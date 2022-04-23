#!/usr/bin/env bash

set -eo pipefail
set -Eo functrace

# The following values can be overridden in the .env file or cmd line. adding some defaults here
export NETWORK="mainnet"
export ACTION=""
export PROFILE="stacks-blockchain"
STACKS_SHUTDOWN_TIMEOUT=1200 # default to 20 minutes, during sync it can take a long time to stop the runloop
LOG_TAIL="100"
FLAGS="proxy"
LOG_OPTS="-f --tail ${LOG_TAIL}"

# Use .env in the local dir
#     - This var is also used in the docker-compose yaml files
export SCRIPTPATH="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
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


# Print log output
log() {
	printf >&2 "%s\\n" "${1}"
}

# Print log output and exit with an error
exit_error() {
	printf "%s\\n\\n" "${1}" >&2
	exit 1
}

# Print usage with some examples
usage() {
	if [ "${1}" ]; then
		log
		log "${LINENO} ${1}"
	fi
	log
	log "${LINENO}  Usage:"
	log "${LINENO}     ${0} -n <network> -a <action> <optional args>"
	log "${LINENO}         -n|--network: [ mainnet | testnet | mocknet | bns ]"
	log "${LINENO}         -a|--action: [ up | down | logs | reset | upgrade | import | export | bns]"
	log "${LINENO}     optional args:"
	log "${LINENO}         -f|--flags: [ proxy,bitcoin ]"
	log "${LINENO}         export: combined with 'logs' action, exports logs to a text file"
	log "${LINENO}     ex: ${0} -n mainnet -a up -f proxy,bitcoin"
	log "${LINENO}     ex: ${0} --network mainnet --action up --flags proxy"
	log "${LINENO}     ex: ${0} -n mainnet -a logs export"
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
		log
		log "${LINENO} ⚠️  WARNING"
		log "${LINENO} ⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
		log "${LINENO} ⚠️  see README for details"
		log "${LINENO} ⚠️  https://github.com/stacks-network/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
		confirm "Continue Anyway?" || exit_error "${LINENO} Exiting"
	fi
}

# Try to detect a breaking (major version change) in the API by comparing local version to .env definition
# Return non-zero if a breaking change is detected (this logic is suspect, but should be ok)
check_api_breaking_change(){
	# Try to detect if there is a breaking API change based on major version change
	if [ "${PROFILE}" != "event-replay" ]; then
		CURRENT_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | cut -f 1 -d "." | head -1)
		CONFIGURED_API_VERSION=$( echo "${STACKS_BLOCKCHAIN_API_VERSION}" | cut -f 1 -d ".")
		if [ "${CURRENT_API_VERSION}" != "" ]; then
			if [ "${CURRENT_API_VERSION}" -lt "${CONFIGURED_API_VERSION}" ];then
				log
				log "${LINENO} *** stacks-blockchain-api contains a breaking schema change ( Version: ${STACKS_BLOCKCHAIN_API_VERSION} ) ***"
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
			log "${LINENO} *** Event import and playback has finished"
			return 0
		fi
		# Import hasn't finished, return 1
		log "${LINENO} *** Event import and playback is in progress"
		return 1
	fi
	if [ "${check_export_started}" -eq "0" ]; then
		# Export has started
		if [ "${check_export_finished}" -eq "0" ]; then
			# Export has finished
			log "${LINENO} *** Event export has finished"
			return 0
		fi
		# Export hasn't finished, return 1
		log "${LINENO} *** Event export is in progress"
		return 1
	fi
	# Default return success - event replay is not running
	return 0
}

# Determine if a supplied container name is running
check_container_running() {
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
					usage "[ Error ] Missing compose file: ${SCRIPTPATH}/compose-files/${flag_path}/${item}.yaml"
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
				if check_container_running "${service}"; then
					local timeout=""
                    log "${LINENO} *** Stopping ${service}"
					if [ "${service}" == "stacks-blockchain" ]; then
                        #  Wait for the stacks blockchain runloop to end by waiting for STACKS_SHUTDOWN_TIMEOUT
						timeout="-t ${STACKS_SHUTDOWN_TIMEOUT}"
                        log "${LINENO}     Timeout is set for ${STACKS_SHUTDOWN_TIMEOUT} seconds"
					fi
                    # Compose a command to run using provided vars
					cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/compose-files/common.yaml -f ${SCRIPTPATH}/compose-files/networks/${NETWORK}.yaml --profile ${PROFILE} stop ${timeout} ${service}"
					log "${LINENO} Running: ${cmd}"
					eval "${cmd}"
				fi
			done
		else
            # stacks-blockchain isn't running, so order of stop isn't important and we just run docker_down
			log
			log "${LINENO} *** Stacks Blockchain not running. Continuing"
		fi
	fi
}

# Configure options to bring services up
docker_up() {
	if check_network; then
		log
		exit_error "${LINENO} *** Stacks Blockchain services are already running"
	fi
	if ! check_event_replay; then
		exit_error "${LINENO} [ ERROR ] Event Replay in progress. Refusing to start services"
	fi
	# Sanity checks before starting services
	local param="-d"
	if [ "${PROFILE}" == "bns" ]; then
		param=""
	fi

    # Create requirted config files and directories
	if [[ "${NETWORK}" == "mainnet" ||  "${NETWORK}" == "testnet" ]];then
		if [[ ! -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]];then
			log "${LINENO} Creating persistent-data for ${NETWORK}"
			mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay"
		fi
	fi
	[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/Config.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/Config.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/Config.toml"
	if [[ "${NETWORK}" == "private-testnet" ]]; then
		[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml.sample" "${SCRIPTPATH}/conf/${NETWORK}/puppet-chain.toml"
		[[ ! -f "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf" ]] && cp "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf.sample" "${SCRIPTPATH}/conf/${NETWORK}/bitcoin.conf"
	fi

    # See if we can detect a Hiro API major version change requiring an event-replay import
	if check_api_breaking_change; then
		log "${LINENO}     Required to perform a stacks-blockchain-api event-replay:"
		log "${LINENO}         https://github.com/hirosystems/stacks-blockchain-api#event-replay "
		if confirm "Run event-replay now?"; then
			## Bring running services down
			docker_down
			## Pull new images if available
			docker_pull
			## Run the event replay import
			event_replay "import"
		fi
		exit_error "${LINENO} [ ERROR ] Event Replay is required"
	fi
	run_docker "up" FLAGS_ARRAY "${PROFILE}" "${param}"
}

# Configure options to bring services down
docker_down() {
	if ! check_network; then
		log "${LINENO} *** Stacks Blockchain services are not running"
		return
	fi
	# sanity checks before stopping services
	if ! check_event_replay;then
		exit_error "${LINENO} [ ERROR ] Event Replay in progress. Refusing to stop services"
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
		usage "[ ERROR ] No ${NETWORK} services running"
	fi
	run_docker "logs" SUPPORTED_FLAGS "${PROFILE}" "${param}"
}

# Export docker logs for the main services to files in ./exported-logs
docker_logs_export(){
	if ! check_network; then
		usage "[ ERROR ] No ${NETWORK} services running"
	fi
	log "${LINENO} Exporting log data to text file"
	# create exported-logs if it doesn't exist
    if [[ ! -d "${SCRIPTPATH}/exported-logs" ]];then
        log "${LINENO}     - Creating ${SCRIPTPATH}/exported-logs dir"
        mkdir -p "${SCRIPTPATH}/exported-logs"
    fi
	# loop through main services, storing the logs as a text file
    for service in "${DEFAULT_SERVICES[@]}"; do
		if check_container_running "${service}"; then
			log "${LINENO}     - Exporting logs for ${service} to ${SCRIPTPATH}/exported-logs/${service}.log"
    	    eval "docker logs ${service} > ${SCRIPTPATH}/exported-logs/${service}.log 2>&1"
		else
			log "${LINENO}     - Skipping export for non-running service ${service}"
		fi
    done
	log "${LINENO} *** Log export complete"
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
		log
		log "${LINENO} *** Stacks Blockchain services are running"
		log
	else
		log
		exit_error "${LINENO} *** Stacks Blockchain services are not running"
	fi
}

# Delete data for NETWORK
#     - Note: does not delete BNS data
reset_data() {
	if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]; then
		log
		if ! check_network; then
			# Exit if operation isn't confirmed
			confirm "Delete Persistent data for ${NETWORK}?" || exit_error "${LINENO} Delete Cancelled"
			log "${LINENO}     Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"  >/dev/null 2>&1 || { 
				# Log error and exit if data wasn't deleted (permission denied etc)
				log
				log "${LINENO}     [ Error ] Failed to remove ${SCRIPTPATH}/persistent-data/${NETWORK}"
				exit_error "${LINENO}         Re-run the command with sudo: 'sudo ${0} -n ${NETWORK} -a reset'"
			}
			log "${LINENO} *** Persistent data deleted"
			log
			exit 0
		else
			# Log error and exit if services are already running
			log "${LINENO} [ Error ] Can't reset while services are running"
			exit_error "${LINENO}     Try again after running: ${0} -n ${NETWORK} -a stop"
		fi
	else
		# No data exists, log error and move on
		usage "[ Error ] No data exists for ${NETWORK}"
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
				log
				exit_error "[ Error ] Missing bns compose file: {SCRIPTPATH}/compose-files/extra-services/bns.yaml"
			fi
			log "${LINENO} Downloading and extracting V1 bns-data"
			docker_up
			docker_down
			log
			log "${LINENO} Download Operation is complete, start the service with: ${0} -n ${NETWORK} -a start"
			log
		else
			log
			status
			log "${LINENO} [ ERROR ] Can't download BNS data - services need to be stopped first"
            log "     ${0} -n ${NETWORK} -a stop"
			exit_error "${LINENO} "
		fi
	else
		log
		exit_error "${LINENO} [ ERROR ] Undefined or commented BNS_IMPORT_DIR variable in ${ENV_FILE}"
	fi
	exit 0
}

# Perform the Hiro API event-replay
event_replay(){
	# Check if the event replay file exists first
	local tsv_file="${SCRIPTPATH}/persistent-data/mainnet/event-replay"/$(basename "${STACKS_EXPORT_EVENTS_FILE}")
	if [ ! -f "${tsv_file}" ]; then
		exit_error "${LINENO} [ ERROR ] Missing event replay file: ${tsv_file}"
	fi
	if check_network; then
		docker_down
	fi
	PROFILE="event-replay"
	local action="${1}"
	SUPPORTED_FLAGS+=("api-${action}-events")
	FLAGS_ARRAY=("api-${action}-events")
	if [ ! -f "${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml" ]; then
		log
		exit_error "[ Error ] Missing events compose file: ${SCRIPTPATH}/compose-files/event-replay/api-${action}-events.yaml"
	fi
	docker_up
	log
	log "${LINENO} *** This operation can take a long while ***"
	log "${LINENO}     check logs for completion: ${0} -n ${NETWORK} -a logs "
	if [ "${action}" == "export" ]; then
		log "${LINENO}         - Look for a log entry: \"Export successful.\""
	fi
	if [ "${action}" == "import" ]; then
		log "${LINENO}         - Look for a log entry: \"Event import and playback successful.\""
	fi
	log "${LINENO}     Once the operation is complete, restart the service with: ${0} -n ${NETWORK} -a restart"
	log
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
	log "${LINENO} Running: ${cmd}"
	eval "${cmd}"
	local ret="${?}"
	# If return is not zero, it should be apparent. if it worked, print how to see the logs
	if [[ "$ret" -eq 0 && "${action}" == "up" && "${profile}" != "bns" ]]; then
		log
		log "${LINENO} Brought up ${NETWORK}"
		log "${LINENO}     Follow logs: ${0} -n ${NETWORK} -a logs"
		log
	fi
}

# Check for required binaries, exit if missing
for cmd in docker-compose docker; do
	command -v "${cmd}" >/dev/null 2>&1 || exit_error "${LINENO} Missing command: ${cmd}"
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
			usage "[ Error ] Missing required value for ${1}"
		fi
		NETWORK=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_NETWORKS "${NETWORK}"; then
			usage "[ Error ] Network (${NETWORK}) not supported"
		fi
		shift
		;;
	-a|--action) 
		# Retrieve the action arg, converted to lowercase
		if [ "${2}" == "" ]; then 
			usage "[ Error ] Missing required value for ${1}"
		fi
		ACTION=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_ACTIONS "${ACTION}"; then
			usage "[ Error ] Action (${ACTION}) not supported"
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
			usage "[ Error ] Missing required value for ${1}"
		fi
		FLAGS=$(echo "${2}" | tr -d ' ' | awk '{print tolower($0)}')
		set -f; IFS=','
		FLAGS_ARRAY=("${FLAGS}")
		if check_flags FLAGS_ARRAY "bns" && [ "${ACTION}" != "bns" ]; then
			usage "[ Error ] bns is not a valid flag"
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
	-h|--help)
		usage
		;;	
	(-*)
		# If any unknown args are provided, fail here
		usage "[ Error ] Unknown arg supplied (${1})"
		;;
	(*)
		# Catchall error
		usage "[ Error ] Malformed arguments"
		;;
	esac
	shift
done

# If NETWORK is not set (either cmd line or default of mainnet), exit
if [ ! "${NETWORK}" ]; then
	usage "[ Error ] Missing '-n|--network' Arg"
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
	usage "[ Error ] Missing '-a|--action' Arg";
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