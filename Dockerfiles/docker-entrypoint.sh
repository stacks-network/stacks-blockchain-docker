#!/bin/sh

/bin/puppet-chain /etc/bitcoin/puppet-chain.toml > /dev/stdout 2>&1 &
/usr/local/bin/bitcoind -conf=/etc/bitcoin/bitcoin.conf -nodebuglogfile -pid=/run/bitcoind.pid -datadir=/root/.bitcoin