FROM alpine:3.20

RUN apk add --no-cache \
    swaks \
    perl \
    curl \
    bind-tools \
    tcpdump \
    openssl \
    iproute2 \
    iputils \
    bash \
    nmap-ncat \
    mailx

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
