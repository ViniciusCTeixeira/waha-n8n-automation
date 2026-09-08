const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { configureDefaultServer } = require('../scripts/waha-dashboard-bootstrap.cjs');
function run(saved) {
  let value = saved;
  vm.runInNewContext(`(${configureDefaultServer.toString()})('test-key')`, {
    window: { location: { origin: 'http://localhost:3000' } },
    localStorage: { getItem: () => value, setItem: (_, next) => { value = next; } },
  });
  return value;
}
test('first access seeds the default server with the configured key', () => {
  const result = JSON.parse(run(null));
  assert.equal(result[0].connection.key, 'test-key');
  assert.equal(result[0].connection.url, 'http://localhost:3000');
});
test('repairs the upstream admin default for this origin', () => {
  const old = JSON.stringify([{ id: 'waha_000000000000000001', connection: { url: 'http://localhost:3000', key: 'admin' } }]);
  assert.equal(JSON.parse(run(old))[0].connection.key, 'test-key');
});
test('preserves a manually configured key and remote servers', () => {
  for (const connection of [{ url: 'http://localhost:3000', key: 'custom' }, { url: 'https://remote.example', key: 'admin' }]) {
    const saved = JSON.stringify([{ id: 'waha_000000000000000001', connection }]);
    assert.equal(run(saved), saved);
  }
});
test('leaves malformed saved settings untouched', () => {
  assert.equal(run('{invalid'), '{invalid');
});
