FROM alpine
ARG BTC_CONF="/etc/bitcoin/bitcoin.conf"A
ARG BTC_DATA="/root/.bitcoin"
ARG BTC_PID="/run/bitcoind.pid"
ENV BTC_CONF=${BTC_CONF}
ENV BTC_DATA=${BTC_DATA}
ENV BTC_PID=${BTC_PID}
ENV BTC_VERSION=0.20.99.0.0
ENV BTC_URL="https://github.com/blockstackpbc/bitcoin-docker/releases/download/${BTC_VERSION}/musl-v${BTC_VERSION}.tar.gz"

WORKDIR /
COPY ./bitcoin.conf ${BTC_CONF}

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
    jq \
    && curl -L -o /bitcoin.tar.gz ${BTC_URL} \
    && tar -xzvf /bitcoin.tar.gz \
    && mkdir -p ${BTC_DATA} \
    && mv /bitcoin-*/bin/* /usr/local/bin/ \
    && rm -rf /bitcoin-*

#ENTRYPOINT ["/usr/local/bin/bitcoind", "-conf=${BTC_CONF}", "-nodebuglogfile", "-pid=${BTC_PID}", "-datadir=${BTC_DATA}"]
CMD ["/usr/local/bin/bitcoind", "-conf=/etc/bitcoin/bitcoin.conf", "-nodebuglogfile",  "-datadir=/root/.bitcoin"]
