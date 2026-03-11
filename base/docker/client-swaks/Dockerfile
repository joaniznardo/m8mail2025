FROM alpine:3.20

RUN apk add --no-cache \
    perl \
    perl-net-ssleay \
    perl-io-socket-ssl \
    curl \
    bind-tools \
    tcpdump \
    openssl \
    iproute2 \
    iputils \
    bash \
    netcat-openbsd \
    && curl -o /usr/local/bin/swaks https://raw.githubusercontent.com/jetmore/swaks/develop/swaks \
    && chmod +x /usr/local/bin/swaks

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
