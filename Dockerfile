# syntax=docker/dockerfile:1.7
#
# Thin wrapper around the official Puter image (ghcr.io/heyputer/puter).
# Render free/starter tiers (512MB RAM) cannot build Puter from source
# (native deps like bcrypt, sharp, better-sqlite3 require g++/python3 and
# a lot of memory). So we re-use the upstream multi-arch image and only
# bake in a custom config.json on top.

FROM ghcr.io/heyputer/puter:latest

# Render injects PORT env (default 10000 on Render). We bake a config.json
# that makes Puter listen on port 10000.
USER root
RUN mkdir -p /etc/puter /var/puter
COPY config.json /etc/puter/config.json
RUN chown -R node:node /etc/puter /var/puter

# Puter default config path is /etc/puter/config.json (set by upstream image)
ENV PUTER_CONFIG_PATH=/etc/puter/config.json
ENV PORT=10000

USER node
EXPOSE 10000
