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

# CMD ["/bin/sh", "-c", "/usr/local/bin/bitcoind -conf=${BTC_CONF} -pid=${BTC_PID} -datadir=${BTC_DATA} && /bin/bitcoin-neon-controller /etc/bitcoin-controller/Config.toml"]
# ENTRYPOINT ["/docker-entrypoint.sh"]
# /usr/local/bin/bitcoind -conf=${BTC_CONF} -nodebuglogfile -pid=${BTC_PID} -datadir=${BTC_DATA} > /dev/stdout 2>&1 & /bin/bitcoin-neon-controller /etc/bitcoin-controller/Config.toml > /dev/stdout 2>&1 &"]

# /usr/local/bin/bitcoind -conf=/etc/bitcoin/bitcoin.conf -nodebuglogfile -pid=/run/bitcoind.pid -datadir=/root/.bitcoin
# sh -c "nohup /bin/bitcoin-neon-controller /etc/bitcoin-controller/Config.toml && /usr/local/bin/bitcoind -conf=/etc/bitcoin/bitcoin.conf -nodebuglogfile -pid=/run/bitcoind.pid -datadir=/root/.bitcoin"
#




# export BTC_CONF="/etc/bitcoin/bitcoin.conf"
# export BTC_DATA="/root/.bitcoin"
# export BTC_PID="/run/bitcoind.pid"
# export BTC_URL="https://github.com/blockstackpbc/bitcoin-docker/releases/download/0.20.99.0.0/musl-v0.20.99.0.0.tar.gz"
# mkdir -p /etc/bitcoin
# cat <<EOF> ${BTC_CONF}
# server=1
# regtest=1
# rpcallowip=0.0.0.0/0
# rpcallowip=::/0
# rpcuser=blockstack
# rpcpassword=blockstacksystem
# txindex=1
# listen=1
# rpcserialversion=0
#
# [regtest]
# bind=0.0.0.0:18444
# rpcbind=0.0.0.0:18443
# rpcport=18443
# EOF
#
# apk add --no-cache --update \
#     curl \
#     gnupg \
#     boost-system \
#     boost-filesystem \
#     boost-thread \
#     boost-chrono \
#     libevent \
#     libzmq \
#     libgcc \
#     tini \
#     && curl -L -o /bitcoin-${BTC_VERSION}.tar.gz ${BTC_URL} \
#     && tar -xzvf /bitcoin-${BTC_VERSION}.tar.gz \
#     && mkdir /root/.bitcoin \
#     && mv /bitcoin-*/bin/* /usr/local/bin/ \
#     && rm -rf /bitcoin-*
#
# /usr/local/bin/bitcoind -conf=${BTC_CONF} -pid=${BTC_PID} -datadir=${BTC_DATA}
