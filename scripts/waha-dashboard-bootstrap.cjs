const fs = require('node:fs');
const crypto = require('node:crypto');

// Runs in the authenticated dashboard, before the upstream application loads.
function configureDefaultServer(key) {
  try {
    const storageKey = 'servers';
    const saved = localStorage.getItem(storageKey);
    const servers = saved ? JSON.parse(saved) : [];
    if (!Array.isArray(servers)) return;
    if (servers.length === 0) {
      servers.push({
        id: 'waha_000000000000000001',
        name: 'WAHA',
        connection: { url: window.location.origin, key },
      });
    } else {
      const server = servers.find((item) =>
        item.id === 'waha_000000000000000001' &&
        item.connection?.url === window.location.origin &&
        ['admin', '', null, undefined].includes(item.connection.key));
      if (!server) return;
      server.connection.key = key;
    }
    localStorage.setItem(storageKey, JSON.stringify(servers));
  } catch {
    // Keep manual configuration available when browser storage is unavailable.
  }
}

function main() {
  const key = process.env.WAHA_API_KEY_PLAIN;
  const configured = process.env.WAHA_API_KEY;
  if (!key || !configured) throw new Error('WAHA API key configuration is missing');
  const expected = configured.startsWith('sha512:')
    ? `sha512:${crypto.createHash('sha512').update(key).digest('hex')}`
    : key;
  if (expected !== configured) throw new Error('WAHA API key and plain key do not match');
  if (!process.env.WAHA_DASHBOARD_USERNAME || !process.env.WAHA_DASHBOARD_PASSWORD ||
      /^(true|1)$/i.test(process.env.WAHA_DASHBOARD_NO_PASSWORD || '')) {
    throw new Error('Dashboard authentication is required for API key bootstrap');
  }
  const path = '/app/dist/dashboard/index.html';
  const marker = /<script id="waha-n8n-bootstrap">[\s\S]*?<\/script>/g;
  const html = fs.readFileSync(path, 'utf8').replace(marker, '');
  if (!html.includes('<head>')) throw new Error('Unsupported WAHA dashboard HTML');
  const escapedKey = JSON.stringify(key).replace(/</g, '\\u003c');
  const script = `<script id="waha-n8n-bootstrap">(${configureDefaultServer.toString()})(${escapedKey});</script>`;
  fs.writeFileSync(path, html.replace('<head>', () => `<head>${script}`));
}

if (require.main === module) main();
module.exports = { configureDefaultServer };
