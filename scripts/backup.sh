#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo ".env não encontrado" >&2; exit 1; }
# shellcheck disable=SC1091
set -a
source .env
set +a

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$ROOT_DIR/backups/$STAMP"
mkdir -p "$DEST"

docker compose exec -T postgres \
  pg_dump -U "$POSTGRES_ADMIN_USER" -d "$POSTGRES_DB" -Fc \
  > "$DEST/postgres.dump"

docker compose exec -T redis redis-cli -a "$REDIS_PASSWORD" SAVE >/dev/null
docker compose cp redis:/data/dump.rdb "$DEST/redis-dump.rdb" 2>/dev/null || true
docker compose cp redis:/data/appendonlydir "$DEST/redis-appendonlydir" 2>/dev/null || true

tar -C "$ROOT_DIR" -czf "$DEST/config-and-env.tar.gz" \
  .env Caddyfile docker-compose.yml config initdb certs/ca.crt

chmod -R go-rwx "$DEST"
echo "Backup criado em: $DEST"
