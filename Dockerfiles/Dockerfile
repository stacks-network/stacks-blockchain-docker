FROM blockstack/stacks-blockchain as builder
FROM alpine
ARG BTC_URL="https://github.com/blockstackpbc/bitcoin-docker/releases/download/0.20.99.0.0/musl-v0.20.99.0.0.tar.gz"
WORKDIR /
COPY --from=builder /bin/puppet-chain /bin/
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
    && curl -L -o /bitcoin.tar.gz ${BTC_URL} \
    && tar -xzvf /bitcoin.tar.gz \
    && mkdir -p /root/.bitcoin \
    && mv /bitcoin-*/bin/* /usr/local/bin/ \
    && rm -rf /bitcoin-*
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/docker-entrypoint.sh"]