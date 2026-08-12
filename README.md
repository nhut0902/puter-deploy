# Puter — Self-hosted on Render

A thin wrapper that deploys the official Puter Docker image
(`ghcr.io/heyputer/puter:latest`) to Render.

Puter is the **Internet OS** — a privacy-first personal cloud that runs
in your browser. Files, apps, AI, and an entire desktop environment,
all open source (AGPL-3.0).

- Upstream: https://github.com/HeyPuter/puter
- Docker image: https://github.com/HeyPuter/puter/pkgs/container/puter
- Live demo: https://puter.com

## Why this repo exists

Render's free/starter tier (512MB RAM) cannot build Puter from source
because native deps (bcrypt, sharp, better-sqlite3) need g++ + python3
and a lot of memory. So this repo re-uses the upstream multi-arch image
and only bakes in a custom `config.json` on top.

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | `FROM ghcr.io/heyputer/puter:latest` + copies `config.json` into `/etc/puter/` |
| `config.json` | Puter config override — listens on port 10000, binds 0.0.0.0 |
| `render.yaml` | Render Blueprint — `runtime: docker`, port 10000, healthcheck `/test` |

## Deploy on Render

1. New → Web Service → connect this repo
2. Runtime: **Docker** (auto-detected via `render.yaml`)
3. Plan: Starter ($7/mo, 512MB → 2GB RAM)
4. Health check path: `/test`
5. Deploy

Or use the Render API / CLI with the Blueprint in this repo.

## Local run

```bash
docker build -t puter-render .
docker run --rm -p 4100:10000 puter-render
# open http://puter.localhost:4100
```

## License

Upstream Puter is AGPL-3.0. This wrapper adds no additional restrictions.
