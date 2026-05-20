# syntax=docker/dockerfile:1
FROM alpine:3.22

ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="docker-duckdns" \
      org.opencontainers.image.description="DuckDNS updater with internal IP support" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.source="https://github.com/luiscbrenes/docker-duckdns" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache \
    curl \
    iproute2 \
    bind-tools \
    tzdata

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
