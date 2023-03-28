#!/usr/bin/env bash
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH="${ABS_PATH}"
export CONTAINER="postgres_import"
ENV_FILE="${SCRIPTPATH}/.env"
# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi

exit_error() {
    # stop container if it is running
    eval "docker stop ${CONTAINER} > /dev/null  2>&1"
    printf "%s\\n" "${1}"
    exit 1
}

COLRED=$'\033[31m' # Red
COLGREEN=$'\033[32m' # Green
COLYELLOW=$'\033[33m' # Yellow
COLBLUE=$'\033[34m' # Blue
COLMAGENTA=$'\033[35m' # Magenta
COLCYAN=$'\033[36m' # Cyan
COLBRRED=$'\033[91m' # Bright Red
COLBOLD=$'\033[1m' # Bold Text
COLRESET=$'\033[0m' # reset color
ERROR="${COLRED}[ Error ]${COLRESET} "
WARN="${COLYELLOW}[ Warn ]${COLRESET} "
INFO="${COLGREEN}[ Success ]${COLRESET} "
EXIT_MSG="${COLRED}[ Exit Error ]${COLRESET} "

if [[ "$EUID" != 0 ]]; then
    exit_error "${COLRED}Error${COLRESET} - Script needs to run as root or with sudo"
fi
CURRENT_USER=$(who am i | awk '{print $1}')

echo "-- seed-chainstate.sh --" 
echo "  Starting at $(date "+%D %H:%m:%S")"
echo "  Using files/methods from https://docs.hiro.so/references/hiro-archive#what-is-the-hiro-archive"
echo "  Setting variables to be used from ${ENV_FILE}"
source "${ENV_FILE}"
set -eo pipefail


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

if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ];then
    confirm "${NETWORK} directory exists.Delete?" || exit_error "${COLRED}Exiting${COLRESET}"
    rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"
fi
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/postgres"


echo ""
confirm "Seed blockchain data from hiro-archiver?" || exit_error "${COLRED}Exiting${COLRESET}"

PGDUMP_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.sha256"
PGDUMP_DEST="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_DEST_SHA256="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump.sha256"

CHAINDATA_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.sha256"
CHAINDATA_DEST="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_DEST_SHA256="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz.sha256"

echo "PGDUMP_URL:  ${PGDUMP_URL}"
echo "PGDUMP_URL_SHA256: ${PGDUMP_URL_SHA256}"
echo "PGDUMP_DEST:  ${PGDUMP_DEST}"
echo "PGDUMP_DEST_SHA256: ${PGDUMP_DEST_SHA256}"
echo "CHAINDATA_URL: ${CHAINDATA_URL}"
echo "CHAINDATA_URL_SHA256: ${CHAINDATA_URL_SHA256}"
echo "CHAINDATA_DEST: ${CHAINDATA_DEST}"
echo "CHAINDATA_DEST_SHA256: ${CHAINDATA_DEST_SHA256}"
echo
echo "**************************************"
echo 


## check if the URL's are valid and a file is actually there before doing anything. 
## if not, print an error message and some possible solutions

echo 
echo
echo "Downloading stacks-blockchain-api postgres ${POSTGRES_VERSION} data to: ${PGDUMP_DEST}"
ARCHIVE_HTTP_CODE=$(curl --output /dev/null --silent --head --fail -w "%{http_code}" ${PGDUMP_URL})
if [[ "${ARCHIVE_HTTP_CODE}" && "${ARCHIVE_HTTP_CODE}" != "200" ]];then
    exit_error "${COLRED}Error${COLRESET} - ${PGDUMP_URL} doesn't exist"
fi
SIZE=$( curl -s -L -I ${PGDUMP_URL} | awk -v IGNORECASE=1 '/^content-length/ { print $2 }' | sed 's/\r$//' )
CONVERTED_SIZE=$(numfmt --to iec --format "%8.4f" ${SIZE})
echo "  File Download size: ${CONVERTED_SIZE}"
echo "  Retrieving URL: ${PGDUMP_URL}"
curl -L ${PGDUMP_URL} -o "${PGDUMP_DEST}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain-api pg data"
curl -L ${PGDUMP_URL_SHA256} -o "${PGDUMP_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain-api pg sha256"
## verify sha256 of downloaded file
SHA256=$(cat ${PGDUMP_DEST_SHA256} | awk {'print $1'} )
echo "    Generating sha256 for ${PGDUMP_DEST} and comparing to: ${SHA256}"
SHA256SUM=$(sha256sum ${PGDUMP_DEST} | awk {'print $1'})
if [ "${SHA256}" != "${SHA256SUM}" ]; then
    echo "${COLRED}Error${COLRESET} sha256 mismatch for ${PGDUMP_DEST}"
    echo "  downloaded sha256: ${SHA256}"
    echo "  calulated sha256: ${SHA256SUM}"
    exit 1
else
    echo "  ${PGDUMP_DEST} sha256 matches. continuing"
fi
unset SIZE
unset CONVERTED_SIZE
unset SHA256
unset SHA256SUM
unset ARCHIVE_HTTP_CODE

echo 
echo
echo "Downloading stacks-blockchain ${STACKS_BLOCKCHAIN_VERSION} data to: ${CHAINDATA_DEST}"
ARCHIVE_HTTP_CODE=$(curl --output /dev/null --silent --head --fail -w "%{http_code}" ${CHAINDATA_URL})
if [[ "${ARCHIVE_HTTP_CODE}" && "${ARCHIVE_HTTP_CODE}" != "200" ]];then
    exit_error "${COLRED}Error${COLRESET} - ${CHAINDATA_URL} doesn't exist"
fi
SIZE=$( curl -s -L -I ${CHAINDATA_URL} | awk -v IGNORECASE=1 '/^content-length/ { print $2 }' | sed 's/\r$//' )
CONVERTED_SIZE=$(numfmt --to iec --format "%8.4f" ${SIZE})
echo "  File Download size: ${CONVERTED_SIZE}"
echo "  Retrieving URL: ${CHAINDATA_URL}"
curl -L ${CHAINDATA_URL}  -o "${CHAINDATA_DEST}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain chainstate data"
curl -L ${CHAINDATA_URL_SHA256} -o "${CHAINDATA_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain chainstate sha256"
## verify sha256 of downloaded file
SHA256=$(cat ${CHAINDATA_DEST_SHA256} | awk {'print $1'})
echo "    Generating sha256 for ${CHAINDATA_DEST} and comparing to: ${SHA256}"
SHA256SUM=$(sha256sum ${CHAINDATA_DEST} | awk {'print $1'})
if [ "${SHA256}" != "${SHA256SUM}" ]; then
    echo "${COLRED}Error${COLRESET} sha256 mismatch for ${CHAINDATA_DEST}"
    echo "  downloaded sha256: ${SHA256}"
    echo "  calulated sha256: ${SHA256SUM}"
    exit 1
else
    echo "  ${CHAINDATA_DEST} sha256 matches. continuing"
fi
unset SIZE
unset CONVERTED_SIZE
unset SHA256
unset SHA256SUM
unset ARCHIVE_HTTP_CODE

echo
echo "Extracting stacks-blockchain chainstate data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
tar -xvf "${CHAINDATA_DEST}" -C "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain/" || exit_error "${COLRED}Error${COLRESET} extracting stacks-blockchain chainstate data"

echo
echo "  Chowning data to ${CURRENT_USER}"
chown -R ${CURRENT_USER} "${SCRIPTPATH}/persistent-data/${NETWORK}" || exit_error "${COLRED}Error${COLRESET} setting file permissions"

echo
echo "Importing postgres data"
echo "  Starting postgres container: ${CONTAINER}"

# eval "docker run -d --rm --name ${CONTAINER} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${SCRIPTPATH}/scripts/postgres-initdb.sh:/docker-entrypoint-initdb.d/postgres-initdb.sh:ro -v ${PGDUMP_DEST}:/tmp/stacks_node_postgres.dump -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} starting postgres container"
eval "docker run -d --rm --name ${CONTAINER} --shm-size=${PG_SHMSIZE:-256MB} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${PGDUMP_DEST}:/tmp/stacks_node_postgres.dump -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} starting postgres container"
echo "  Sleeping for 15s to give time for Postgres to start"
sleep 15

echo
echo "Restoring postgres data from ${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
eval "docker exec ${CONTAINER} sh -c \"pg_restore --username ${PG_USER} --verbose --create --dbname postgres /tmp/stacks_node_postgres.dump\"" || exit_error "${COLRED}Error${COLRESET} restoring postgres data"
echo "Setting postgres user password from .env for ${PG_USER}"
eval "docker exec -it ${CONTAINER} sh -c \"psql -U ${PG_USER} -c \\\"ALTER USER ${PG_USER} PASSWORD '${PG_PASSWORD}';\\\"\" " || exit_error "${COLRED}Error${COLRESET} setting postgres password for ${PG_USER}"



# modify restored DB to match .env
# psql -U postgres -d stacks_blockchain_api -c "drop SCHEMA public;" 
# psql -U postgres -d stacks_blockchain_api -c "ALTER SCHEMA stacks_blockchain_api RENAME TO public;" 
# psql -U postgres -d template1 -c "DROP database postgres;"
# psql -U postgres -d template1 -c "ALTER DATABASE stacks_blockchain_api RENAME TO postgres;"

if [[ ${PG_DATABASE} != "stacks_blockchain_api" && ${PG_SCHEMA} != "stacks_blockchain_api" ]];then
    echo "dropping restored schema stacks_blockchain_api.public"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"drop SCHEMA if exists public;\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping schema public"

    echo "altering restored schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"ALTER SCHEMA stacks_blockchain_api RENAME TO ${PG_SCHEMA:-public};\\\"\" " || exit_error "${COLRED}Error${COLRESET} altering schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
fi
if [[ ${PG_DATABASE} == "postgres" ]];then
    echo "dropping db ${PG_DATABASE}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"DROP database ${PG_DATABASE};\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping db ${PG_DATABASE}"
fi
if [[ ${PG_DATABASE} != "stacks_blockchain_api" ]]; then
    echo "renaming db stacks_blockchain_api to ${PG_DATABASE}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"ALTER DATABASE stacks_blockchain_api RENAME TO ${PG_DATABASE};\\\"\" "|| exit_error "${COLRED}Error${COLRESET} renaming db stacks_blockchain_api to ${PG_DATABASE}"
fi
echo "Stopping postgres container"
eval "docker stop ${CONTAINER} > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} stopping postgres container ${CONTAINER}"

echo "Deleting downloaded archive files"
if [ -f ${PGDUMP_DEST} ]; then
    eval "rm -f ${PGDUMP_DEST}" || exit_error "${COLRED}Error${COLRESET} deleting ${PGDUMP_DEST}"
fi
if [ -f ${PGDUMP_DEST_SHA256} ]; then
    eval "rm -f ${PGDUMP_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} deleting ${PGDUMP_DEST_SHA256}"
fi
if [ -f ${CHAINDATA_DEST} ]; then
    eval "rm -f ${CHAINDATA_DEST}" || exit_error "${COLRED}Error${COLRESET} deleting ${CHAINDATA_DEST}"
fi
if [ -f ${CHAINDATA_DEST_SHA256} ]; then
    eval "rm -f ${CHAINDATA_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} deleting ${CHAINDATA_DEST_SHA256}"
fi

echo "Exiting successfully at $(date "+%D %H:%m:%S")"
exit 0
