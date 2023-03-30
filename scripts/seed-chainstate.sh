#!/usr/bin/env bash
set -eo pipefail
set -Eo functrace
shopt -s expand_aliases

### need to check if services are currently running

ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH="${ABS_PATH}"
export CONTAINER="postgres_import"
ENV_FILE="${SCRIPTPATH}/.env"
# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"


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

alias log="logger"
alias log_error='logger "${ERROR}"'
alias log_warn='logger "${WARN}"'
alias log_info='logger "${INFO}"'
alias log_exit='exit_error "${EXIT_MSG}"'
if ${VERBOSE}; then
	alias log='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}"' 
	alias log_info='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${INFO}"' 
	alias log_warn='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${WARN}"' 
	alias log_error='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${ERROR}"'
	alias log_exit='exit_error  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${EXIT_MSG}"' 
fi

logger() {
    if ${VERBOSE}; then
        printf "%s %-25s %-10s %-10s %-25s %s\\n" "${1}" "${2}" "${3}" "${DEBUG}" "${4}" "${5}"
    else
        printf "%-25s %s\\n" "${1}" "${2}"
    fi
}

exit_error() {
    if ${VERBOSE}; then
        printf "%s %-25s %-10s %-10s %-25s %s\\n\\n" "${1}" "${2}" "${DEBUG}" "${3}" "${4}" "${5}"
	else
        printf "%-25s %s\\n\\n" "${1}" "${2}"
    fi
    exit 1
}

if [[ "$EUID" != 0 ]]; then
    exit_error "${COLRED}Error${COLRESET} - Script needs to run as root or with sudo"
fi
CURRENT_USER=$(who am i | awk '{print $1}')

log "-- seed-chainstate.sh --" 
log "  Starting at $(date "+%D %H:%m:%S")"
log "  Using files/methods from https://docs.hiro.so/references/hiro-archive#what-is-the-hiro-archive"

# # Function to ask for confirmation. Loop until valid input is received
# confirm() {
#     # y/n confirmation. loop until valid response is received
#     while true; do
#         read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
#         case ${REPLY} in
#             [yY]) echo ; return 0 ;;
#             [nN]) echo ; return 1 ;;
#             *) printf "\\033[31m %s \\n\\033[0m" "invalid input"
#         esac 
#     done  
# }
log "checking for existence of ${SCRIPTPATH}/persistent-data/${NETWORK}"
if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ];then
    log "Deleting existing data: ${SCRIPTPATH}/persistent-data/${NETWORK}"
    # confirm "${NETWORK} directory exists.Delete?" || exit_error "${COLRED}Exiting${COLRESET}"
    rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"
fi
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/postgres"


log ""
log "Seeding chainstate data"
# confirm "Seed blockchain data from hiro-archiver?" || exit_error "${COLRED}Exiting${COLRESET}"

PGDUMP_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.sha256"
PGDUMP_DEST="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_DEST_SHA256="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump.sha256"

CHAINDATA_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.sha256"
CHAINDATA_DEST="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_DEST_SHA256="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz.sha256"

log "  PGDUMP_URL:  ${PGDUMP_URL}"
log "  PGDUMP_URL_SHA256: ${PGDUMP_URL_SHA256}"
log "  PGDUMP_DEST:  ${PGDUMP_DEST}"
log "  PGDUMP_DEST_SHA256: ${PGDUMP_DEST_SHA256}"
log "  CHAINDATA_URL: ${CHAINDATA_URL}"
log "  CHAINDATA_URL_SHA256: ${CHAINDATA_URL_SHA256}"
log "  CHAINDATA_DEST: ${CHAINDATA_DEST}"
log "  CHAINDATA_DEST_SHA256: ${CHAINDATA_DEST_SHA256}"
log
log "**************************************"
log 


## check if the URL's are valid and a file is actually there before doing anything. 
## if not, print an error message and some possible solutions

log 
log
log "Downloading stacks-blockchain-api postgres ${POSTGRES_VERSION} data to: ${PGDUMP_DEST}"
ARCHIVE_HTTP_CODE=$(curl --output /dev/null --silent --head -w "%{http_code}" ${PGDUMP_URL})
if [[ "${ARCHIVE_HTTP_CODE}" && "${ARCHIVE_HTTP_CODE}" != "200" ]];then
    exit_error "${COLRED}Error${COLRESET} - ${PGDUMP_URL} doesn't exist"
fi
SIZE=$( curl -s -L -I ${PGDUMP_URL} | awk -v IGNORECASE=1 '/^content-length/ { print $2 }' | sed 's/\r$//' )
CONVERTED_SIZE=$(numfmt --to iec --format "%8.4f" ${SIZE})
log "  File Download size: ${CONVERTED_SIZE}"
log "  Retrieving URL: ${PGDUMP_URL}"
curl -L ${PGDUMP_URL} -o "${PGDUMP_DEST}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain-api pg data"
curl -L ${PGDUMP_URL_SHA256} -o "${PGDUMP_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain-api pg sha256"
## verify sha256 of downloaded file
SHA256=$(cat ${PGDUMP_DEST_SHA256} | awk {'print $1'} )
log "    Generating sha256 for ${PGDUMP_DEST} and comparing to: ${SHA256}"
SHA256SUM=$(sha256sum ${PGDUMP_DEST} | awk {'print $1'})
if [ "${SHA256}" != "${SHA256SUM}" ]; then
    log "${COLRED}Error${COLRESET} sha256 mismatch for ${PGDUMP_DEST}"
    log "  downloaded sha256: ${SHA256}"
    log "  calulated sha256: ${SHA256SUM}"
    exit 1
else
    log "  ${PGDUMP_DEST} sha256 matches. continuing"
fi
unset SIZE
unset CONVERTED_SIZE
unset SHA256
unset SHA256SUM
unset ARCHIVE_HTTP_CODE

log 
log
log "Downloading stacks-blockchain ${STACKS_BLOCKCHAIN_VERSION} data to: ${CHAINDATA_DEST}"
ARCHIVE_HTTP_CODE=$(curl --output /dev/null --silent --head -w "%{http_code}" ${CHAINDATA_URL})
if [[ "${ARCHIVE_HTTP_CODE}" && "${ARCHIVE_HTTP_CODE}" != "200" ]];then
    exit_error "${COLRED}Error${COLRESET} - ${CHAINDATA_URL} doesn't exist"
fi
SIZE=$( curl -s -L -I ${CHAINDATA_URL} | awk -v IGNORECASE=1 '/^content-length/ { print $2 }' | sed 's/\r$//' )
CONVERTED_SIZE=$(numfmt --to iec --format "%8.4f" ${SIZE})
log "  File Download size: ${CONVERTED_SIZE}"
log "  Retrieving URL: ${CHAINDATA_URL}"
curl -L ${CHAINDATA_URL}  -o "${CHAINDATA_DEST}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain chainstate data"
curl -L ${CHAINDATA_URL_SHA256} -o "${CHAINDATA_DEST_SHA256}" || exit_error "${COLRED}Error${COLRESET} downloading stacks-blockchain chainstate sha256"
## verify sha256 of downloaded file
SHA256=$(cat ${CHAINDATA_DEST_SHA256} | awk {'print $1'})
log "    Generating sha256 for ${CHAINDATA_DEST} and comparing to: ${SHA256}"
SHA256SUM=$(sha256sum ${CHAINDATA_DEST} | awk {'print $1'})
if [ "${SHA256}" != "${SHA256SUM}" ]; then
    log "${COLRED}Error${COLRESET} sha256 mismatch for ${CHAINDATA_DEST}"
    log "  downloaded sha256: ${SHA256}"
    log "  calulated sha256: ${SHA256SUM}"
    exit 1
else
    log "  ${CHAINDATA_DEST} sha256 matches. continuing"
fi
unset SIZE
unset CONVERTED_SIZE
unset SHA256
unset SHA256SUM
unset ARCHIVE_HTTP_CODE

log
log "Extracting stacks-blockchain chainstate data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
tar -xvf "${CHAINDATA_DEST}" -C "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain/" || exit_error "${COLRED}Error${COLRESET} extracting stacks-blockchain chainstate data"

log
log "  Chowning data to ${CURRENT_USER}"
chown -R ${CURRENT_USER} "${SCRIPTPATH}/persistent-data/${NETWORK}" || exit_error "${COLRED}Error${COLRESET} setting file permissions"

log 
log "Importing postgres data"
log "  Starting postgres container: ${CONTAINER}"

# eval "docker run -d --rm --name ${CONTAINER} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${SCRIPTPATH}/scripts/postgres-initdb.sh:/docker-entrypoint-initdb.d/postgres-initdb.sh:ro -v ${PGDUMP_DEST}:/tmp/stacks_node_postgres.dump -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} starting postgres container"
eval "docker run -d --rm --name ${CONTAINER} --shm-size=${PG_SHMSIZE:-256MB} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${PGDUMP_DEST}:/tmp/stacks_node_postgres.dump -v ${SCRIPTPATH}/persistent-data/mainnet/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} starting postgres container"
log "  Sleeping for 15s to give time for Postgres to start"
sleep 15

log
log "Restoring postgres data from ${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
eval "docker exec ${CONTAINER} sh -c \"pg_restore --username ${PG_USER} --verbose --create --dbname postgres /tmp/stacks_node_postgres.dump\"" || exit_error "${COLRED}Error${COLRESET} restoring postgres data"
log "Setting postgres user password from .env for ${PG_USER}"
eval "docker exec -it ${CONTAINER} sh -c \"psql -U ${PG_USER} -c \\\"ALTER USER ${PG_USER} PASSWORD '${PG_PASSWORD}';\\\"\" " || exit_error "${COLRED}Error${COLRESET} setting postgres password for ${PG_USER}"



# modify restored DB to match .env
# psql -U postgres -d stacks_blockchain_api -c "drop SCHEMA public;" 
# psql -U postgres -d stacks_blockchain_api -c "ALTER SCHEMA stacks_blockchain_api RENAME TO public;" 
# psql -U postgres -d template1 -c "DROP database postgres;"
# psql -U postgres -d template1 -c "ALTER DATABASE stacks_blockchain_api RENAME TO postgres;"

if [[ ${PG_DATABASE} != "stacks_blockchain_api" && ${PG_SCHEMA} != "stacks_blockchain_api" ]];then
    log "dropping restored schema stacks_blockchain_api.public"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"drop SCHEMA if exists public;\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping schema public"

    log "altering restored schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"ALTER SCHEMA stacks_blockchain_api RENAME TO ${PG_SCHEMA:-public};\\\"\" " || exit_error "${COLRED}Error${COLRESET} altering schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
fi
if [[ ${PG_DATABASE} == "postgres" ]];then
    log "dropping db ${PG_DATABASE}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"DROP database ${PG_DATABASE};\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping db ${PG_DATABASE}"
fi
if [[ ${PG_DATABASE} != "stacks_blockchain_api" ]]; then
    log "renaming db stacks_blockchain_api to ${PG_DATABASE}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"ALTER DATABASE stacks_blockchain_api RENAME TO ${PG_DATABASE};\\\"\" "|| exit_error "${COLRED}Error${COLRESET} renaming db stacks_blockchain_api to ${PG_DATABASE}"
fi
log "Stopping postgres container"
eval "docker stop ${CONTAINER} > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} stopping postgres container ${CONTAINER}"

log "Deleting downloaded archive files"
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

log "Exiting successfully at $(date "+%D %H:%m:%S")"
exit 0
