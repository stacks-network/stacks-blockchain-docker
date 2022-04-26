#!/usr/bin/env bash

set -eo pipefail
set -Eo functrace
shopt -s expand_aliases

# The following values can be overridden in the .env file or cmd line. adding some defaults here
export NETWORK="mainnet"
export ACTION=""
export PROFILE="stacks-blockchain"
STACKS_SHUTDOWN_TIMEOUT=1200 # default to 20 minutes, during sync it can take a long time to stop the runloop
LOG_TAIL="100"
FLAGS="proxy"
LOG_OPTS="-f --tail ${LOG_TAIL}"
VERBOSE=false

COLRED=$'\033[31m' # Red
COLGREEN=$'\033[32m' # Green
COLYELLOW=$'\033[33m' # Yellow
COLLTBLUE=$'\033[36m' # Light Blue
# COLBLUE=$'\033[34m' # Blue
# COLPURPLE=$'\033[35m' # Purple
# COLBLACK=$'\033[30m' # Black
# COLGRAY=$'\033[2m' # Gray
# COLITALIC=$'\033[3m' # Italic
# COLUNDERLINE=$'\033[4m' # underline
# COLBOLD=$'\033[7m' # block text
COLRESET=$'\033[0m' # reset color

ERROR="${COLRED}[ Error ]${COLRESET} "
WARN="${COLYELLOW}[ Warn ]${COLRESET} "
INFO="${COLGREEN}[ Success ]${COLRESET} "
EXIT_MSG="${COLRED}[ Exit Error ]${COLRESET} "


# Use .env in the local dir
#     - This var is also used in the docker-compose yaml files
FULL_PATH="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
# export SCRIPTPATH="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
export SCRIPTPATH=${FULL_PATH}
ENV_FILE="${SCRIPTPATH}/.env"

# If no .env file exists, copy the sample env and export the vars
if [ ! -f "${ENV_FILE}" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"

DEFAULT_SERVICES=(
	stacks-blockchain
	stacks-blockchain-api
	postgres
)

# Populate list of supported flags based on files in ./compose-files/extra-services
SUPPORTED_FLAGS=()
for i in "${SCRIPTPATH}"/compose-files/extra-services/*.yaml; do
	flag=$(basename "${i%.*}")
	SUPPORTED_FLAGS+=("$flag")
done

# Populate list of supported networks based on files in ./compose-files/networks
SUPPORTED_NETWORKS=()
for i in "${SCRIPTPATH}"/compose-files/networks/*.yaml; do
	network=$(basename "${i%.*}")
	SUPPORTED_NETWORKS+=("${network}")
done

# Hardcoded list of supported actions this script accepts
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


# # Print log output
# log() {
# 	printf >&2 "%b\\n" "${1}"
# }

# # Print log output and exit with an error
# exit_error() {
# 	printf "%b\\n\\n" "${1}" >&2
# 	exit 1
# }

alias log="logger"
alias log_error='logger "${ERROR}"'
alias log_warn='logger "${WARN}"'
alias log_info='logger "${INFO}"'
alias log_exit='exit_error "${EXIT_MSG}"'
if $VERBOSE; then
	alias log='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}"' 
	alias log_info='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${INFO}"' 
	alias log_warn='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${WARN}"' 
	alias log_error='logger  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${ERROR}"'
	alias log_exit='exit_error  "$(date "+%D %H:%m:%S")" "Func:${FUNCNAME:-main}" "Line:${LINENO:-null}" "${EXIT_MSG}"' 
fi

logger() {
    if $VERBOSE;then
        printf "%s %-25s %-10s %-25s %s\\n" "$1" "$2" "$3" "$4" "$5"
    else
        printf "%-25s %s\\n" "$1" "$2"
    fi
}

exit_error() {
    if $VERBOSE;then
        printf "%s %-25s %-10s %-25s %s\\n\\n" "$1" "$2" "$3" "$4" "$5"
	else
        printf "%-25s %s\\n\\n" "$1" "$2"
    fi
    exit 1
}

# Print usage with some examples
usage() {
	if [ "${1}" ]; then
		echo
		log "${1}"
	fi
	echo
	log "Usage:"
	log "    ${0} -n <network> -a <action> <optional args>"
	log "        -n|--network: [ mainnet | testnet | mocknet | bns ]"
	log "        -a|--action: [ up | down | logs | reset | upgrade | import | export | bns]"
	log "    optional args:"
	log "        -f|--flags: [ proxy,bitcoin ]"
	log "        export: combined with 'logs' action, exports logs to a text file"
	log "    ex: ${COLLTBLUE}${0} -n mainnet -a up -f proxy,bitcoin${COLRESET}"
	log "    ex: ${COLLTBLUE}${0} --network mainnet --action up --flags proxy${COLRESET}"
	log "    ex: ${COLLTBLUE}${0} -n mainnet -a logs export${COLRESET}"
	exit 0
}

# Function to ask for confirmation. Lloop until valid input is received
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
	local array="${1}[@]"
	local element="${2}"
	for i in ${!array}; do
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
		log_warn "⚠️      https://github.com/stacks-network/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
		confirm "Continue Anyway?" || exit_error "${COLRED}Exiting${COLRESET}"
	fi
}

# Try to detect a breaking (major version change) in the API by comparing local version to .env definition
# Return non-zero if a breaking change is detected (this logic is suspect, but should be ok)
check_api(){
	# Try to detect if there is a breaking API change based on major version change
	if [ "${PROFILE}" != "event-replay" ]; then
		CURRENT_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | cut -f 1 -d "." | head -1)
		CONFIGURED_API_VERSION=$( echo "${STACKS_BLOCKCHAIN_API_VERSION}" | cut -f 1 -d ".")
		if [ "${CURRENT_API_VERSION}" != "" ]; then
			if [ "${CURRENT_API_VERSION}" -lt "${CONFIGURED_API_VERSION}" ];then
				echo
				log_warn "stacks-blockchain-api contains a breaking schema change ( Version: ${STACKS_BLOCKCHAIN_API_VERSION} )"
				return 0
			fi
		fi
	fi
	return 1
}

# Check if services are running
check_network() {
	# Determine if the services are already running
	if [[ $(docker-compose -f "${SCRIPTPATH}/compose-files/common.yaml" ps -q) ]]; then
		# Docker is running, return success
		return 0
	fi
	# Docker is not running, return fail
	return 1
}

# Check if there is an event-replay operation in progress
check_event_replay(){
	##
	## Check if import has started and save return code
	eval "docker logs stacks-blockchain-api 2>&1 | head -n20 | grep -q 'Importing raw event requests'" || test ${?} -eq 141
	check_import_started="${?}"
	##
	## Check if import has completed and save return code
	eval "docker logs stacks-blockchain-api 2>&1 | tail -n20 | grep -q 'Event import and playback successful'" || test ${?} -eq 141
	check_import_finished="${?}"	
	##
	## Check if export has started and save return code
	eval "docker logs stacks-blockchain-api 2>&1 | head -n20 | grep -q 'Export started'" || test ${?} -eq 141
	check_export_started="${?}"
	##
	## Check if export has completed and save return code
	eval "docker logs stacks-blockchain-api 2>&1 | tail -n20 | grep -q 'Export successful'" || test ${?} -eq 141
	check_export_finished="${?}"

	if [ "${check_import_started}" -eq "0" ]; then
		# Import has started
		if [ "${check_import_finished}" -eq "0" ]; then
			# Import has finished
			log_info "Event import and playback has finished"
			return 0
		fi
		# Import hasn't finished, return 1
		log_warn "Event import and playback is in progress"
		return 1
	fi
	if [ "${check_export_started}" -eq "0" ]; then
		# Export has started
		if [ "${check_export_finished}" -eq "0" ]; then
			# Export has finished
			log_info "Event export has finished"
			return 0
		fi
		# Export hasn't finished, return 1
		log_warn "Event export is in progress"
		return 1
	fi
	# Default return success - event replay is not running
	return 0
}

# Determine if a supplied container name is running
check_container() {
	local container="${1}"
    if [ "$(docker ps -f name="^${container}"$ -q)" ]; then
        # Container is running, return success
		return 0
	fi
    # Container is not running return fail
	return 1
}

# Loop through supplied flags and set FLAGS for the yaml files to load
#     - Silently fail if a flag isn't supported or a yaml file doesn't exist
set_flags() {
	local array="${*}"
	local flags=""
	local flag_path=""
    # Case to change the path of files based on profile
	case ${profile} in
		event-replay)
			flag_path="event-replay"
			;;
		*)
			flag_path="extra-services"
			;;
	esac
	for item in ${!array}; do
		if check_flags SUPPORTED_FLAGS "${item}"; then
			# Add to local flags if found in SUPPORTED_FLAGS array *and* the file exists in the expected path
			#     - If no yaml file exists, silently fail
			if [ -f "${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml" ]; then
				flags="${flags} -f ${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml"
			else
				if [ "${profile}" != "stacks-blockchain" ];then
					log_error "Missing compose file: ${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml"
					usage
				fi
			fi
		fi
	done
	echo "${flags}"
}

# Stop the services in a specific order, individually
ordered_stop() {
	if [[ -f "${SCRIPTPATH}/compose-files/common.yaml" && -f "${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml" ]]; then
		if eval "docker-compose -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml ps -q stacks-blockchain > /dev/null  2>&1"; then
			for service in "${DEFAULT_SERVICES[@]}"; do
				if check_container "${service}"; then
					local timeout=""
                    log "Stopping ${service}"
					if [ "${service}" == "stacks-blockchain" ]; then
                        #  Wait for the stacks blockchain runloop to end by waiting for STACKS_SHUTDOWN_TIMEOUT
						timeout="-t ${STACKS_SHUTDOWN_TIMEOUT}"
                        log "    Timeout is set for ${STACKS_SHUTDOWN_TIMEOUT} seconds"
					fi
                    # Compose a command to run using provided vars
					cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml --profile ${PROFILE} stop ${timeout} ${service}"
					log "Running: ${cmd}"
					eval "${cmd}"
				fi
			done
		else
            # stacks-blockchain isn't running, so order of stop isn't important and we just run docker_down
			echo
			log "Stacks Blockchain not running. Continuing"
		fi
	fi
}

# Configure options to bring services up
docker_up() {
	if check_network; then
		echo
		log_exit "Stacks Blockchain services are already running"
	fi
	if ! check_event_replay; then
		log_exit "Event Replay in progress. Refusing to start services"
	fi
	# Sanity checks before starting services
	local param="-d"
	if [ "${PROFILE}" == "bns" ]; then
		param=""
	fi

    # Create requirted config files and directories
	if [[ "${NETWORK}" == "mainnet" ||  "${NETWORK}" == "testnet" ]];then
		if [[ ! -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]];then
			log "Creating persistent-data for ${NETWORK}"
			mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay"
		fi
	fi
	[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/Config.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/Config.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/Config.toml"
	if [[ "${NETWORK}" == "private-testnet" ]]; then
		[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml"
		[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf.sample" "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf"
	fi

    # See if we can detect a Hiro API major version change requiring an event-replay import
	if check_api; then
		log_warn "    Required to perform a stacks-blockchain-api event-replay:"
		log_warn "        https://github.com/hirosystems/stacks-blockchain-api#event-replay "
		if confirm "Run event-replay now?"; then
			## Bring running services down
			docker_down
			## Pull new images if available
			docker_pull
			## Run the event replay import
			event_replay "import"
		fi
		log_exit "Event Replay is required"
	fi
	run_docker "up" FLAGS_ARRAY "${PROFILE}" "${param}"
}

# Configure options to bring services down
docker_down() {
	if ! check_network; then
		log "Stacks Blockchain services are not running"
		return
	fi
	# sanity checks before stopping services
	if ! check_event_replay;then
		log_exit "Event Replay in progress. Refusing to stop services"
	fi
	if [[ "${NETWORK}" == "mainnet" || "${NETWORK}" == "testnet" ]] && [ "${PROFILE}" != "bns" ]; then
		# if this is mainnet/testnet and the profile is not bns, stop the blockchain service first
		ordered_stop
	fi
	# stop the rest of the services after the blockchain has been stopped
	run_docker "down" SUPPORTED_FLAGS "${PROFILE}"
}

# Output the service logs
docker_logs(){
	# Tail docker logs for the last 100 lines via LOG_TAIL
	local param="${1}"
	if ! check_network; then
		log_error "No ${NETWORK} services running"
		usage
	fi
	run_docker "logs" SUPPORTED_FLAGS "${PROFILE}" "${param}"
}

# Export docker logs for the main services to files in ./exported-logs
docker_logs_export(){
	if ! check_network; then
		log_error "No ${NETWORK} services running"
		usage
	fi
	log "Exporting log data to text file"
	# create exported-logs if it doesn't exist
    if [[ ! -d "${SCRIPTPATH}/exported-logs" ]];then
        log "    - Creating ${SCRIPTPATH}/exported-logs dir"
        mkdir -p "${SCRIPTPATH}/exported-logs"
    fi
	# loop through main services, storing the logs as a text file
    for service in "${DEFAULT_SERVICES[@]}"; do
		if check_container "${service}"; then
			log "    - Exporting logs for ${service} to ${SCRIPTPATH}/exported-logs/${service}.log"
    	    eval "docker logs ${service} > ${SCRIPTPATH}/exported-logs/${service}.log 2>&1"
		else
			log "    - Skipping export for non-running service ${service}"
		fi
    done
	log_info "Log export complete"
    exit
}

# Pull any updated images that may have been published
docker_pull() {
	local action="pull"
	run_docker "pull" SUPPORTED_FLAGS "${PROFILE}"
}

# Check if the services are running
status() {
	if check_network; then
		echo
		log_info "Stacks Blockchain services are running"
		echo
	else
		log
		log_exit "Stacks Blockchain services are not running"
	fi
}

# Delete data for NETWORK
#     - Note: does not delete BNS data
reset_data() {
	if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]; then
		log
		if ! check_network; then
			# Exit if operation isn't confirmed
			confirm "Delete Persistent data for ${NETWORK}?" || log_exit "Delete Cancelled"
			log "    Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"  >/dev/null 2>&1 || { 
				# Log error and exit if data wasn't deleted (permission denied etc)
				echo
				log_error "Failed to remove ${SCRIPTPATH}/persistent-data/${NETWORK}"
				log_exit "  Re-run the command with sudo: ${COLLTBLUE}sudo ${0} -n ${NETWORK} -a reset${COLRESET}"
			}
			log_info "Persistent data deleted"
			echo
			exit 0
		else
			# Log error and exit if services are already running
			log_error "Can't reset while services are running"
			log_exit "  Try again after running: ${COLLTBLUE}${0} -n ${NETWORK} -a stop${COLRESET}"
		fi
	else
		# No data exists, log error and move on
		log_error "No data exists for ${NETWORK}"
		usage
	fi
}

# Download V1 BNS data to import via .env file BNS_IMPORT_DIR
download_bns_data() {
	if [ "${BNS_IMPORT_DIR}" != "" ]; then
		if ! check_network; then
			SUPPORTED_FLAGS+=("bns")
			FLAGS_ARRAY=(bns)
			PROFILE="bns"
			if [ ! -f "${SCRIPTPATH}/compose-files/extra-services/bns.yaml" ]; then
				echo
				log_error "Missing bns compose file: ${COLLTBLUE}{SCRIPTPATH}/compose-files/extra-services/bns.yaml${COLRESET}"
			fi
			log "Downloading and extracting V1 bns-data"
			docker_up
			docker_down
			echo
			log_info "Download Operation is complete"
			log "  Start the services with: ${COLLTBLUE}${0} -n ${NETWORK} -a start${COLRESET}"
			echo
		else
			echo
			status
			log_error "Can't download BNS data - services need to be stopped"
            log_exit "  Stop the services with: ${COLLTBLUE}${0} -n ${NETWORK} -a stop${COLRESET}"
		fi
	else
		echo
		log_error "Undefined or commented ${COLYELLOW}BNS_IMPORT_DIR${COLRESET} variable in ${COLLTBLUE}${ENV_FILE}${COLRESET}"
	fi
	exit 0
}

# Perform the Hiro API event-replay
event_replay(){
	# Check if the event replay file exists first
	local tsv_file
	tsv_file="${SCRIPTPATH}/persistent-data/mainnet/event-replay"/$(basename "${STACKS_EXPORT_EVENTS_FILE}")
	if [ ! -f "${tsv_file}" ]; then
		log_error "Missing event replay file: ${COLLTBLUE}${tsv_file}${COLRESET}"
	fi
	if check_network; then
		docker_down
	fi
	PROFILE="event-replay"
	local action="${1}"
	SUPPORTED_FLAGS+=("api-${action}-events")
	FLAGS_ARRAY=("api-${action}-events")
	if [ ! -f "${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml" ]; then
		echo
		log_errpr "Missing events compose file: ${COLLTBLUE}${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml${COLRESET}"
	fi
	docker_up
	echo
	log "${COLRED}This operation can take a long while${COLRESET}"
	log "Check logs for completion: ${COLLTBLUE}${0} -n ${NETWORK} -a logs${COLRESET}"
	if [ "${action}" == "export" ]; then
		log "    - Look for a export log entry: ${COLYELLOW}\"Export successful.\"${COLRESET}"
	fi
	if [ "${action}" == "import" ]; then
		log "    - Look for a import log entry: ${COLYELLOW}\"Event import and playback successful.\"${COLRESET}"
	fi
	log "Once the operation is complete, restart the service with: ${COLLTBLUE}${0} -n ${NETWORK} -a restart${COLRESET}"
	echo
	exit 0
}

# Execute the docker-compose command using provided args
run_docker() {
	local action="${1}"
	local flags="${2}[@]"
	local profile="${3}"
	local param="${4}"
	local optional_flags=""
	optional_flags=$(set_flags "${flags}")
	cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml ${optional_flags} --profile ${profile} ${action} ${param}"
	# Log the command we'll be running for verbosity
	log "Running: ${cmd}"
	eval "${cmd}"
	local ret="${?}"
	# If return is not zero, it should be apparent. if it worked, print how to see the logs
	if [[ "$ret" -eq 0 && "${action}" == "up" && "${profile}" != "bns" ]]; then
		echo
		log_info "Brought up ${NETWORK}"
		log "    Follow logs: ${COLLTBLUE}${0} -n ${NETWORK} -a logs${COLRESET}"
		echo
	fi
}

# Check for required binaries, exit if missing
for cmd in docker-compose docker; do
	command -v "${cmd}" >/dev/null 2>&1 || log_exit "Missing command: ${cmd}"
done

# If no args are provided, print usage
if [[ ${#} -eq 0 ]]; then
	usage
fi

# loop through the args and try to determine what options we have
#   - simple check for logs/status/upgrade/bns since these are not network dependent
while [ ${#} -gt 0 ]
do
	case ${1} in
	-n|--network)
		# Retrieve the network arg, converted to lowercase
		if [ "${2}" == "" ]; then 
			log_error "Missing required value for ${1}"
			usage
		fi
		NETWORK=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_NETWORKS "${NETWORK}"; then
			log_error "Network (${NETWORK}) not supported"
			usage
		fi
		shift
		;;
	-a|--action) 
		# Retrieve the action arg, converted to lowercase
		if [ "${2}" == "" ]; then 
			log_error "Missing required value for ${1}"
			usage
		fi
		ACTION=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_ACTIONS "${ACTION}"; then
			log_error "Action (${ACTION}) not supported"
			usage
		fi
		# If the action is log/logs, we also accept a second option 'export' to save the log output to file
		if [[ "${ACTION}" =~ ^(log|logs)$ && "${3}" == "export" ]]; then
			docker_logs_export
		fi
		shift
		;;
	-f|--flags)
		# Retrieve the flags arg as a comma separated list, converted to lowercase
		# Check against the dynamic list 'FLAGS_ARRAY' which validates against folder contents 
		if [ "${2}" == "" ]; then 
			log_error "Missing required value for ${1}"
			usage
		fi
		FLAGS=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		set -f; IFS=','
		FLAGS_ARRAY=("${FLAGS}")
		if check_flags FLAGS_ARRAY "bns" && [ "${ACTION}" != "bns" ]; then
			log_error "bns is not a valid flag"
			usage
		fi
		shift
		;;
	upgrade)
		# Standalone - this can be run without supplying an action arg
		#     If .env image version has been modified, this pulls any image that isn't stored locally
		if [ "${ACTION}" == "status" ]; then
			break
		fi
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
			docker_logs_export
		fi
		docker_logs "${LOG_OPTS}"
		exit 0
		;;
	status)
		# Standalone - this can be run without supplying an action arg
		#     Checks the current service/network status
		if [ "${ACTION}" == "logs" ]; then
			break
		fi
		status
		exit 0
		;;
	bns)
		download_bns_data
		;;
	-v|--verbose)
		VERBOSE=true
		;;		
	-h|--help)
		usage
		;;	
	(-*)
		# If any unknown args are provided, fail here
		log_error "Unknown arg supplied (${1})"
		usage
		;;
	(*)
		# Catchall error
		log_error "Malformed arguments"
		usage
		;;
	esac
	shift
done

# If NETWORK is not set (either cmd line or default of mainnet), exit
if [ ! "${NETWORK}" ]; then
	usage "${COLRED}[ Error ]${COLRESET} Missing '-n|--network' Arg"
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

# Explicitly export these vars since we use them in compose files
export STACKS_CHAIN_ID=${STACKS_CHAIN_ID}
export NETWORK=${NETWORK}

# If ACTION is not set, exit
if [ ! "${ACTION}" ]; then
	log_error "Missing '-a|--action' Arg";
	usage
fi

# Call function based on ACTION arg
case ${ACTION} in
	up|start)
		check_device
		docker_up
		;;
	down|stop)
		docker_down
		;;
	restart)
		docker_down
		docker_up
		;;
	log|logs)
		docker_logs "${LOG_OPTS}"
		;;
	import|export)
		event_replay "${ACTION}"
		;;
	upgrade|pull)
		docker_pull
		;;
	status)
		status
		;;
	reset)
		reset_data
		;;
    bns)
		download_bns_data
		;;
	*)
		usage
		;;
esac
exit 0