#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Execute com sudo." >&2
  exit 1
fi

command -v ufw >/dev/null 2>&1 || {
  apt-get update
  apt-get install -y ufw
}

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

# O usuário pediu acesso externo de qualquer rede. PostgreSQL exige TLS e Redis
# expõe somente a porta TLS, mas continuam públicos e sujeitos a tentativas de login.
ufw allow 5432/tcp
ufw allow 6379/tcp

ufw --force enable
ufw status verbose
