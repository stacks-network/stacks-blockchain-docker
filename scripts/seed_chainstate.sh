

#!/usr/bin/env bash
export NETWORK=mainnet
export API_VERSION=5.0.0
export STACKS_VERSION=2.05.0.3.0
export POSTGRES_VERSION=14
export CONTAINER=postgres_import

set -eo pipefail

echo "Setting variables to be used throughout upgrade"
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH=${ABS_PATH}
# echo $SCRIPTPATH
mkdir -p ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain
mkdir -p ${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay
mkdir -p ${SCRIPTPATH}/persistent-data/${NETWORK}/postgres
source .env

# Function to ask for confirmation. Loop until valid input is received
confirm() {
    # y/n confirmation. loop until valid response is received
    while true; do
        read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
        case ${REPLY} in
            [yY]) echo ; return 0 ;;
            [nN]) echo ; return 1 ;;
            *) printf "\\033[31m %s \\n\\033[0m" "invalid input"
        esac 
    done  
}

exit_error() {
    printf "%s\\n" "${1}"
    exit 1
}


echo "using files/methods from https://docs.hiro.so/references/hiro-archiver#what-is-the-hiro-archiver"
echo ""
confirm "Seed blockchain data from hiro-archiver?" || exit_error "${COLRED}Exiting${COLRESET}"

echo "  Downloading stacks-blockchain data (${STACKS_VERSION} to: ${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_VERSION}-latest.tar.gz"
curl -L https://storage.googleapis.com/hirosystems-archive/${NETWORK}/blockchain/${NETWORK}-blockchain-${STACKS_VERSION}-latest.tar.gz -o ${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_VERSION}-latest.tar.gz

echo "  Downloading stacks-blockchain-api data (${API_VERSION} to: ${SCRIPTPATH}/${NETWORK}-blockchain-api-${API_VERSION}-latest.tar.gz"
curl -L https://storage.googleapis.com/hirosystems-archive/${NETWORK}/api/${NETWORK}-blockchain-api-${API_VERSION}-latest.tar.gz -o ${SCRIPTPATH}/${NETWORK}-blockchain-api-${API_VERSION}-latest.tar.gz

echo "  Downloading postgres data (${POSTGRES_VERSION} to: ${SCRIPTPATH}/${NETWORK}-postgres-${POSTGRES_VERSION}-latest.tar.gz"
curl -L https://storage.googleapis.com/hirosystems-archive/${NETWORK}/postgres/${NETWORK}-postgres-${POSTGRES_VERSION}-latest.tar.gz -o ${SCRIPTPATH}/${NETWORK}-postgres-${POSTGRES_VERSION}-latest.tar.gz

echo "  Extracting stacks-blockchain data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
tar -xvf ${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_VERSION}-latest.tar.gz -C ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain/

echo "  Extracting stacks-blockchain-api data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay/"
tar -xvf ${SCRIPTPATH}/${NETWORK}-blockchain-api-${API_VERSION}-latest.tar.gz -C ${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay/

echo
echo "*** Postgres Import ***"
echo "  Starting postgres container"

eval "sudo docker run -d --rm --name ${CONTAINER} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${SCRIPTPATH}/${NETWORK}-postgres-${POSTGRES_VERSION}-latest.tar.gz:/tmp/stacks_node_postgres.tar.gz -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "[ export ] Error starting postgres container"
echo "  Sleeping for 15s to give time for Postgres to start"
sleep 15

echo "  Import backed up postgres data from ${SCRIPTPATH}/${NETWORK}-postgres-${POSTGRES_VERSION}-latest.tar.gz"
eval "sudo docker exec ${CONTAINER} sh -c \"pg_restore -U postgres -v -C -d postgres /tmp/stacks_node_postgres.tar.gz\"" || exit_error "[ export ] Error restoring postgres data"

echo "  [ import ] Restore postgres password from .env"
sudo docker exec -it ${CONTAINER} \
    sh -c "psql -U postgres -c \"ALTER USER postgres PASSWORD '${PG_PASSWORD}';\""


echo "  [ import ] Stopping postgres container"
eval "sudo docker stop ${CONTAINER} > /dev/null  2>&1" || exit_error "[ export ] Error stopping postgres container"
