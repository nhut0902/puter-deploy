# syntax=docker/dockerfile:1.7
#
# Puter wrapper for Render.
# Uses the official upstream image (ghcr.io/heyputer/puter:latest) and
# fixes the runtime write-permission issue (node user needs to create
# volatile/runtime/ for SQLite).

FROM ghcr.io/heyputer/puter:latest

USER root
# Pre-create the writable runtime dirs the SQLite + faux-S3 backends
# need. Upstream image owns /opt/puter as node:node but on some runtimes
# (Render) the USER directive is honoured yet the dir is missing.
RUN mkdir -p /etc/puter /var/puter \
             /opt/puter/volatile/runtime \
             /opt/puter/volatile/runtime/fauxqs-data \
             /opt/puter/volatile/runtime/fauxqs-s3-data && \
    chown -R node:node /etc/puter /var/puter /opt/puter

COPY config.json /etc/puter/config.json
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown node:node /entrypoint.sh /etc/puter/config.json

ENV PUTER_CONFIG_PATH=/etc/puter/config.json
ENV PORT=10000

USER node
EXPOSE 10000

CMD ["/entrypoint.sh"]
