FROM alpine:3.20

RUN apk add --no-cache \
    curl \
    openssl \
    bash \
    bind-tools \
    iproute2 \
    socat \
    && curl https://get.acme.sh | sh -s email=admin@demoasixcloud2025.cat

# Crear directori per als certificats generats
RUN mkdir -p /certs

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
