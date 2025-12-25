# Docker: Practice Software Testing (local stack)

This repo runs UI tests **against a locally hosted Toolshop stack** to avoid Cloudflare/bot-protection flakiness.

## Start
From repo root:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d --pull missing
```

URLs:
- UI: http://localhost:4200
- API / web: http://localhost:8091

## Stop
```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml down -v
```
