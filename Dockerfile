# syntax=docker/dockerfile:1.7
#
# Puter wrapper for Render.
# Uses the official upstream image (ghcr.io/heyputer/puter:latest) and
# runs a Node.js entrypoint that:
#   1. Pre-creates writable data dirs
#   2. Starts Puter in background
#   3. Serves an HTTP log endpoint on $PORT (so Render health check
#      passes immediately and we can fetch the log via the public URL
#      even if Puter crashes)

FROM ghcr.io/heyputer/puter:latest

USER root
# Pre-create writable runtime dirs. Upstream image's chown may not be
# honoured by Render's runtime UID (1001 vs node's 1000), so we also
# chmod 777 the data dirs as a safety net.
RUN mkdir -p /etc/puter /var/puter \
             /opt/puter/volatile/runtime \
             /opt/puter/volatile/runtime/fauxqs-data \
             /opt/puter/volatile/runtime/fauxqs-s3-data && \
    chmod -R 777 /opt/puter/volatile /var/puter /tmp && \
    chown -R node:node /etc/puter /var/puter /opt/puter

COPY config.json /etc/puter/config.json
COPY entrypoint.js /entrypoint.js
RUN chmod +x /entrypoint.js && \
    chown node:node /entrypoint.js /etc/puter/config.json

ENV PUTER_CONFIG_PATH=/etc/puter/config.json
ENV PORT=10000
ENV NODE_ENV=production

USER node
EXPOSE 10000

CMD ["node", "/entrypoint.js"]
