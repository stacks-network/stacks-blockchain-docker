#!/usr/bin/env bash

set -eo pipefail
set -Eo functrace
shopt -s expand_aliases

# The following values can be overridden in the .env file or cmd line. adding some defaults here
export NETWORK="mainnet"
export ACTION=""
export PROFILE="stacks-blockchain"
SIGNER=false
STACKS_CHAIN_ID="2147483648"
STACKS_SHUTDOWN_TIMEOUT=1200 # default to 20 minutes, during sync it can take a long time to stop the runloop
LOG_TAIL="100"
FLAGS="proxy"
LOG_OPTS="-f --tail ${LOG_TAIL}"
VERBOSE=false
REVERT_BNS=false
REVERT_EVENTS=false

# # Base colors
# COLBLACK=$'\033[30m' # Black
COLRED=$'\033[31m' # Red
COLGREEN=$'\033[32m' # Green
COLYELLOW=$'\033[33m' # Yellow
COLBLUE=$'\033[34m' # Blue
COLMAGENTA=$'\033[35m' # Magenta
COLCYAN=$'\033[36m' # Cyan
# COLWHITE=$'\033[37m' # White

# # Bright colors
COLBRRED=$'\033[91m' # Bright Red
# COLBRGREEN=$'\033[92m' # Bright Green
# COLBRYELLOW=$'\033[93m' # Bright Yellow
# COLBRBLUE=$'\033[94m' # Bright Blue
# COLBRMAGENTA=$'\033[95m' # Bright Magenta
# COLBRCYAN=$'\033[96m' # Bright Cyan
# COLBRWHITE=$'\033[97m' # Bright White

# # Text formatting
# COLITALIC=$'\033[3m' # Italic
# COLUNDERLINE=$'\033[4m' # underline
# COLITALIC=$'\033[3m' # italic
# COLUNDERLINE=$'\033[4m' # underline
COLBOLD=$'\033[1m' # Bold Text

# # Text rest to default
COLRESET=$'\033[0m' # reset color


ERROR="${COLRED}[ Error ]${COLRESET} "
WARN="${COLYELLOW}[ Warn ]${COLRESET} "
INFO="${COLGREEN}[ Success ]${COLRESET} "
EXIT_MSG="${COLRED}[ Exit Error ]${COLRESET} "
DEBUG="[ DEBUG ] "

# Use .env in the local dir
#     - This var is also used in the docker compose yaml files
ABS_PATH="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH=${ABS_PATH}
ENV_FILE="${SCRIPTPATH}/.env"
ENV_FILE_TMP="${SCRIPTPATH}/.env.tmp"

# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"


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

# Populate hardcoded list of default services for shutdown order and log files export
${VERBOSE} && log "Creating list of default services"
DEFAULT_SERVICES=(
	stacks-blockchain
	stacks-blockchain-api
	postgres
)
${VERBOSE} && log "DEFAULT_SERVICES: ${DEFAULT_SERVICES[*]}"

# Populate list of supported flags based on files in ./compose-files/extra-services
OPTIONAL_FLAGS=""
SUPPORTED_FLAGS=()
${VERBOSE} && log "Creating list of supported flags"
for i in "${SCRIPTPATH}"/compose-files/extra-services/*.yaml; do
	flag=$(basename "${i%.*}")
	SUPPORTED_FLAGS+=("$flag")
done
${VERBOSE} && log "SUPPORTED_FLAGS: ${SUPPORTED_FLAGS[*]}"

# Populate list of supported networks based on files in ./compose-files/networks
${VERBOSE} && log "Creating list of supported networks"
SUPPORTED_NETWORKS=()
for i in "${SCRIPTPATH}"/compose-files/networks/*.yaml; do
	network=$(basename "${i%.*}")
	SUPPORTED_NETWORKS+=("${network}")
done
${VERBOSE} && log "SUPPORTED_NETWORKS: ${SUPPORTED_NETWORKS[*]}"

# Hardcoded list of supported actions this script accepts
${VERBOSE} && log "Defining hardcoded list of supported actions"
SUPPORTED_ACTIONS=(
	up
	start
	down
	stop
	restart
    log
	logs
	import
	export
	upgrade
	pull
	status
	reset
	bns
)
${VERBOSE} && log "SUPPORTED_ACTIONS: ${SUPPORTED_ACTIONS[*]}"


# Print usage with some examples
usage() {
	echo
	log "Usage:"
	log "    ${0} -n <network> -a <action> <optional args>"
	log "        -n|--network: [ mainnet | testnet | mocknet ]"
	log "        -a|--action: [ start | stop | logs | reset | upgrade | import | export | bns ]"
	log "    optional args:"
	log "        -f|--flags: [ signer,proxy ]"
	log "        export: combined with 'logs' action, exports logs to a text file"
	log "    ex: ${COLCYAN}${0} -n mainnet -a start -f proxy${COLRESET}"
	log "    ex: ${COLCYAN}${0} -n mainnet -a start -f signer,proxy${COLRESET}"
	log "    ex: ${COLCYAN}${0} --network mainnet --action start --flags proxy${COLRESET}"
	log "    ex: ${COLCYAN}${0} -n mainnet -a logs export${COLRESET}"
	echo
	exit 0
}

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

# Function to check for a valid flag (exists in provided arg of array)
#     - arrays are provided as args
check_flags() {
	local array="${1}"
	local element="${2}"
	${VERBOSE} && log "array: ${1}"
	${VERBOSE} && log "element: ${element}"
	for i in ${array}; do
		if [[ ${i} == "${element}" ]]; then
			return 0
		fi
	done
	return 1
}

# Check if we're on a Mac M1 - Docker IO is not ideal yet, and we're IO heavy
#     - Confirm if user really wants to run this on an M1
check_device() {
	# Check if we're on a M1 Mac - Disk IO is not ideal on this platform
	if [[ $(uname -m) == "arm64" ]]; then
		echo
		log_warn "⚠️  ${COLYELLOW}WARNING${COLRESET}"
		log_warn "⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
		log_warn "⚠️  see README for details"
		log_warn "⚠️      https://github.com/stacks-network/stacks-blockchain-docker/blob/master/docs/requirements.md#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
		confirm "Continue Anyway?" || exit_error "${COLRED}Exiting${COLRESET}"
	fi
}

# # Try to detect a breaking (major version change) in the API by comparing local version to .env definition
# # Return non-zero if a breaking change is detected (this logic is suspect, but should be ok)
# check_api(){
# 	# Try to detect if there is a breaking API change based on major version change
# 	${VERBOSE} && log "Checking API version for potential breaking change"
# 	if [ "${PROFILE}" != "event-replay" ]; then
# 		CURRENT_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | cut -f 1 -d "." | head -1)
# 		CONFIGURED_API_VERSION=$( echo "${STACKS_BLOCKCHAIN_API_VERSION}" | cut -f 1 -d ".")
# 		${VERBOSE} && log "CURRENT_API_VERSION: ${CURRENT_API_VERSION}"
# 		${VERBOSE} && log "CONFIGURED_API_VERSION: ${CONFIGURED_API_VERSION}"
# 		if [ "${CURRENT_API_VERSION}" != "" ]; then
# 			if [ "${CURRENT_API_VERSION}" -lt "${CONFIGURED_API_VERSION}" ];then
# 				echo
# 				log_warn "${COLBOLD}stacks-blockchain-api contains a breaking schema change${COLRESET} ( Version: ${COLYELLOW}${STACKS_BLOCKCHAIN_API_VERSION}${COLRESET} )"
# 				return 0
# 			fi
# 		fi
# 	fi
# 	${VERBOSE} && log "No schema-breaking change detected"
# 	return 1
# }

# Check if services are running
check_network() {
	local profile="${1}"
	${VERBOSE} && log "Checking if default services are running"
	# Determine if the services are already running
	if [[ $(docker compose -f "${SCRIPTPATH}/compose-files/common.yaml" --profile ${profile} ps -q) ]]; then
		${VERBOSE} && log "Docker services have a pid"
		# Docker is running, return success
		return 0
	fi
	${VERBOSE} && log "Docker services have no pid"
	# Docker is not running, return fail
	return 1
}

# Check if there is an event-replay operation in progress
check_event_replay(){
	${VERBOSE} && log "Checking status of API event-replay"
	##
	## Check if import has started and save return code
	if [[ "${ACTION}" == "export" || "${ACTION}" == "import" ]]; then
		log "${ACTION} Checking for an active event-replay import"
	fi
	eval "docker logs stacks-blockchain-api 2>&1 | head -n20 | grep -q 'Importing raw event requests'" || test ${?} -eq 141
	check_import_started="${?}"
	${VERBOSE} && log "check_import_started: ${check_import_started}"
	##
	## Check if import has completed and save return code
	if [[ "${ACTION}" == "export" || "${ACTION}" == "import" ]]; then
		log "${ACTION} Checking for a completed event-replay import"
	fi
	eval "docker logs stacks-blockchain-api --tail 20 2>&1 | grep -q 'Event import and playback successful'" || test ${?} -eq 141
	check_import_finished="${?}"
	${VERBOSE} && log "check_import_finished: ${check_import_finished}"
	##
	## Check if export has started and save return code
	if [[ "${ACTION}" == "export" || "${ACTION}" == "import" ]]; then
		log "${ACTION} Checking for an active event-replay export"
	fi
	eval "docker logs stacks-blockchain-api 2>&1 | head -n20 | grep -q 'Export started'" || test ${?} -eq 141
	check_export_started="${?}"
	${VERBOSE} && log "check_export_started: ${check_export_started}"
	##
	## Check if export has completed and save return code
	if [[ "${ACTION}" == "export" || "${ACTION}" == "import" ]]; then
		log "${ACTION} Checking for a completed event-replay export"
	fi
	eval "docker logs stacks-blockchain-api --tail 20 2>&1 | grep -q 'Export successful'" || test ${?} -eq 141
	check_export_finished="${?}"
	${VERBOSE} && log "check_export_finished: ${check_export_finished}"

	if [ "${check_import_started}" -eq "0" ]; then
		# Import has started
		${VERBOSE} && log "import has started"
		if [ "${check_import_finished}" -eq "0" ]; then
			# Import has finished
			log "Event import and playback has finished"
			${VERBOSE} && log "import has finished, return 0"
			return 0
		fi
		# Import hasn't finished, return 1
		log_warn "Event import and playback is in progress"
		${VERBOSE} && log "import has not finished, return 1"
		return 1
	fi
	if [ "${check_export_started}" -eq "0" ]; then
		# Export has started
		${VERBOSE} && log "export has started"
		if [ "${check_export_finished}" -eq "0" ]; then
			# Export has finished
			log "Event export has finished"
			${VERBOSE} && log "export has finished, return 0"
			return 0
		fi
		# Export hasn't finished, return 1
		log_warn "Event export is in progress"
		${VERBOSE} && log "export has not finished, return 1"
		return 1
	fi
	${VERBOSE} && log "No event-replay in progress"
	# Default return success - event-replay is not running
	return 0
}

# Determine if a supplied container name is running
check_container() {
	local container="${1}"
	${VERBOSE} && log "Checking if container ${container} is running"
    if [ "$(docker ps -f name="^${container}"$ -q)" ]; then
        # Container is running, return success
		${VERBOSE} && log "${container} is running, return 0"
		return 0
	fi
    # Container is not running return fail
	${VERBOSE} && log "${container} is running, return 1"
	return 1
}

# # Check if BNS_IMPORT_DIR is defined, and if the directory exists/not empty
check_bns() {
	if [ "${BNS_IMPORT_DIR}" ]; then
		${VERBOSE} && log "Defined BNS_IMPORT_DIR var"
		local file_list=()
		if [ -d "${SCRIPTPATH}/persistent-data${BNS_IMPORT_DIR}" ]; then
			${VERBOSE} && log "Found existing BNS_IMPORT_DIR directory"
			for file in "${SCRIPTPATH}"/persistent-data"${BNS_IMPORT_DIR}"/*; do
				file_base=$(basename "${file%.*}")
				file_list+=("$file_base")
			done
			for item in "${BNS_FILES[@]}"; do
				if ! check_flags "${file_list[*]}" "$item"; then
					return 1
				fi
			done
		fi
	fi
	return 0
}

# adjust BNS_IMPORT_DIR for mocknet
bns_import_env() {
	if "${REVERT_BNS}"; then
		${VERBOSE} && log "Uncommenting BNS_IMPORT_DIR in ${ENV_FILE}"
		${VERBOSE} && log "Running: sed -i.tmp \"s/^#BNS_IMPORT_DIR=/BNS_IMPORT_DIR=/;\" ${ENV_FILE}"
		$(sed -i.tmp "
			s/^#BNS_IMPORT_DIR=/BNS_IMPORT_DIR=/;
		" "${ENV_FILE}" 2>&1) || {
			log_exit "Unable to update BNS_IMPORT_DIR value in .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Deleting temp .env file: ${ENV_FILE}.tmp${COLRESET}"
		${VERBOSE} && log "${COLYELLOW}Grepping for BNS_IMPORT_DIR"
		cat ${ENV_FILE} | grep "BNS_IMPORT_DIR"
		$(rm "${ENV_FILE}.tmp" 2>&1) || {
			log_exit "Unable to delete tmp .env file: ${COLCYAN}${ENV_FILE}.tmp${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Set REVERT_BNS to false${COLRESET}"
		REVERT_BNS=false
	fi
	if [ "${BNS_IMPORT_DIR}" ];then
		${VERBOSE} && log "Commenting BNS_IMPORT_DIR in ${ENV_FILE}"
		${VERBOSE} && log "Running: sed -i.tmp \"s/^BNS_IMPORT_DIR=/#BNS_IMPORT_DIR=/;\" ${ENV_FILE}"
		$(sed -i.tmp "
			s/^BNS_IMPORT_DIR=/#BNS_IMPORT_DIR=/;
		" "${ENV_FILE}" 2>&1) || {
			log_exit "Unable to update BNS_IMPORT_DIR value in .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Deleting temp .env file: ${ENV_FILE}.tmp${COLRESET}"
		${VERBOSE} && log "${COLYELLOW}Grepping for BNS_IMPORT_DIR"
		cat ${ENV_FILE} | grep "BNS_IMPORT_DIR"
		$(rm "${ENV_FILE}.tmp" 2>&1) || {
			log_exit "Unable to delete tmp .env file: ${COLCYAN}${ENV_FILE}.tmp${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Set REVERT_BNS to true${COLRESET}"
		REVERT_BNS=true
		${VERBOSE} && log "${COLYELLOW}Unset BNS_IMPORT_DIR var${COLRESET}"
		unset BNS_IMPORT_DIR
	fi
	${VERBOSE} && log "Sourcing updated .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
	source "${ENV_FILE}"
	return 0
}

# adjust STACKS_EXPORT_EVENTS_FILE for mocknet
events_file_env(){
	if "${REVERT_EVENTS}"; then
		${VERBOSE} && log "Uncommenting STACKS_EXPORT_EVENTS_FILE in ${ENV_FILE}"
		${VERBOSE} && log "Running: sed -i.tmp \"s/^#STACKS_EXPORT_EVENTS_FILE=/STACKS_EXPORT_EVENTS_FILE=/;\" ${ENV_FILE}"
		$(sed -i.tmp "
			s/^#STACKS_EXPORT_EVENTS_FILE=/STACKS_EXPORT_EVENTS_FILE=/;
		" "${ENV_FILE}" 2>&1) || {
			log_exit "Unable to update STACKS_EXPORT_EVENTS_FILE value in .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Grepping for STACKS_EXPORT_EVENTS_FILE"
		cat ${ENV_FILE} | grep "STACKS_EXPORT_EVENTS_FILE"
		${VERBOSE} && log "${COLYELLOW}Deleting temp .env file: ${ENV_FILE}.tmp${COLRESET}"
		$(rm "${ENV_FILE}.tmp" 2>&1) || {
			log_exit "Unable to delete tmp .env file: ${COLCYAN}${ENV_FILE}.tmp${COLRESET}"
		}
		${VERBOSE} && log ${COLYELLOW}"Set REVERT_EVENTS to false${COLRESET}"
		REVERT_EVENTS=false
	fi
	if [ "${STACKS_EXPORT_EVENTS_FILE}" ]; then
		${VERBOSE} && log "Commenting STACKS_EXPORT_EVENTS_FILE in ${ENV_FILE_TMP}"
		${VERBOSE} && log "Running: sed -i.tmp \"s/^STACKS_EXPORT_EVENTS_FILE=/#STACKS_EXPORT_EVENTS_FILE=/;\" ${ENV_FILE}"
		$(sed -i.tmp "
			s/^STACKS_EXPORT_EVENTS_FILE=/#STACKS_EXPORT_EVENTS_FILE=/;
		" "${ENV_FILE}" 2>&1) || {
			log_exit "Unable to update STACKS_EXPORT_EVENTS_FILE value in .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Grepping for STACKS_EXPORT_EVENTS_FILE"
		cat ${ENV_FILE} | grep "STACKS_EXPORT_EVENTS_FILE"
		${VERBOSE} && log "${COLYELLOW}Deleting temp .env file: ${ENV_FILE}.tmp${COLRESET}"
		$(rm "${ENV_FILE}.tmp" 2>&1) || {
			log_exit "Unable to delete tmp .env file: ${COLCYAN}${ENV_FILE}.tmp${COLRESET}"
		}
		${VERBOSE} && log "${COLYELLOW}Set REVERT_EVENTS to true${COLRESET}"
		REVERT_EVENTS=true
		${VERBOSE} && log "${COLYELLOW}Unset STACKS_EXPORT_EVENTS_FILE${COLRESET}"
		unset STACKS_EXPORT_EVENTS_FILE
	fi
	${VERBOSE} && log "Sourcing updated .env file: ${COLCYAN}${ENV_FILE}${COLRESET}"
	source "${ENV_FILE}"
	return 0
}

# Function that updates Config.toml
update_configs(){
	if [ "${NETWORK}" == "testnet" ]; then
		BTC_HOST=${TBTC_HOST}
		BTC_RPC_USER=${TBTC_RPC_USER}
		BTC_RPC_PASS=${TBTC_RPC_PASS}
		BTC_RPC_PORT=${TBTC_RPC_PORT}
		BTC_P2P_PORT=${TBTC_P2P_PORT}
		SIGNER_PRIVATE_KEY=${TESTNET_SIGNER_PRIVATE_KEY}
	fi
	CONFIG_TOML="${SCRIPTPATH}/conf/${NETWORK}/Config.toml"
	SIGNER_TOML="${SCRIPTPATH}/conf/${NETWORK}/Signer.toml"

		## update Config.toml with signer options
		if [ "${SIGNER}" != "true" ]; then
			${VERBOSE} && log "${COLYELLOW}Disabling signer options in ${CONFIG_TOML}${COLRESET}"
			sed -i.tmp "
				/^\[\[events_observer\]\]/{
					:a
					N
					/endpoint.*stacks-signer/!ba
					s/^/#/mg
				}
				/^stacker = true/ s/^/#/
			" "${CONFIG_TOML}" || {
					log_exit "Unable to update values in Config.toml file: ${COLCYAN}${CONFIG_TOML}${COLRESET}"
			}
    else
			[ ! ${SIGNER_PRIVATE_KEY} ] && log_exit "Signer private key not set!"
			${VERBOSE} && log "${COLYELLOW}Enabling signer options in ${CONFIG_TOML}${COLRESET}"
			sed -i.tmp "
				/^#\[\[events_observer\]\]/{
					:a
					N
					/endpoint.*stacks-signer/!ba
					s/^#//mg
				}
				/^#stacker = true/ s/^#//
			" "${CONFIG_TOML}" || {
					log_exit "Unable to update values in Config.toml file: ${COLCYAN}${CONFIG_TOML}${COLRESET}"
			}

				## update Signer.toml with env vars
			[[ ! -f "${SIGNER_TOML}" ]] && cp "${SIGNER_TOML}.sample" "${SIGNER_TOML}"
			${VERBOSE} && log "${COLYELLOW}Updating values in ${SIGNER_TOML} from .env${COLRESET}"
				$(sed -i.tmp "
				/^node_host/s/.*/node_host = \"${STACKS_CORE_RPC_HOST}:${STACKS_CORE_RPC_PORT}\"/;
				/^endpoint/s/.*/endpoint = \"0.0.0.0:${STACKS_SIGNER_PORT}\"/;
				/^metrics_endpoint/s/.*/metrics_endpoint = \"0.0.0.0:${SIGNER_METRICS_PORT}\"/;
				/^auth_password/s/.*/auth_password = \"${AUTH_TOKEN}\"/;
				/^stacks_private_key/s/.*/stacks_private_key = \"${SIGNER_PRIVATE_KEY}\"/;
			" "${SIGNER_TOML}" 2>&1) || {
						log_exit "Unable to update values in Signer.toml file: ${COLCYAN}${SIGNER_TOML}${COLRESET}"
				}
				${VERBOSE} && log "${COLYELLOW}Deleting temp Signer.toml file: ${SIGNER_TOML}.tmp${COLRESET}"
				$(rm "${SIGNER_TOML}.tmp" 2>&1) || {
						log_exit "Unable to delete tmp Signer.toml file: ${COLCYAN}${SIGNER_TOML}.tmp${COLRESET}"
				}
    fi

    ## update Config.toml with btc vars
	[[ ! -f "${CONFIG_TOML}" ]] && cp "${CONFIG_TOML}.sample" "${CONFIG_TOML}"
	${VERBOSE} && log "${COLYELLOW}Updating values in ${CONFIG_TOML} from .env${COLRESET}"
    $(sed -i.tmp "
		/^peer_host/s/.*/peer_host = \"${BTC_HOST}\"/;
		/^username/s/.*/username = \"${BTC_RPC_USER}\"/;
		/^password/s/.*/password = \"${BTC_RPC_PASS}\"/;
		/^rpc_port/s/.*/rpc_port = ${BTC_RPC_PORT}/;
		/^peer_port/s/.*/peer_port = ${BTC_P2P_PORT}/;
		/^auth_token/s/.*/auth_token = \"${AUTH_TOKEN}\"/;
		/^endpoint = \"stacks-signer/s/.*/endpoint = \"stacks-signer:${STACKS_SIGNER_PORT}\"/;
		/^prometheus_bind/s/.*/prometheus_bind = \"0.0.0.0:${NODE_METRICS_PORT}\"/;
	" "${CONFIG_TOML}" 2>&1) || {
        log_exit "Unable to update values in Config.toml file: ${COLCYAN}${CONFIG_TOML}${COLRESET}"
    }
    ${VERBOSE} && log "${COLYELLOW}Deleting temp Config.toml file: ${CONFIG_TOML}.tmp${COLRESET}"
    $(rm "${CONFIG_TOML}.tmp" 2>&1) || {
        log_exit "Unable to delete tmp Config.toml file: ${COLCYAN}${CONFIG_TOML}.tmp${COLRESET}"
    }
	return 0
}

# Loop through supplied flags and set FLAGS for the yaml files to load
#     - Silently fail if a flag isn't supported or a yaml file doesn't exist
set_flags() {
	local array="${*}"
	local flags=""
	local flag_path=""
	${VERBOSE} && log "EXPOSE_POSTGRES: ${EXPOSE_POSTGRES}"
	if [ "${EXPOSE_POSTGRES}" -a -f "${SCRIPTPATH}/compose-files/extra-services/postgres.yaml" ]; then
		${EXPOSE_POSTGRES} && flags="-f ${SCRIPTPATH}/compose-files/extra-services/postgres.yaml"
    fi
	# Case to change the path of files based on profile
	${VERBOSE} && log "Setting optional flags for cmd to eval"
	case ${profile} in
		event-replay)
			flag_path="event-replay"
			;;
		*)
			flag_path="extra-services"
			;;
	esac
	${VERBOSE} && log "array: ${array}"
	${VERBOSE} && log "flags: ${flags}"
	${VERBOSE} && log "flag_path: ${flag_path}"
	${VERBOSE} && log "profile: ${profile}"
	for item in ${array}; do
		${VERBOSE} && log "checking if ${item} is a supported flag"
		if check_flags "${SUPPORTED_FLAGS[*]}" "${item}"; then
			# Add to local flags if found in SUPPORTED_FLAGS array *and* the file exists in the expected path
			#     - If no yaml file exists, silently fail
			${VERBOSE} && log "Checking for compose file: ${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml"
			if [ -f "${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml" ]; then
				${VERBOSE} && log "compose file for ${item} is found"
				flags="${flags} -f ${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml"
			else
				if [ "${profile}" != "stacks-blockchain" ];then
					log_error "Missing compose file: ${COLCYAN}${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml${COLRESET}"
					${VERBOSE} && log "calling usage function"
					usage
				fi
			fi
		fi
	done
	OPTIONAL_FLAGS=${flags}
	${VERBOSE} && log "OPTIONAL_FLAGS: ${OPTIONAL_FLAGS}"
	true
}

# Stop the services in a specific order, individually
ordered_stop() {
	${VERBOSE} && log "Starting the ordered stop of services"
	if [[ -f "${SCRIPTPATH}/compose-files/common.yaml" && -f "${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml" ]]; then
		if eval "docker compose -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml ps -q stacks-blockchain > /dev/null  2>&1"; then
			${VERBOSE} && log "Services are running. continuing to stop services"
			for service in "${DEFAULT_SERVICES[@]}"; do
				if check_container "${service}"; then
					local timeout=""
                    log "${COLBOLD}Stopping ${service}${COLRESET}"
					if [ "${service}" == "stacks-blockchain" ]; then
                        #  Wait for the stacks blockchain runloop to end by waiting for STACKS_SHUTDOWN_TIMEOUT
						timeout="-t ${STACKS_SHUTDOWN_TIMEOUT}"
                        log "    Timeout is set for ${STACKS_SHUTDOWN_TIMEOUT} seconds"
					fi
                    # Compose a command to run using provided vars
					cmd="docker compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml --profile ${PROFILE} stop ${timeout} ${service}"
					${VERBOSE} && log "Running: ${cmd}"
					eval "${cmd}"
				fi
			done
			return 0
		fi
		# stacks-blockchain isn't running, so order of stop isn't important and we just run docker_down
		log "${COLBOLD}Stacks Blockchain services are not running. Continuing${COLRESET}"
		return 1
	fi
}

# Configure options to bring services up
docker_up() {
	if check_network "${PROFILE}"; then
		echo
		log_exit "Stacks Blockchain services are already running"
	fi
	if ! check_event_replay; then
		log_exit "Event-replay in progress. Refusing to start services"
	fi

	# Set signer env based on flag
	if [[ "${FLAGS_ARRAY[*]}" == *"signer"* ]]; then
		SIGNER=true
	fi

	# Sanity checks before starting services
	local param="-d"
	if [ "${PROFILE}" == "bns" ]; then
		param=""
	fi

    # Create required config files and directories
	[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/Config.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/Config.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/Config.toml"
	if [[ "${NETWORK}" == "private-testnet" ]]; then
		[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml"
	fi
	if [[ "${NETWORK}" == "mainnet" ||  "${NETWORK}" == "testnet" ]];then
		if [[ ! -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]];then
			log "Creating persistent-data for ${NETWORK}"
			mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay" >/dev/null 2>&1 || {
				log_exit "Unable to create required dir: ${COLCYAN}${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay${COLRESET}"
			}
			${VERBOSE} && log "created (recursive) persistent-data dir ${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay"
		fi
		${VERBOSE} && log "Using existing data dir: ${SCRIPTPATH}/persistent-data/${NETWORK}"
	fi

	update_configs

    # # See if we can detect a Hiro API major version change requiring an event-replay import
	# if check_api; then
	# 	log_warn "    Required to perform a stacks-blockchain-api event-replay:"
	# 	log_warn "        https://github.com/hirosystems/stacks-blockchain-api#event-replay "
	# 	if confirm "Run event-replay now?"; then
	# 		## Bring running services down
	# 		${VERBOSE} && log "upgrade api: calling docker_down function"
	# 		docker_down
	# 		## Pull new images if available
	# 		${VERBOSE} && log "upgrade api: docker_pull function"
	# 		docker_pull
	# 		## Run the event-replay import
	# 		${VERBOSE} && log "upgrade api: event-replay import function"
	# 		event_replay "import"
	# 	fi
	# 	log_exit "Event-replay is required"
	# fi
	${VERBOSE} && log "Copying ${COLCYAN}${ENV_FILE}${COLRESET} -> ${COLCYAN}${ENV_FILE}.save${COLRESET}"
	$(cp -a "${ENV_FILE}" "${ENV_FILE}.save") >/dev/null 2>&1 || {
		log_exit "Unable to copy ${COLCYAN}${ENV_FILE}${COLRESET} -> ${COLCYAN}${ENV_FILE}.save${COLRESET}"
	}
	log "Starting all services for ${COLYELLOW}${PROFILE}${COLRESET}"
	${VERBOSE} && log "calling run_docker function: run_docker \"up\" \"${FLAGS_ARRAY[*]}\" \"${PROFILE}\" \"${param}\""
	run_docker "up" "${FLAGS_ARRAY[*]}" "${PROFILE}" "${param}"
}

# Configure options to bring services down
docker_down() {
	if ! check_network "${PROFILE}"; then
		if [ "${ACTION}" != "restart" ];then
			${VERBOSE} && log "calling status function"
			status
		fi
		return
	fi
	# sanity checks before stopping services
	if ! check_event_replay;then
		log_exit "Event-replay in progress. Refusing to stop services"
	fi
	if [[ "${NETWORK}" == "mainnet" || "${NETWORK}" == "testnet" ]] && [ "${PROFILE}" != "bns" ]; then
		# if this is mainnet/testnet and the profile is not bns, stop the blockchain service first
		${VERBOSE} && log "calling ordered_stop function"
		if ordered_stop; then
			# stop the rest of the services after the blockchain has been stopped
			log "Stopping all services for ${COLYELLOW}${PROFILE}${COLRESET}"
		fi
	fi
	# # stop the rest of the services after the blockchain has been stopped
	log "${COLBOLD}Stopping all services${COLRESET}"
	${VERBOSE} && log "calling run_docker function: run_docker \"down\" \"${SUPPORTED_FLAGS[*]}\" \"${PROFILE}\""
	run_docker "down" "${SUPPORTED_FLAGS[*]}" "${PROFILE}"
}

# Output the service logs
docker_logs(){
	# Tail docker logs for the last x lines via LOG_TAIL as 'param'
	local param="${1}"
	${VERBOSE} && log "param: ${param}"
	if ! check_network "${PROFILE}"; then
		log_error "No ${COLYELLOW}${NETWORK}${COLRESET} services running"
		usage
	fi
	${VERBOSE} && log "calling run_docker function: run_docker \"logs\" \"${SUPPORTED_FLAGS[*]}\" \"${PROFILE}\" \"${param}\""
	run_docker "logs" "${SUPPORTED_FLAGS[*]}" "${PROFILE}" "${param}"
}

# Export docker logs for the main services to files in ./exported-logs
logs_export(){
	if ! check_network "${PROFILE}"; then
		log_error "No ${COLYELLOW}${NETWORK}${COLRESET} services running"
		usage
	fi
	log "Exporting log data to text file"
	# create exported-logs if it doesn't exist
    if [[ ! -d "${SCRIPTPATH}/exported-logs" ]];then
        log "    - Creating log dir: ${COLCYAN}${SCRIPTPATH}/exported-logs${COLRESET}"
        mkdir -p "${SCRIPTPATH}/exported-logs" >/dev/null 2>&1 || {
			log_exit "Unable to create required dir: ${COLCYAN}${SCRIPTPATH}/exported-logs${COLRESET}"
		}
		${VERBOSE} && log "created logs dir: ${SCRIPTPATH}/exported-logs"
    fi
	${VERBOSE} && log "using existing logs dir: ${SCRIPTPATH}/exported-logs"
	# loop through main services, storing the logs as a text file
    for service in "${DEFAULT_SERVICES[@]}"; do
		if check_container "${service}"; then
			log "    - Exporting logs for ${COLCYAN}${service}${COLRESET} -> ${COLCYAN}${SCRIPTPATH}/exported-logs/${service}.log${COLRESET}"
    	    eval "docker logs ${service} > ${SCRIPTPATH}/exported-logs/${service}.log 2>&1"
		else
			log "    - Skipping export for non-running service ${COLYELLOW}${service}${COLRESET}"
		fi
    done
	log_info "Log export complete"
    exit 0
}

# Pull any updated images that may have been published
docker_pull() {
	${VERBOSE} && log "pulling new images for ${PROFILE}"
	${VERBOSE} && log "calling run_docker function: run_docker \"pull\" \"${SUPPORTED_FLAGS[*]}\" \"${PROFILE}\""
	run_docker "pull" "${SUPPORTED_FLAGS[*]}" "${PROFILE}"
}

# Check if the services are running
status() {
	if check_network "${PROFILE}"; then
		echo
		log "${COLBOLD}Stacks Blockchain services are running${COLRESET}"
		echo
		${VERBOSE} && echo -e "$(docker compose -f "${SCRIPTPATH}/compose-files/common.yaml" ps)"
		exit 0
	else
		echo
		log "${COLBOLD}Stacks Blockchain services are not running${COLRESET}"
		echo
		exit 1
	fi
}

# Delete persistent data for NETWORK
reset_data() {
	if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]; then
		${VERBOSE} && log "Found existing data: ${SCRIPTPATH}/persistent-data/${NETWORK}"
		if ! check_network "${PROFILE}"; then
			# Exit if operation isn't confirmed
			confirm "Delete Persistent data for ${COLYELLOW}${NETWORK}${COLRESET}?" || log_exit "Delete Cancelled"
			${VERBOSE} && log "  Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"  >/dev/null 2>&1 || {
				# Log error and exit if data wasn't deleted (permission denied etc)
				log_error "Failed to remove ${COLCYAN}${SCRIPTPATH}/persistent-data/${NETWORK}${COLRESET}"
				log_exit "  Re-run the command with sudo: ${COLCYAN}sudo ${0} -n ${NETWORK} -a reset${COLRESET}"
			}
			log_info "Persistent data deleted"
			echo
			exit 0
		else
			# Log error and exit if services are already running
			log_error "Can't reset while services are running"
			log_exit "  Try again after running: ${COLCYAN}${0} -n ${NETWORK} -a stop${COLRESET}"
		fi
	fi
	# No data exists, log error and move on
	log_error "No data exists for ${COLYELLOW}${NETWORK}${COLRESET}"
	${VERBOSE} && log "calling usage function"
	usage
}

# Download V1 BNS data to import via .env file BNS_IMPORT_DIR
download_bns_data() {
	if [ "${BNS_IMPORT_DIR}" ]; then
		${VERBOSE} && log "Using defined BNS_IMPORT_DIR: ${BNS_IMPORT_DIR}"
		if ! check_network "${PROFILE}"; then
			SUPPORTED_FLAGS+=("bns")
			FLAGS_ARRAY=(bns)
			PROFILE="bns"
			${VERBOSE} && log "SUPPORTED_FLAGS: ${SUPPORTED_FLAGS[*]}"
			${VERBOSE} && log "FLAGS_ARRAY: ${FLAGS_ARRAY[*]}"
			${VERBOSE} && log "PROFILE: ${PROFILE}"
			if [ ! -f "${SCRIPTPATH}/compose-files/extra-services/bns.yaml" ]; then
				log_exit "Missing bns compose file: ${COLCYAN}${SCRIPTPATH}/compose-files/extra-services/bns.yaml${COLRESET}"
			fi
			log "Downloading and extracting V1 bns-data"
			${VERBOSE} && log "calling docker_up function"
			docker_up
			${VERBOSE} && log "calling docker_down function"
			docker_down
			log_info "BNS Download Operation is complete"
			log "    Start the services with: ${COLCYAN}${0} -n ${NETWORK} -a start${COLRESET}"
			exit 0
		fi
		echo
		log_error "Refusing to download BNS data - ${COLBOLD}services need to be stopped first${COLRESET}"
		log_exit "    Stop the services with: ${COLCYAN}${0} -n ${NETWORK} -a stop${COLRESET}"
	fi
	echo
	log_error "Undefined or commented ${COLYELLOW}BNS_IMPORT_DIR${COLRESET} variable in ${COLCYAN}${ENV_FILE}${COLRESET}"
	exit 0
}

# Perform the Hiro API event-replay
event_replay(){
	if [ "${STACKS_BLOCKCHAIN_API_VERSION}" == "5.0.1" ]; then
	 	echo
		log "${COLYELLOW}${COLBOLD}There is an open issue running event-replay with this version (${STACKS_BLOCKCHAIN_API_VERSION}) of the API${COLRESET}"
		log "    https://github.com/hirosystems/stacks-blockchain-api/issues/1336"
		log "For now, use prior version of the API: ${COLBOLD}4.2.1${COLRESET}"
		log "Or sync from genesis using API: ${COLBOLD}5.0.1${COLRESET}"
		echo
		log_exit "${1} not supported for this version of the API"
	fi
	if [ "${STACKS_EXPORT_EVENTS_FILE}" != "" ]; then
		${VERBOSE} && log "Using defined STACKS_EXPORT_EVENTS_FILE: ${STACKS_EXPORT_EVENTS_FILE}"
		# Check if the event-replay file exists first
		local tsv_file
		tsv_file="${SCRIPTPATH}/persistent-data/mainnet/event-replay"/$(basename "${STACKS_EXPORT_EVENTS_FILE}")
		if [ ! -f "${tsv_file}" ]; then
			log_error "Missing event-replay file: ${COLCYAN}${tsv_file}${COLRESET}"
		fi
		${VERBOSE} && log "Using local event-replay file: ${tsv_file}"
		if check_network "${PROFILE}"; then
			${VERBOSE} && log "calling docker_down function"
			docker_down
		fi
		PROFILE="event-replay"
		local action="${1}"
		SUPPORTED_FLAGS+=("api-${action}-events")
		FLAGS_ARRAY=("api-${action}-events")
		${VERBOSE} && log "PROFILE: ${PROFILE}"
		${VERBOSE} && log "SUPPPORTED_FLAGS: ${SUPPORTED_FLAGS[*]}"
		${VERBOSE} && log "FLAGS_ARRAY: ${FLAGS_ARRAY[*]}"
		if [ ! -f "${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml" ]; then
			echo
			log_exit "Missing events compose file: ${COLCYAN}${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml${COLRESET}"
		fi
		${VERBOSE} && log "calling docker_up function"
		docker_up
		echo
		log "${COLBRRED}${COLBOLD}This operation can take a long while${COLRESET}"
		log "Check logs for completion: ${COLCYAN}${0} -n ${NETWORK} -a logs${COLRESET}"
		if [ "${action}" == "export" ]; then
			log "    - Look for a export log entry: ${COLYELLOW}\"Export successful.\"${COLRESET}"
		fi
		if [ "${action}" == "import" ]; then
			log "    - Look for a import log entry: ${COLYELLOW}\"Event import and playback successful.\"${COLRESET}"
		fi
		log "${COLBOLD}Once the operation is complete${COLRESET}, restart the service with: ${COLCYAN}${0} -n ${NETWORK} -a restart${COLRESET}"
		echo
		exit 0
	fi
	echo
	log_error "Undefined or commented ${COLYELLOW}STACKS_EXPORT_EVENTS_FILE${COLRESET} variable in ${COLCYAN}${ENV_FILE}${COLRESET}"
	exit 0
}

# Execute the docker compose command using provided args
run_docker() {
	local action="${1}"
	local flags="${2}"
	local profile="${3}"
	local param="${4}"
	# # set any optional flags
	set_flags "${flags}"
	cmd="docker compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml ${OPTIONAL_FLAGS} --profile ${profile} ${action} ${param}"
	# Log the command we'll be running for verbosity
	${VERBOSE} && log "action: ${action}"
	${VERBOSE} && log "profile: ${profile}"
	${VERBOSE} && log "param: ${param}"
	${VERBOSE} && log "OPTIONAL_FLAGS: ${OPTIONAL_FLAGS}"
	${VERBOSE} && log "Running: eval ${cmd}"
	if [[ "${NETWORK}" == "mocknet" && "${action}" == "up" ]]; then
		${VERBOSE} && log "Disabling STACKS_EXPORT_EVENTS_FILE for ${NETWORK}"
		events_file_env
		${VERBOSE} && log "Disabling BNS_IMPORT_DIR for ${NETWORK}"
		bns_import_env
	fi
	if [[ "${NETWORK}" == "mainnet" || "${NETWORK}" == "testnet" ]] && [ "${action}" == "up" ]; then
		${VERBOSE} && log "Checking if BNS_IMPORT_DIR is defined and has data"
		if ! check_bns; then
			log "Missing some BNS files"
			log "  run: ${COLCYAN}${0} bns"
			log " -or -"
			log "  comment BNS_IMPORT_DIR in ${COLYELLOW}${ENV_FILE}${COLRESET}"
			exit_error "Exiting"
		fi
	fi
	eval "${cmd}"
	local ret="${?}"
	if [[ "${NETWORK}" == "mocknet" && "${action}" == "up" ]]; then
		${VERBOSE} && log "Re-enabling STACKS_EXPORT_EVENTS_FILE for ${NETWORK}"
		events_file_env
		${VERBOSE} && log "Re-enabling BNS_IMPORT_DIR for ${NETWORK}"
		bns_import_env
	fi
	${VERBOSE} && log "cmd returned: ${ret}"
	# If return is not zero, it should be apparent. if it worked, print how to see the logs
	if [[ "$ret" -eq 0 && "${action}" == "up" && "${profile}" != "bns" ]]; then
		log_info "Brought up ${COLYELLOW}${NETWORK}${COLRESET}"
		log "    Follow logs: ${COLCYAN}${0} -n ${NETWORK} -a logs${COLRESET}"
	fi
	if [[ "$ret" -eq 0 && "${action}" == "down" && "${profile}" != "bns" ]]; then
		log_info "Brought down ${COLYELLOW}${NETWORK}${COLRESET}"
	fi
}

# Check for required binaries, exit if missing
for cmd in docker id; do
	command -v "${cmd}" >/dev/null 2>&1 || log_exit "Missing command: ${cmd}"
done

# Check for docker compose specifically (as a subcommand)
if ! docker compose version >/dev/null 2>&1; then
	log_exit "Missing command: docker compose (Docker Compose v2 required)"
fi

# If no args are provided, print usage
if [[ ${#} -eq 0 ]]; then
	${VERBOSE} && log "No args provided"
	${VERBOSE} && log "calling usage function"
	usage
fi

USER_ID=$(id -u "$(whoami)")
export USER_ID="${USER_ID}"
export DOCKER_NETWORK="${DOCKER_NETWORK}"
export STACKS_CHAIN_ID=${STACKS_CHAIN_ID}
${VERBOSE} && log "Exporting STACKS_CHAIN_ID: ${STACKS_CHAIN_ID}"
${VERBOSE} && log "Exporting USER_ID: ${USER_ID}"
${VERBOSE} && log "Exporting DOCKER_NETWORK: ${DOCKER_NETWORK}"

# loop through the args and try to determine what options we have
#   - simple check for logs/status/upgrade/bns since these are not network dependent
while [ ${#} -gt 0 ]
do
	case ${1} in
	-n|--network)
		# Retrieve the network arg, converted to lowercase
		if [ "${2}" == "" ]; then
			log_error "Missing required value for ${COLYELLOW}${1}${COLRESET}"
			${VERBOSE} && log "calling usage function"
			usage
		fi
		NETWORK=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		${VERBOSE} && log "calling check_flags function with (SUPPORTED_NETWORKS: ${SUPPORTED_NETWORKS[*]}) (NETWORK: ${NETWORK})"
		if ! check_flags "${SUPPORTED_NETWORKS[*]}" "${NETWORK}"; then
			log_error "Network (${COLYELLOW}${NETWORK}${COLRESET}) not supported"
			${VERBOSE} && log "calling usage function"
			usage
		fi
		${VERBOSE} && log "Defining NETWORK: ${NETWORK}"
				${VERBOSE} && log "SUPPORTED_NETWORKS: ${SUPPORTED_NETWORKS[*]}"
		shift
		;;
	-a|--action)
		# Retrieve the action arg, converted to lowercase
		if [ "${2}" == "" ]; then
			log_error "Missing required value for ${COLYELLOW}${1}${COLRESET}"
			${VERBOSE} && log "calling usage function"
			usage
		fi
		ACTION=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		${VERBOSE} && log "calling check_flags function with (SUPPORTED_ACTIONS: ${SUPPORTED_ACTIONS[*]}) (ACTION: ${ACTION})"
		if ! check_flags "${SUPPORTED_ACTIONS[*]}" "${ACTION}"; then
			log_error "Action (${COLYELLOW}${ACTION}${COLRESET}) not supported"
			${VERBOSE} && log "calling usage function"
			usage
		fi
		${VERBOSE} && log "Defining ACTION: ${ACTION}"
		# If the action is log/logs, we also accept a second option 'export' to save the log output to file
		if [[ "${ACTION}" =~ ^(log|logs)$ && "${3}" == "export" ]]; then
			${VERBOSE} && log "calling logs_export function"
			logs_export
		fi
		shift
		;;
	-f|--flags)
		# Retrieve the flags arg as a comma separated list, converted to lowercase
		# Check against the dynamic list 'FLAGS_ARRAY' which validates against folder contents
		if [ "${2}" == "" ]; then
			log_error "Missing required value for ${COLYELLOW}${1}${COLRESET}"
			${VERBOSE} && log "calling usage function"
			usage
		fi
		FLAGS=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		set -f; IFS=','
		FLAGS_ARRAY=("${FLAGS}")
		${VERBOSE} && log "calling check_flags function with (FLAGS_ARRAY: ${FLAGS_ARRAY[*]}) (FLAGS: ${FLAGS[*]})"
		if check_flags "${FLAGS_ARRAY[*]}" "bns" && [ "${ACTION}" != "bns" ]; then
			log_error "${COLYELLOW}bns${COLRESET} is not a valid flag"
			usage
		fi
		${VERBOSE} && log "Defining FLAGS: ${FLAGS[*]}"
		shift
		;;
	upgrade|pull)
		# Standalone - this can be run without supplying an action arg
		#     If .env image version has been modified, this pulls any image that isn't stored locally
		if [ "${ACTION}" == "status" ]; then
			break
		fi
		${VERBOSE} && log "calling docker_pull function"
		docker_pull
		exit 0
		;;
	log|logs)
		# Standalone - this can be run without supplying an action arg
		#     Tail the logs from the last $LOG_TAIL number of lines
		if [ "${ACTION}" == "status" ]; then
			break
		fi
		# if there is a second arg of 'export', export the logs to text file
		if [ "${2}" == "export" ]; then
			${VERBOSE} && log "calling logs_export function"
			logs_export
		fi
		${VERBOSE} && log "calling docker_logs function"
		docker_logs "${LOG_OPTS}"
		exit 0
		;;
	status)
		# Standalone - this can be run without supplying an action arg
		#     Checks the current service/network status
		if [ "${ACTION}" == "logs" ]; then
			break
		fi
		${VERBOSE} && log "calling status function"
		status
		exit 0
		;;
	bns)
		${VERBOSE} && log "calling download_bns_data function"
		export STACKS_CHAIN_ID=${STACKS_CHAIN_ID}
		download_bns_data
		;;
	-h|--help)
		${VERBOSE} && log "calling usage function"
		usage
		;;
	(-*)
		# If any unknown args are provided, fail here
		log_error "Unknown arg supplied (${COLYELLOW}${1}${COLRESET})"
		${VERBOSE} && log "calling usage function"
		usage
		;;
	(*)
		# Catchall error
		log_error "Malformed arguments"
		${VERBOSE} && log "calling usage function"
		usage
		;;
	esac
	shift
done

# If ACTION is not set, exit
if [ ! "${ACTION}" ]; then
	log_error "Missing ${COLYELLOW}-a|--action${COLRESET} arg";
	${VERBOSE} && log "calling usage function"
	usage
fi

# Explicitly export these vars since we use them in compose files
# If NETWORK is not set (either cmd line or default of mainnet), exit
if [ ! "${NETWORK}" ]; then
	log_error "Missing ${COLYELLOW}-n|--network${COLRESET} arg"
	${VERBOSE} && log "calling usage function"
	usage
else
	case ${NETWORK} in
		mainnet)
			# Set chain id to mainnet
			STACKS_CHAIN_ID="0x00000001"
			;;
		testnet)
			# Set chain id to testnet
			STACKS_CHAIN_ID="0x80000000"
			;;
		*)
			# Default the chain id to mocknet
			STACKS_CHAIN_ID="2147483648"
			;;
	esac
fi
${VERBOSE} && log "setting STACKS_CHAIN_ID based on arg: ${STACKS_CHAIN_ID}"
${VERBOSE} && log "exporting NETWORK: ${NETWORK}"
export STACKS_CHAIN_ID=${STACKS_CHAIN_ID}
export NETWORK=${NETWORK}
export PG_SHMSIZE=${PG_SHMSIZE}

# Call function based on ACTION arg
case ${ACTION} in
	up|start)
		${VERBOSE} && log "calling check_device function"
		check_device
		${VERBOSE} && log "calling docker_up function"
		docker_up
		;;
	down|stop)
		${VERBOSE} && log "calling docker_down function"
		docker_down
		;;
	restart)
		${VERBOSE} && log "calling docker_down function"
		docker_down
		${VERBOSE} && log "calling docker_up function"
		docker_up
		;;
	log|logs)
		${VERBOSE} && log "calling docker_logs function"
		docker_logs "${LOG_OPTS}"
		;;
	import|export)
		${VERBOSE} && log "calling event_replay function"
		event_replay "${ACTION}"
		;;
	upgrade|pull)
		${VERBOSE} && log "calling docker_pull function"
		docker_pull
		;;
	status)
		${VERBOSE} && log "calling status function"
		status
		;;
	reset)
		${VERBOSE} && log "calling reset_data function"
		reset_data
		;;
    bns)
		${VERBOSE} && log "calling download_bns_data function"
		download_bns_data
		;;
	*)
		${VERBOSE} && log "calling usage function"
		usage
		;;
esac
${VERBOSE} && log "End of script: exiting"
exit 0
