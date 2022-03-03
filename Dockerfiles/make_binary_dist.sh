#!/bin/sh -x

DEST_DIR="/srv/bitcoind"
BERKELEYDB_VERSION="db-4.8.30.NC"
BERKELEYDB_PREFIX="/opt/${BERKELEYDB_VERSION}"
GIT_REPO="https://github.com/bitcoin/bitcoin"


if [ -d ${DEST_DIR} ]; then
  rm -rf ${DEST_DIR}
fi

echo ""
echo "Cloning ${GIT_REPO} into ${DEST_DIR}"
echo ""
git clone --depth 1 --branch v${BTC_VERSION} ${GIT_REPO} ${DEST_DIR}


echo ""
echo "Building Berkeley DB Version:$BERKELEYDB_VERSION"
echo ""
curl -sL https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz -o /tmp/${BERKELEYDB_VERSION}.tar.gz
tar -xzf /tmp/${BERKELEYDB_VERSION}.tar.gz -C /tmp/
sed s/__atomic_compare_exchange/__atomic_compare_exchange_db/g -i /tmp/${BERKELEYDB_VERSION}/dbinc/atomic.h
mkdir -p ${BERKELEYDB_PREFIX}
cd /tmp/${BERKELEYDB_VERSION}/build_unix
../dist/configure --build=x86_64 --enable-cxx --disable-shared --with-pic --prefix=${BERKELEYDB_PREFIX}
make -j4
make install
/sbin/ldconfig /usr/lib /lib ${BERKELEYDB_PREFIX}/lib
BDB_LDFLAGS="-L${BERKELEYDB_PREFIX}/lib/"
BDB_CPPFLAGS="-I${BERKELEYDB_PREFIX}/include/"


cd ${DEST_DIR}
echo ""
echo "Building BTC Version:${BTC_VERSION}"
echo ""
echo ""
echo "Running autogen"
echo ""
sh autogen.sh

echo ""
echo "Configuring bitcoin"
echo ""
./configure \
  --enable-util-cli \
  --disable-gui-tests \
  --enable-static \
  --disable-tests \
  --without-miniupnpc \
  --disable-shared \
  --with-pic \
  --enable-cxx \
  LDFLAGS="${BDB_LDFLAGS} -static-libstdc++" \
  CPPFLAGS="${BDB_CPPFLAGS} -static-libstdc++"

echo ""
echo "Compiling bitcoin"
echo ""
make STATIC=1
make install

