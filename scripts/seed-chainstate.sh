#!/usr/bin/env bash
set -eo pipefail
set -Eo functrace
shopt -s expand_aliases
export DUMP_VERSION="latest"
export PROFILE="stacks-blockchain"
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH="${ABS_PATH}"
export CONTAINER="postgres_import"
ENV_FILE="${SCRIPTPATH}/.env"
# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"
export CURRENT_USER=$(who am i | awk '{print $1}')

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
    log "Stopping container ${CONTAINER} before exit"
    eval "docker stop ${CONTAINER} > /dev/null  2>&1"
    exit 1
}

if [[ "$EUID" != 0 ]]; then
    exit_error "${COLRED}Error${COLRESET} - Script needs to run as root or with sudo"
fi

# Check if services are running
check_network() {
	local profile="${1}"
	${VERBOSE} && log "Checking if default services are running"
	# Determine if the services are already running
	if [[ $(docker-compose -f "${SCRIPTPATH}/compose-files/common.yaml" --profile ${profile} ps -q) ]]; then
		${VERBOSE} && log "Docker services have a pid"
        log "Stacks Blockchain services are currently running."
        log "  Stop services with: ./manage.sh -n ${NETWORK} -a stop"
        exit_error "  Exiting"
		# Docker is running, return success
	fi
	${VERBOSE} && log "Docker services have no pid"
	return 0
}

download_file(){
    local url=${1}
    local dest=${2}
    local checksum_url=${3:-""}
    local checksum_file=${4:-""}

    log
    log "Checking for ${dest}"

    # Check if file exists locally and if we should verify checksum
    if [[ -f "${dest}" && -n "${checksum_url}" && -n "${checksum_file}" ]]; then
        log "  File exists locally. Checking remote checksum..."

        # Download checksum file if it doesn't exist
        if [[ ! -f "${checksum_file}" ]]; then
            log "  Downloading checksum file: ${checksum_url}"
            curl -s -L ${checksum_url} -o "${checksum_file}" || exit_error "${COLRED}Error${COLRESET} downloading checksum file ${checksum_url}"
        fi

        # Get the remote checksum
        local remote_sha256=$(cat ${checksum_file} | awk {'print $1'})

        # Calculate local file checksum
        local local_sha256=$(sha256sum ${dest} | awk {'print $1'})

        log "  Local SHA256: ${local_sha256}"
        log "  Remote SHA256: ${remote_sha256}"

        # If checksums match, skip download
        if [[ "${local_sha256}" == "${remote_sha256}" ]]; then
            log "  ${COLGREEN}Checksum matches. Skipping download.${COLRESET}"
            return 0
        else
            log "  ${COLYELLOW}Checksum mismatch. Will download fresh copy.${COLRESET}"
        fi
    elif [[ -f "${dest}" ]]; then
        log "  ${COLYELLOW}File exists but cannot verify checksum. Will download fresh copy.${COLRESET}"
    fi

    # Download the file
    local http_code=$(curl --output /dev/null --silent --head -w "%{http_code}" ${url})
    log "Downloading ${url} data to: ${dest}"
    if [[ "${http_code}" && "${http_code}" != "200" ]];then
        exit_error "${COLRED}Error${COLRESET} - ${url} doesn't exist"
    fi
    local size=$( curl -s -L -I ${url} | awk -v IGNORECASE=1 '/^content-length/ { print $2 }' | sed 's/\r$//' )
    local converted_size=$(numfmt --to iec --format "%8.4f" ${size})
    log "  File Download size: ${converted_size}"
    log "  Retrieving: ${url}"
    curl -L -# ${url} -o "${dest}" || exit_error "${COLRED}Error${COLRESET} downloading ${url} to ${dest}"

    # If checksum URL was provided, download it (if not done already)
    if [[ -n "${checksum_url}" && -n "${checksum_file}" && ! -f "${checksum_file}" ]]; then
        log "  Downloading checksum file: ${checksum_url}"
        curl -s -L ${checksum_url} -o "${checksum_file}" || exit_error "${COLRED}Error${COLRESET} downloading checksum file ${checksum_url}"
    fi

    return 0
}

verify_checksum(){
    local local_file=${1}
    local local_sha256=${2}
    local sha256=$(cat ${local_sha256} | awk {'print $1'} )
    local basename=$(basename ${local_file})
    log "  Generating sha256 for ${basename} and comparing to: ${sha256}"
    local sha256sum=$(sha256sum ${local_file} | awk {'print $1'})
    if [ "${sha256}" != "${sha256sum}" ]; then
        log "${COLRED}Error${COLRESET} sha256 mismatch for ${basename}"
        log "  downloaded sha256: ${sha256}"
        log "  calulated sha256: ${sha256sum}"
        exit_error "exiting"
    else
        log "  SHA256 matched for: ${basename}"
        log "  Continuing"
    fi
    return 0
}

log "-- seed-chainstate.sh --"
log "  Starting at $(date "+%D %H:%m:%S")"
log "  Using files/methods from https://docs.hiro.so/hiro-archive"
log "  checking for existence of ${SCRIPTPATH}/persistent-data/${NETWORK}"
if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ];then
    log "  Deleting existing data: ${SCRIPTPATH}/persistent-data/${NETWORK}"
    rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"
fi
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain" > /dev/null  2>&1
mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/postgres" > /dev/null  2>&1

PGDUMP_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-${DUMP_VERSION}.dump"
PGDUMP_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-${DUMP_VERSION}.sha256"
PGDUMP_DEST="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-${DUMP_VERSION}.dump"
PGDUMP_DEST_SHA256="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-${DUMP_VERSION}.dump.sha256"

CHAINDATA_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-${DUMP_VERSION}.tar.gz"
CHAINDATA_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-${DUMP_VERSION}.sha256"
CHAINDATA_DEST="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-${DUMP_VERSION}.tar.gz"
CHAINDATA_DEST_SHA256="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-${DUMP_VERSION}.tar.gz.sha256"


${VERBOSE} && log "  PGDUMP_URL:  ${PGDUMP_URL}"
${VERBOSE} && log "  PGDUMP_URL_SHA256: ${PGDUMP_URL_SHA256}"
${VERBOSE} && log "  PGDUMP_DEST:  ${PGDUMP_DEST}"
${VERBOSE} && log "  PGDUMP_DEST_SHA256: ${PGDUMP_DEST_SHA256}"
${VERBOSE} && log "  CHAINDATA_URL: ${CHAINDATA_URL}"
${VERBOSE} && log "  CHAINDATA_URL_SHA256: ${CHAINDATA_URL_SHA256}"
${VERBOSE} && log "  CHAINDATA_DEST: ${CHAINDATA_DEST}"
${VERBOSE} && log "  CHAINDATA_DEST_SHA256: ${CHAINDATA_DEST_SHA256}"
${VERBOSE} && log "**************************************"

if check_network "${PROFILE}"; then
    ${VERBOSE} && log "Stacks Blockchain services are not running"
    ${VERBOSE} && log "  Continuing"
fi

download_file ${PGDUMP_URL} ${PGDUMP_DEST} ${PGDUMP_URL_SHA256} ${PGDUMP_DEST_SHA256}
verify_checksum ${PGDUMP_DEST} ${PGDUMP_DEST_SHA256}

download_file ${CHAINDATA_URL} ${CHAINDATA_DEST} ${CHAINDATA_URL_SHA256} ${CHAINDATA_DEST_SHA256}
verify_checksum ${CHAINDATA_DEST} ${CHAINDATA_DEST_SHA256}


log
log "Extracting stacks-blockchain chainstate data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
tar -xvf "${CHAINDATA_DEST}" -C "${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain/" || exit_error "${COLRED}Error${COLRESET} extracting stacks-blockchain chainstate data"

log
log "  Chowning data to ${CURRENT_USER}"
chown -R ${CURRENT_USER} "${SCRIPTPATH}/persistent-data/${NETWORK}" || exit_error "${COLRED}Error${COLRESET} setting file permissions"

log
log "Importing postgres data"
log "  Starting postgres container: ${CONTAINER}"

eval "docker run -d --rm --name ${CONTAINER} --shm-size=${PG_SHMSIZE:-256MB} -e POSTGRES_PASSWORD=${PG_PASSWORD} -v ${PGDUMP_DEST}:/tmp/stacks_node_postgres.dump -v ${SCRIPTPATH}/persistent-data/${NETWORK}/postgres:/var/lib/postgresql/data postgres:${POSTGRES_VERSION}-alpine > /dev/null  2>&1" || exit_error "${COLRED}Error${COLRESET} starting postgres container"
log "  Sleeping for 15s to give time for Postgres to start"
sleep 15

log
log "Restoring postgres data from ${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-${DUMP_VERSION}.dump"
echo "docker exec ${CONTAINER} sh -c \"pg_restore --username ${PG_USER} --verbose --create --dbname postgres /tmp/stacks_node_postgres.dump\"" || exit_error "${COLRED}Error${COLRESET} restoring postgres data"
eval "docker exec ${CONTAINER} sh -c \"pg_restore --username ${PG_USER} --verbose --create --dbname postgres /tmp/stacks_node_postgres.dump\"" || exit_error "${COLRED}Error${COLRESET} restoring postgres data"
log "Setting postgres user password from .env for ${PG_USER}"
echo "docker exec -it ${CONTAINER} sh -c \"psql -U ${PG_USER} -c \\\"ALTER USER ${PG_USER} PASSWORD '${PG_PASSWORD}';\\\"\" " || exit_error "${COLRED}Error${COLRESET} setting postgres password for ${PG_USER}"
eval "docker exec -it ${CONTAINER} sh -c \"psql -U ${PG_USER} -c \\\"ALTER USER ${PG_USER} PASSWORD '${PG_PASSWORD}';\\\"\" " || exit_error "${COLRED}Error${COLRESET} setting postgres password for ${PG_USER}"

if [[ ${PG_DATABASE} != "stacks_blockchain_api" && ${PG_SCHEMA} != "stacks_blockchain_api" ]];then
    log "dropping restored schema stacks_blockchain_api.public"
    echo "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"drop SCHEMA if exists public;\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping schema public"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"drop SCHEMA if exists public;\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping schema public"

    log "altering restored schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
    echo "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"ALTER SCHEMA stacks_blockchain_api RENAME TO ${PG_SCHEMA:-public};\\\"\" " || exit_error "${COLRED}Error${COLRESET} altering schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d stacks_blockchain_api -c \\\"ALTER SCHEMA stacks_blockchain_api RENAME TO ${PG_SCHEMA:-public};\\\"\" " || exit_error "${COLRED}Error${COLRESET} altering schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
fi
if [[ ${PG_DATABASE} == "postgres" ]];then
    log "dropping db ${PG_DATABASE}"
    echo "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"DROP database ${PG_DATABASE};\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping db ${PG_DATABASE}"
    eval "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"DROP database ${PG_DATABASE};\\\"\" " || exit_error "${COLRED}Error${COLRESET} dropping db ${PG_DATABASE}"
fi
if [[ ${PG_DATABASE} != "stacks_blockchain_api" ]]; then
    log "renaming db stacks_blockchain_api to ${PG_DATABASE}"
    echo "docker exec -it ${CONTAINER} sh -c \"psql -U postgres -d template1 -c \\\"ALTER DATABASE stacks_blockchain_api RENAME TO ${PG_DATABASE};\\\"\" "|| exit_error "${COLRED}Error${COLRESET} renaming db stacks_blockchain_api to ${PG_DATABASE}"
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
