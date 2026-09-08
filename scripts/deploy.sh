#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for required in .env certs/ca.crt certs/postgres/server.crt certs/postgres/server.key certs/redis/server.crt certs/redis/server.key config/redis/redis.conf; do
  [[ -f "$required" ]] || {
    echo "Arquivo ausente: $required" >&2
    echo "Execute primeiro: sudo ./scripts/setup.sh IP_PUBLICO EMAIL" >&2
    exit 1
  }
done

command -v docker >/dev/null 2>&1 || {
  echo "Docker não encontrado. Instale Docker Engine e o plugin Docker Compose." >&2
  exit 1
}

docker compose config >/dev/null
docker compose pull
docker compose up -d --remove-orphans
docker compose ps

echo
echo "Logs iniciais: docker compose logs -f --tail=100"
