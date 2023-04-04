
#!/usr/bin/env bash
set -eo pipefail
set -Eo functrace
shopt -s expand_aliases
export NETWORK="mainnet"
export PROFILE="stacks-blockchain"
# CURRENT_USER=$(who am i | awk '{print $1}')
ABS_PATH="$( cd -- "$(dirname '${0}')" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH="${ABS_PATH}"
export CONTAINER="postgres_import"
ENV_FILE="${SCRIPTPATH}/.env"
# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"
export DOCKER_NETWORK="${DOCKER_NETWORK}"
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

PGDUMP_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain-api-pg/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.sha256"
PGDUMP_DEST="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
PGDUMP_DEST_SHA256="${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump.sha256"

CHAINDATA_URL="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_URL_SHA256="https://archive.hiro.so/${NETWORK}/stacks-blockchain/${NETWORK}-stacks-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.sha256"
CHAINDATA_DEST="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz"
CHAINDATA_DEST_SHA256="${SCRIPTPATH}/${NETWORK}-blockchain-${STACKS_BLOCKCHAIN_VERSION}-latest.tar.gz.sha256"


    log "Stopping container ${CONTAINER} before exit"
	${VERBOSE} && log "Checking if default services are running"
		${VERBOSE} && log "Docker services have a pid"
        log "Stacks Blockchain services are currently running."
        log "  Stop services with: ./manage.sh -n ${NETWORK} -a stop"
	${VERBOSE} && log "Docker services have no pid"
    log "Downloading ${url} data to: ${DEST}"
    log "  File Download size: ${converted_size}"
    log "  Retrieving: ${url}"
    log "  Generating sha256 for ${basename} and comparing to: ${sha256}"
        log "${COLRED}Error${COLRESET} sha256 mismatch for ${basename}"
        log "  downloaded sha256: ${sha256}"
        log "  calulated sha256: ${sha256sum}"
        log "  SHA256 matched for: ${basename}"
        log "  Continuing"
log "-- seed-chainstate.sh --" 
log "  Starting at $(date "+%D %H:%m:%S")"
log "  Using files/methods from https://docs.hiro.so/references/hiro-archive#what-is-the-hiro-archive"
log "  checking for existence of ${SCRIPTPATH}/persistent-data/${NETWORK}"
    log "  Deleting existing data: ${SCRIPTPATH}/persistent-data/${NETWORK}"
${VERBOSE} && log "  PGDUMP_URL:  ${PGDUMP_URL}"
${VERBOSE} && log "  PGDUMP_URL_SHA256: ${PGDUMP_URL_SHA256}"
${VERBOSE} && log "  PGDUMP_DEST:  ${PGDUMP_DEST}"
${VERBOSE} && log "  PGDUMP_DEST_SHA256: ${PGDUMP_DEST_SHA256}"
${VERBOSE} && log "  CHAINDATA_URL: ${CHAINDATA_URL}"
${VERBOSE} && log "  CHAINDATA_URL_SHA256: ${CHAINDATA_URL_SHA256}"
${VERBOSE} && log "  CHAINDATA_DEST: ${CHAINDATA_DEST}"
${VERBOSE} && log "  CHAINDATA_DEST_SHA256: ${CHAINDATA_DEST_SHA256}"
${VERBOSE} && log "**************************************"
    ${VERBOSE} && log "Stacks Blockchain services are not running"
    ${VERBOSE} && log "  Continuing"
log "Extracting stacks-blockchain chainstate data to: ${SCRIPTPATH}/persistent-data/${NETWORK}/stacks-blockchain"
log "  Chowning data to ${CURRENT_USER}"
log 
log "Importing postgres data"
log "  Starting postgres container: ${CONTAINER}"
log "  Sleeping for 15s to give time for Postgres to start"
log "Restoring postgres data from ${SCRIPTPATH}/stacks-blockchain-api-pg-${POSTGRES_VERSION}-${STACKS_BLOCKCHAIN_API_VERSION}-latest.dump"
log "Setting postgres user password from .env for ${PG_USER}"
    log "dropping restored schema stacks_blockchain_api.public"
    log "altering restored schema stacks_blockchain_api -> ${PG_SCHEMA:-public}"
    log "dropping db ${PG_DATABASE}"
    log "renaming db stacks_blockchain_api to ${PG_DATABASE}"
log "Stopping postgres container"
log "Deleting downloaded archive files"
log "Exiting successfully at $(date "+%D %H:%m:%S")"
