#!/usr/bin/env bash

set -eo pipefail

echo "Setting variables to be used throughout upgrade"
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH=${ABS_PATH}
# echo $SCRIPTPATH
mkdir -p ${SCRIPTPATH}/pg_dump
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


confirm "Convert Postgres 13 data to Postgres ${POSTGRES_VERSION} ?" || exit_error "${COLRED}Exiting${COLRESET}"

if [ -f  "${SCRIPTPATH}/pg_dump/dump.sql" ]; then
    confirm "Overwrite existing pg_dump?" || exit_error "${COLRED}Exiting${COLRESET}"
    rm -f "${SCRIPTPATH}/pg_dump/dump.sql"
fi

###########################################################
##  Export postgres data
###########################################################
echo "*** Postgres Export ***"
echo "  [ export ] Starting postgres container"
eval "sudo docker run -d --rm --name postgres_dump -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${SCRIPTPATH}/pg_dump:/tmp -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data -w /tmp postgres:13-alpine > /dev/null  2>&1" || exit_error "[ export ] Error starting postgres container"

echo "  [ export ] Sleeping for 15s to give time for Postgres to start"
sleep 15

echo "  [ export ] Dump postgres data to ${SCRIPTPATH}/pg_dump/dump.sql"
eval "sudo docker exec postgres_dump sh -c \"pg_dumpall -U postgres > /tmp/dump.sql\"" || exit_error "[ export ] Error dumping postgres data"

echo "  [ export ] Stopping postgres container"
eval "sudo docker stop postgres_dump > /dev/null  2>&1" || exit_error "[ export ] Error stopping postgres container"

echo "  [ export ] Remove mapped docker volume"
eval "sudo rm -rf ${SCRIPTPATH}/persistent-data/mainnet/postgres && mkdir -p ${SCRIPTPATH}/persistent-data/mainnet/postgres" || exit_error "[ export ] Error removing postgres data"

###########################################################
##  Import postgres data
###########################################################

echo
echo "*** Postgres Import ***"
echo "  [ import ] Starting postgres container"
eval "sudo docker run -d --rm --name postgres_dump -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${SCRIPTPATH}/pg_dump:/tmp -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data -e POSTGRES_PASSWORD=${PG_PASSWORD} -w /tmp postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "[ import ] Error starting postgres container"

echo "  [ export ] Sleeping for 15s to give time for Postgres to start"
sleep 15

echo "  [ import ] Import backed up postgres data from ${SCRIPTPATH}/pg_dump/dump.sql"
eval "sudo docker exec postgres_dump sh -c \"psql -U postgres -d template1 < /tmp/dump.sql\"" || exit_error "[ import ] Error importing postgres data"

echo "  [ import ] Restore postgres password from .env"
sudo docker exec -it postgres_dump \
    sh -c "psql -U postgres -c \"ALTER USER postgres PASSWORD '${PG_PASSWORD}';\""

echo
echo "*** Removing pg_dump sql file"
eval "rm -rf ${SCRIPTPATH}/pg_dump"
echo "** Postgres upgrade Done **"
exit 0

