# syntax=docker/dockerfile:1.7
#
# Thin wrapper around the official Puter image (ghcr.io/heyputer/puter).
# Render free/starter tiers (512MB RAM) cannot build Puter from source
# (native deps like bcrypt, sharp, better-sqlite3 require g++/python3 and
# a lot of memory). So we re-use the upstream multi-arch image and only
# bake in a custom config.json on top.
#
# Upstream image:
#   - EXPOSE 4100
#   - USER node
#   - CMD: node ./dist/src/backend/index.js
#   - HEALTHCHECK: wget http://puter.localhost:4100/test
#
# On Render the PORT env var is injected (default 10000). We override
# the listening port via config.json below so Puter listens on $PORT.

FROM ghcr.io/heyputer/puter:latest

# Render injects PORT. Default to 10000 if missing (Render's default).
ARG RENDER_PORT=10000
ENV RENDER_PORT=${RENDER_PORT}

# Puter reads its config from PUTER_CONFIG_PATH (/etc/puter/config.json
# in the upstream image). We drop our override there. The v2 loader
# deep-merges this over config.default.json, so we only need to set
# the port + a few safe defaults.
USER root
RUN mkdir -p /etc/puter
COPY config.json /etc/puter/config.json
RUN chown -R node:node /etc/puter

# Puter serves on this port. Render's health check + public URL will
# route to this port via the $PORT env var.
ENV PORT=10000

USER node
EXPOSE 10000
