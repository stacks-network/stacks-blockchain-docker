FROM blockstack/bitcoind:controller as builder
FROM alpine
ENV BTC_CONF="/etc/bitcoin/bitcoin.conf"
ENV BTC_DATA="/root/.bitcoin"
ENV BTC_PID="/run/bitcoind.pid"
ARG BTC_URL="https://github.com/blockstackpbc/bitcoin-docker/releases/download/0.20.99.0.0/musl-v0.20.99.0.0.tar.gz"

WORKDIR /
COPY --from=builder /bin/bitcoin-neon-controller /bin/
COPY ./Config.toml /etc/bitcoin-controller/
COPY ./bitcoin.conf ${BTC_CONF}
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

RUN apk add --update \
    curl \
    gnupg \
    boost-system \
    boost-filesystem \
    boost-thread \
    boost-chrono \
    libevent \
    libzmq \
    libgcc \
    tini \
    jq \
    && curl -L -o /bitcoin-${BTC_VERSION}.tar.gz ${BTC_URL} \
    && tar -xzvf /bitcoin-${BTC_VERSION}.tar.gz \
    && mkdir -p /root/.bitcoin \
    && mv /bitcoin-*/bin/* /usr/local/bin/ \
    && rm -rf /bitcoin-*
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/docker-entrypoint.sh"]
