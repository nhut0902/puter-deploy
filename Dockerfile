# syntax=docker/dockerfile:1.7
#
# DEBUG build — captures Puter startup logs and serves them over HTTP
# so we can see why Puter crashes on Render (Render dashboard logs are
# not accessible via API).

FROM ghcr.io/heyputer/puter:latest

USER root
RUN mkdir -p /etc/puter /var/puter
COPY config.json /etc/puter/config.json
COPY entrypoint-debug.sh /entrypoint-debug.sh
RUN chmod +x /entrypoint-debug.sh && \
    chown -R node:node /etc/puter /var/puter /entrypoint-debug.sh

ENV PUTER_CONFIG_PATH=/etc/puter/config.json
ENV PORT=10000
ENV LOG_FILE=/tmp/puter.log

USER node
EXPOSE 10000

CMD ["/entrypoint-debug.sh"]
