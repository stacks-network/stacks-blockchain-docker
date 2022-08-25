#!/usr/bin/env bash

set -eo pipefail

echo "Setting variables to be used throughout upgrade"
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH=${ABS_PATH}
echo $SCRIPTPATH
mkdir ${SCRIPTPATH}/pg_dump
source .env

exit_error() {
    echo "${1}"
    exit 1
}

###########################################################
##  Export postgres data
###########################################################
echo "*** Postgres Export ***"
echo "  [ export ] Starting postgres container"
eval "sudo docker run -d --rm --name postgres_dump -v ${SCRIPTPATH}/pg_dump:/tmp -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data -w /tmp postgres:13-alpine" || exit_error "[ export ] Error starting postgres container"

echo "  [ export ] Dump postgres data to ${SCRIPTPATH}/pg_dump/dump.sql"
eval "sudo docker exec postgres_dump sh -c \"pg_dumpall -U postgres > /tmp/dump.sql\"" || exit_error "[ export ] Error dumping postgres data"

echo "  [ export ] Stopping postgres container"
eval "sudo docker stop postgres_dump" exit_error "[ export ] Error stopping postgres container"

echo "  [ export ] Remove mapped docker volume"
eval "sudo rm -rf ${SCRIPTPATH}/persistent-data/mainnet/postgres && mkdir -p ${SCRIPTPATH}/persistent-data/mainnet/postgres" || exit_error "[ export ] Error removing postgres data"

###########################################################
##  Import postgres data
###########################################################

echo "*** Postgres Import ***"
echo "  [import] Starting postgres container"
eval "sudo docker run -d --rm --name postgres_dump -v ${SCRIPTPATH}/pg_dump:/tmp -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data -e POSTGRES_PASSWORD=${PG_PASSWORD} -w /tmp postgres:14-alpine" || exit_error "[ import ] Error starting postgres container"

echo "  [import] Import backed up postgres data"
eval "sudo docker exec postgres_dump sh -c \"psql -U postgres -d template1 < /tmp/dump.sql\"" || exit_error "[ import ] Error importing postgres data"

echo "  [import] Restore postgres data from ${SCRIPTPATH}/pg_dump/dump.sql"
sudo docker exec -it postgres_dump \
    sh -c "psql -U postgres -c \"ALTER USER postgres PASSWORD '${PG_PASSWORD}';\""

echo "  [import] Stopping postgres container"
eval "sudo docker stop postgres_dump" || exit_error "[import] Error stopping postgres container"

echo "** Postgres upgrade Done **"
exit 0

