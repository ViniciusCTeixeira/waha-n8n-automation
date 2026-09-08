#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Uso:
  sudo ./scripts/setup.sh

Antes de executar:
  cp setup.conf.example setup.conf
  nano setup.conf

O script cria:
  - .env com segredos aleatórios
  - CA privada e certificados TLS para PostgreSQL e Redis
  - config/redis/redis.conf com senha

Ele não sobrescreve uma instalação existente.
EOF
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Execute com sudo para definir corretamente as permissões dos certificados." >&2
  usage
  exit 1
fi

CONFIG_FILE="setup.conf"

if [[ "$#" -gt 0 ]]; then
  echo "Este setup não aceita argumentos. Configure os dados em setup.conf." >&2
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Arquivo de configuração não encontrado: $CONFIG_FILE" >&2
  echo "Crie com: cp setup.conf.example setup.conf" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source "$CONFIG_FILE"
set +a

PUBLIC_IP="${PUBLIC_IP:-}"
ACME_EMAIL="${ACME_EMAIL:-}"
N8N_DOMAIN="${N8N_DOMAIN:-n8n.seudominio.com}"
WAHA_DOMAIN="${WAHA_DOMAIN:-waha.seudominio.com}"
TZ="${TZ:-America/Sao_Paulo}"

if [[ -z "$PUBLIC_IP" || -z "$ACME_EMAIL" || -z "$N8N_DOMAIN" || -z "$WAHA_DOMAIN" ]]; then
  usage
  exit 1
fi

if ! [[ "$PUBLIC_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "IP público inválido: $PUBLIC_IP" >&2
  exit 1
fi

for cmd in openssl sed sha512sum awk; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Comando obrigatório não encontrado: $cmd" >&2
    exit 1
  }
done

if [[ -e .env || -e certs/ca.key || -e config/redis/redis.conf ]]; then
  echo "Arquivos de configuração existentes detectados. Nada foi sobrescrito." >&2
  echo "Para uma reinstalação limpa, faça backup e remova manualmente .env, certs/ e config/redis/redis.conf." >&2
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

cat > .env <<EOF
N8N_DOMAIN=$N8N_DOMAIN
WAHA_DOMAIN=$WAHA_DOMAIN
ACME_EMAIL=$ACME_EMAIL
TZ=$TZ

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
chmod 600 .env

mkdir -p certs/postgres certs/redis config/redis shared backups

# CA privada usada apenas por PostgreSQL e Redis.
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -sha256 -days 3650 \
  -key certs/ca.key \
  -out certs/ca.crt \
  -subj "/CN=Automation Stack Private CA/O=Automation Stack"

make_server_cert() {
  local service="$1"
  local dir="certs/$service"
  local config
  config="$(mktemp)"

  cat > "$config" <<EOF
[req]
distinguished_name=req_dn
prompt=no
req_extensions=req_ext

[req_dn]
CN=$PUBLIC_IP
O=Automation Stack

[req_ext]
subjectAltName=@alt_names
extendedKeyUsage=serverAuth

[alt_names]
IP.1=$PUBLIC_IP
DNS.1=$service
EOF

  openssl genrsa -out "$dir/server.key" 3072
  openssl req -new -sha256 \
    -key "$dir/server.key" \
    -out "$dir/server.csr" \
    -config "$config"
  openssl x509 -req -sha256 -days 825 \
    -in "$dir/server.csr" \
    -CA certs/ca.crt \
    -CAkey certs/ca.key \
    -CAcreateserial \
    -out "$dir/server.crt" \
    -extensions req_ext \
    -extfile "$config"

  rm -f "$dir/server.csr" "$config"
}

make_server_cert postgres
make_server_cert redis

# UID/GID 999 corresponde ao usuário de serviço nas variantes Debian do PostgreSQL e Alpine do Redis selecionadas.
chown 999:999 certs/postgres/server.key certs/postgres/server.crt
chown 999:999 certs/redis/server.key certs/redis/server.crt certs/ca.crt
chmod 600 certs/postgres/server.key certs/redis/server.key certs/ca.key
chmod 644 certs/postgres/server.crt certs/redis/server.crt certs/ca.crt

sed "s/__REDIS_PASSWORD__/$REDIS_PASSWORD/g" \
  config/redis/redis.conf.template > config/redis/redis.conf
chown 999:999 config/redis/redis.conf
chmod 600 config/redis/redis.conf

chmod +x initdb/01-create-n8n-user.sh scripts/*.sh

echo
echo "Configuração criada com sucesso."
echo "CA para importar no DBeaver/RedisInsight: $ROOT_DIR/certs/ca.crt"
echo "Próximo passo: ./scripts/deploy.sh"
