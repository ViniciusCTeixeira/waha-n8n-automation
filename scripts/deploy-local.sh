#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env.local ]] || {
  echo ".env.local não encontrado" >&2
  echo "Execute primeiro: ./scripts/setup-local.sh" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo "Docker não encontrado. Instale Docker Engine e o plugin Docker Compose." >&2
  exit 1
}

docker compose --env-file .env.local -f docker-compose.local.yml config >/dev/null
docker compose --env-file .env.local -f docker-compose.local.yml pull
docker compose --env-file .env.local -f docker-compose.local.yml up -d --remove-orphans
docker compose --env-file .env.local -f docker-compose.local.yml ps

echo
echo "n8n:  http://localhost:$(grep '^LOCAL_N8N_PORT=' .env.local | cut -d= -f2)"
echo "WAHA: http://localhost:$(grep '^LOCAL_WAHA_PORT=' .env.local | cut -d= -f2)/dashboard"
echo
echo "Logs iniciais: docker compose --env-file .env.local -f docker-compose.local.yml logs -f --tail=100"
