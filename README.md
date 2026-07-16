# WAHA + n8n Automation Stack

Infraestrutura Docker para automações comerciais via WhatsApp, integrando WAHA, n8n, PostgreSQL, Redis e Caddy em um ambiente pronto para implantação em servidor Linux.

Este projeto foi estruturado como uma base de automação para atendimento, vendas, notificações e integrações operacionais. A proposta é entregar um stack simples de publicar, com dados persistentes, proxy reverso, HTTPS, geração automatizada de segredos e rotinas básicas de operação.

## Visão Comercial

Empresas que usam WhatsApp como canal de relacionamento normalmente precisam conectar mensagens, sistemas internos, planilhas, CRMs, bancos de dados e fluxos de atendimento. Este repositório resolve a camada de infraestrutura para esse cenário:

- WAHA expõe a integração com WhatsApp por API.
- n8n orquestra os workflows e integrações.
- PostgreSQL persiste dados do n8n.
- Redis apoia automações e armazenamento operacional do WAHA.
- Caddy publica os serviços com HTTPS e proxy reverso.
- Scripts de setup, deploy, firewall e backup reduzem trabalho manual.

O resultado é uma fundação técnica reutilizável para projetos de automação comercial, atendimento automatizado, captação de leads, pós-venda, alertas e integrações entre sistemas.

## Principais Recursos

- Stack completo com Docker Compose.
- Modo local para testes sem domínio público.
- Suporte a servidores ARM64, como Oracle Cloud Ampere A1.
- Seleção automática da imagem WAHA para ARM64 ou AMD64 no script de setup.
- n8n em modo regular, usando PostgreSQL como banco principal.
- Redis separado por banco lógico:
  - DB `0` para workflows do n8n.
  - DB `1` para o WAHA.
- Caddy como proxy reverso para n8n e WAHA.
- HTTPS nos domínios públicos via Caddy.
- TLS obrigatório para conexões externas ao PostgreSQL.
- TLS obrigatório para conexões externas ao Redis.
- Geração automática de senhas, chaves e certificados privados.
- Backup de PostgreSQL, Redis e arquivos de configuração.
- Regras de firewall com UFW.

## Arquitetura

```text
Internet
   |
   | HTTPS
   v
Caddy
   |----------------------|
   v                      v
n8n                    WAHA
   |                      |
   | PostgreSQL           | Redis DB 1
   v                      v
PostgreSQL             Redis
   ^
   |
Redis DB 0 usado por workflows do n8n
```

### Serviços

| Serviço | Função | Exposição |
|---|---|---|
| Caddy | Proxy reverso e HTTPS | `80`, `443`, `443/udp` |
| n8n | Orquestração de workflows | via Caddy |
| WAHA | API e dashboard WhatsApp | via Caddy |
| PostgreSQL | Banco de dados do n8n | `5432` com TLS |
| Redis | Cache/estado para n8n e WAHA | `6379` com TLS externo |

## Estrutura do Projeto

```text
.
├── Caddyfile
├── docker-compose.yml
├── docker-compose.local.yml
├── .env.example
├── .env.local.example
├── setup.conf.example
├── config/
│   ├── postgres/
│   └── redis/
├── initdb/
├── scripts/
│   ├── setup.sh
│   ├── setup-local.sh
│   ├── deploy.sh
│   ├── deploy-local.sh
│   ├── configure-ufw.sh
│   └── backup.sh
├── certs/
├── backups/
└── shared/
```

## Requisitos

- Docker Engine.
- Docker Compose plugin.

Para uso local:

- Linux, macOS ou Windows com WSL2/Docker Desktop.
- Portas locais disponíveis: `5678`, `3000`, `5432` e `6379`.

Para deploy em servidor:

- Servidor Linux com Ubuntu 24.04 ou compatível.
- Domínios ou subdomínios apontando para o IP público do servidor.
- Portas liberadas no provedor de cloud:
  - `22/tcp`
  - `80/tcp`
  - `443/tcp`
  - `443/udp`
  - `5432/tcp`, caso queira acesso externo ao PostgreSQL.
  - `6379/tcp`, caso queira acesso externo ao Redis.

> Para produção, restrinja `22`, `5432` e `6379` ao menor conjunto possível de IPs confiáveis.

## Configuração de DNS

Crie dois registros `A` apontando para o IP público do servidor:

| Tipo | Nome sugerido | Destino |
|---|---|---|
| A | `n8n.seudominio.com` | IP público do servidor |
| A | `waha.seudominio.com` | IP público do servidor |

Se estiver usando Cloudflare:

- SSL/TLS: `Full (strict)`.
- WebSockets: ativado.
- Cache: bypass para os hostnames do n8n e WAHA.

PostgreSQL e Redis não devem passar por proxy HTTP. Para acesso externo, conecte diretamente pelo IP público usando TLS.

## Modo Local

Use o modo local quando quiser testar o projeto no seu computador, sem domínio, sem Caddy e sem HTTPS público.

Nesse modo:

- n8n fica em `http://localhost:5678`.
- WAHA fica em `http://localhost:3000/dashboard`.
- PostgreSQL fica disponível em `127.0.0.1:5432`.
- Redis fica disponível em `127.0.0.1:6379`.
- PostgreSQL e Redis não usam TLS externo, pois ficam presos ao `localhost`.
- O webhook WAHA -> n8n continua funcionando pela rede interna Docker.

### Exemplo no Windows

No Windows, use Docker Desktop com integração WSL2 habilitada e execute os scripts dentro de uma distro Linux, como Ubuntu.

No PowerShell:

```powershell
wsl
```

Dentro do WSL, clone o repositório e execute o setup local:

```bash
git clone https://github.com/ViniciusCTeixeira/waha-n8n-automation.git
cd waha-n8n-automation
bash ./scripts/setup-local.sh
bash ./scripts/deploy-local.sh
```

Depois acesse pelo navegador do Windows:

```text
http://localhost:5678
http://localhost:3000/dashboard
```

> Os scripts foram escritos em Bash. No Windows, prefira WSL2 em vez de PowerShell puro.

### Exemplo no Linux Local

Em uma máquina Linux com Docker instalado:

```bash
git clone https://github.com/ViniciusCTeixeira/waha-n8n-automation.git
cd waha-n8n-automation
bash ./scripts/setup-local.sh
bash ./scripts/deploy-local.sh
```

Depois acesse:

```text
http://localhost:5678
http://localhost:3000/dashboard
```

Se preferir rodar manualmente:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml up -d
```

Acesse:

```text
http://localhost:5678
http://localhost:3000/dashboard
```

As credenciais locais do WAHA ficam em `.env.local`:

```bash
grep -E '^WAHA_DASHBOARD_(USERNAME|PASSWORD)=' .env.local
grep '^WAHA_API_KEY_PLAIN=' .env.local
```

Para parar o ambiente local:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml down
```

Para remover também os volumes locais:

```bash
docker compose --env-file .env.local -f docker-compose.local.yml down -v
```

## Instalação em Servidor

Clone o repositório no servidor:

```bash
git clone https://github.com/ViniciusCTeixeira/waha-n8n-automation.git
cd waha-n8n-automation
```

Crie o arquivo de configuração do setup:

```bash
cp setup.conf.example setup.conf
nano setup.conf
```

Configure os dados principais:

```env
PUBLIC_IP=203.0.113.10
ACME_EMAIL=admin@seudominio.com
N8N_DOMAIN=n8n.seudominio.com
WAHA_DOMAIN=waha.seudominio.com
TZ=America/Sao_Paulo
```

Execute o setup inicial:

```bash
sudo ./scripts/setup.sh
```

O script cria:

- `.env` com senhas e chaves aleatórias.
- CA privada para PostgreSQL e Redis.
- Certificados TLS para PostgreSQL e Redis.
- `config/redis/redis.conf` com senha aplicada.
- Diretórios necessários para arquivos, certificados e backups.

Depois do setup, revise o arquivo `.env` gerado:

```env
N8N_DOMAIN=n8n.seudominio.com
WAHA_DOMAIN=waha.seudominio.com
ACME_EMAIL=admin@seudominio.com
```

## Firewall

Configure o firewall local:

```bash
sudo ./scripts/configure-ufw.sh
```

O script libera as portas necessárias para HTTP, HTTPS, PostgreSQL e Redis. Em ambientes comerciais, recomenda-se limitar `5432` e `6379` a IPs administrativos específicos.

## Deploy

Suba os containers:

```bash
./scripts/deploy.sh
```

Acompanhe os logs:

```bash
docker compose logs -f --tail=100
```

Verifique os serviços:

```bash
docker compose ps
```

## Primeiro Acesso

### n8n

Acesse:

```text
https://n8n.seudominio.com
```

No primeiro acesso, o n8n solicitará a criação da conta proprietária.

### WAHA

Acesse:

```text
https://waha.seudominio.com/dashboard
```

As credenciais do dashboard são geradas no `.env`:

```bash
grep -E '^WAHA_DASHBOARD_(USERNAME|PASSWORD)=' .env
```

Para chamadas à API do WAHA, use o header:

```http
X-Api-Key: SUA_CHAVE
```

A chave está no campo:

```bash
grep '^WAHA_API_KEY_PLAIN=' .env
```

## Integração WAHA -> n8n

Crie no n8n um workflow com nó Webhook:

```text
Method: POST
Path: waha
```

O WAHA envia eventos internamente para:

```text
http://n8n:5678/webhook/waha
```

O caminho pode ser alterado no `.env`:

```env
WAHA_N8N_WEBHOOK_PATH=waha
```

Eventos configurados por padrão:

```env
WAHA_WEBHOOK_EVENTS=message,message.any,message.ack,session.status
```

## Redis nos Workflows do n8n

Para usar Redis dentro dos workflows do n8n, crie uma credencial Redis com:

```text
Host: redis
Port: 6379
Database Number: 0
Password: valor de REDIS_PASSWORD no .env
SSL: desativado
```

Essa conexão usa a rede interna do Docker. Não use o IP público nessa credencial.

O WAHA já usa Redis no banco lógico `1`:

```text
redis://default:SENHA@redis:6379/1
```

## Acesso Externo ao PostgreSQL

Para ferramentas como DBeaver ou pgAdmin:

```text
Host: IP público do servidor
Port: 5432
Database: n8n
Username: postgres_admin
Password: POSTGRES_ADMIN_PASSWORD do .env
SSL mode: verify-full
Root certificate / CA: certs/ca.crt
```

Para uso cotidiano, prefira o usuário `n8n_app`. Reserve `postgres_admin` para administração.

## Acesso Externo ao Redis

Para ferramentas como RedisInsight:

```text
Host: IP público do servidor
Port: 6379
Username: default
Password: REDIS_PASSWORD do .env
TLS/SSL: ativado
CA certificate: certs/ca.crt
Client certificate: não necessário
```

Teste com `redis-cli`:

```bash
redis-cli \
  -h IP_PUBLICO_DO_SERVIDOR \
  -p 6379 \
  --tls \
  --cacert certs/ca.crt \
  -a 'SUA_SENHA' \
  ping
```

## Backup

Execute:

```bash
./scripts/backup.sh
```

O backup é salvo em:

```text
backups/AAAAMMDD-HHMMSS
```

O processo inclui:

- Dump do PostgreSQL.
- Snapshot/AOF do Redis quando disponível.
- Arquivos essenciais de configuração.
- CA pública usada por clientes externos.

## Atualizações

As versões ficam fixadas no `.env` e no `docker-compose.yml`. Antes de atualizar:

1. Leia as notas oficiais do n8n e WAHA.
2. Execute `./scripts/backup.sh`.
3. Altere a versão desejada.
4. Rode:

```bash
docker compose pull
docker compose up -d
```

## Segurança

Este projeto já inclui boas práticas importantes para um ambiente pequeno ou médio:

- Segredos gerados automaticamente.
- `.env` com permissão restrita.
- PostgreSQL com autenticação `scram-sha-256`.
- TLS obrigatório para conexões externas ao PostgreSQL.
- Redis externo publicado somente via TLS.
- Certificados privados fora do versionamento.
- Volumes persistentes para dados.
- Caddy removendo header `Server`.
- Backups locais com permissões restritas.

No modo local, os serviços são publicados apenas em `127.0.0.1` e usam HTTP para facilitar testes. Não use `docker-compose.local.yml` como base de produção.

Pontos recomendados para produção:

- Restringir portas administrativas por IP.
- Usar VPN ou bastion host para PostgreSQL e Redis.
- Monitorar logs e tentativas de autenticação.
- Automatizar backup externo.
- Definir política de retenção.
- Revisar eventos expostos pelo webhook do WAHA.

## Limitações Conhecidas

- O n8n está em modo regular, sem queue mode e sem workers dedicados.
- O repositório entrega a infraestrutura, não workflows prontos de negócio.
- O modo local é voltado a desenvolvimento e demonstração, não a produção.
- PostgreSQL e Redis podem ser expostos publicamente se as regras de firewall forem mantidas como padrão.
- Os certificados de PostgreSQL e Redis são emitidos para o IP informado no setup. Se o IP mudar, gere novos certificados.
- O script de inicialização do usuário `n8n_app` roda apenas na primeira criação do volume PostgreSQL.

## Roadmap Sugerido

- Adicionar exemplos de workflows comerciais no n8n.
- Criar monitoramento com Prometheus/Grafana ou solução equivalente.
- Automatizar backup externo para S3, R2 ou Object Storage.
- Adicionar compose opcional com queue mode para maior escala.
- Incluir pipeline CI para validação de Compose e ShellCheck.
- Criar documentação de recuperação de desastre.

## Competências Demonstradas

Este projeto demonstra experiência prática com:

- Docker e Docker Compose.
- Deploy de aplicações em VPS/cloud.
- Reverse proxy e HTTPS com Caddy.
- Integração entre serviços via rede Docker.
- PostgreSQL com usuário dedicado e TLS.
- Redis com persistência e TLS externo.
- Automação de setup com Bash.
- Boas práticas de variáveis de ambiente e versionamento de segredos.
- Infraestrutura para automações comerciais com n8n e WhatsApp.

## Observações Para Repositório Público

Antes de publicar no GitHub, confirme que estes arquivos não foram versionados:

- `.env`
- `.env.local`
- `setup.conf`
- `certs/ca.key`
- `certs/postgres/server.key`
- `certs/redis/server.key`
- `config/redis/redis.conf`
- qualquer backup real dentro de `backups/`

O `.gitignore` deste projeto já cobre esses arquivos, mas vale revisar o histórico do Git antes de tornar o repositório público.

## Licença

Defina uma licença antes de publicar. Para portfólio aberto, opções comuns são MIT, Apache-2.0 ou GPL-3.0, conforme o nível de liberdade que você deseja conceder.
