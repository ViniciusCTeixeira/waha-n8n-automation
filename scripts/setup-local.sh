#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Uso:
  ./scripts/setup-local.sh

O script cria:
  - .env.local com segredos aleatórios
  - diretórios locais necessários

Ele não sobrescreve uma configuração local existente.
EOF
}

if [[ "$#" -gt 0 ]]; then
  usage
  exit 1
fi

for cmd in openssl sha512sum awk; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Comando obrigatório não encontrado: $cmd" >&2
    exit 1
  }
done

if [[ -e .env.local ]]; then
  echo "Arquivo .env.local existente detectado. Nada foi sobrescrito." >&2
  echo "Para recriar o ambiente local, faça backup e remova manualmente .env.local." >&2
  exit 1
fi

rand_hex() {
  openssl rand -hex "${1:-32}"
}

case "$(uname -m)" in
  aarch64|arm64)
    WAHA_IMAGE="devlikeapro/waha:gows-arm"
    ;;
  x86_64|amd64)
    WAHA_IMAGE="devlikeapro/waha:gows"
    ;;
  *)
    echo "Arquitetura não reconhecida: $(uname -m)" >&2
    exit 1
    ;;
esac

POSTGRES_ADMIN_PASSWORD="$(rand_hex 32)"
N8N_DB_PASSWORD="$(rand_hex 32)"
REDIS_PASSWORD="$(rand_hex 32)"
N8N_ENCRYPTION_KEY="$(rand_hex 32)"
WAHA_API_KEY_PLAIN="$(rand_hex 32)"
WAHA_API_KEY_SHA512="$(printf '%s' "$WAHA_API_KEY_PLAIN" | sha512sum | awk '{print $1}')"
WAHA_DASHBOARD_PASSWORD="$(rand_hex 24)"
WAHA_SWAGGER_PASSWORD="$(rand_hex 24)"
WAHA_WEBHOOK_HMAC_KEY="$(rand_hex 32)"

cat > .env.local <<EOF
TZ=America/Sao_Paulo

LOCAL_N8N_PORT=5678
LOCAL_WAHA_PORT=3000
LOCAL_POSTGRES_PORT=5432
LOCAL_REDIS_PORT=6379

N8N_VERSION=stable
WAHA_IMAGE=$WAHA_IMAGE
WAHA_ENGINE=GOWS

POSTGRES_DB=n8n
POSTGRES_ADMIN_USER=postgres_admin
POSTGRES_ADMIN_PASSWORD=$POSTGRES_ADMIN_PASSWORD
N8N_DB_USER=n8n_app
N8N_DB_PASSWORD=$N8N_DB_PASSWORD

REDIS_PASSWORD=$REDIS_PASSWORD
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

WAHA_API_KEY_PLAIN=$WAHA_API_KEY_PLAIN
WAHA_API_KEY_SHA512=$WAHA_API_KEY_SHA512
WAHA_DASHBOARD_USERNAME=admin
WAHA_DASHBOARD_PASSWORD=$WAHA_DASHBOARD_PASSWORD
WAHA_SWAGGER_USERNAME=admin
WAHA_SWAGGER_PASSWORD=$WAHA_SWAGGER_PASSWORD
WAHA_N8N_WEBHOOK_PATH=waha
WAHA_WEBHOOK_HMAC_KEY=$WAHA_WEBHOOK_HMAC_KEY
WAHA_WEBHOOK_EVENTS=message,message.any,message.ack,session.status
EOF
chmod 600 .env.local

mkdir -p shared backups
chmod +x initdb/01-create-n8n-user.sh scripts/*.sh

echo
echo "Configuração local criada com sucesso."
echo "Suba o ambiente com: ./scripts/deploy-local.sh"
