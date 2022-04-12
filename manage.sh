#!/usr/bin/bash

set -eo pipefail
set -Eo functrace

# The following values can be overridden in the .env file. adding some defaults here
NETWORK="mainnet"
ACTION="up"
PROFILE="stacks-blockchain"
STACKS_SHUTDOWN_TIMEOUT=1200 # default to 20 minutes, during sync it can take a long time to stop the runloop
LOG_TAIL="100"
FLAGS="proxy"

# Use .env in the local dir
# this var is also used in the docker-compose yaml files
export SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENV_FILE="${SCRIPTPATH}/.env"

# if no .env exists, copy the sample env and export the vars
if [ ! -f "$ENV_FILE" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"

# hardcode some valid flags we can use
# this has to be hardcoded so we know what to shutdown
SUPPORTED_FLAGS=(
	bitcoin
	proxy
)

# static list of blockchain networks we support
SUPPORTED_NETWORKS=(
	mainnet
	testnet
	mocknet
	private-testnet
)

# list of supported actions this script accepts
SUPPORTED_ACTIONS=(
	up
	start
	down
	stop
	restart
	logs
	import
	export
	upgrade
	pull
	status
	reset
	bns
)


# log output
log() {
	printf >&2 "%s\\n" "$1"
}

# log output and exit with an error
exit_error() {
	printf "%s\\n\\n" "$1" >&2
	exit 1
}

# print usage with some examples
usage() {
	if [ "$1" ]; then
		log
		log "$1"
	fi
	log
	log "Usage:"
	log "  $0"
	log "    -n|--network - [ mainnet | testnet | mocknet | bns ]"
	log "    -a|--action - [ up | down | logs | reset | upgrade | import | export | bns]"
	log "    optional args:"
	log "      -f|--flags - [ proxy,bitcoin ]"
	log "  ex: $0 -n mainnet -a up -f proxy,bitcoin"
	log "  ex: $0 --network mainnet --action up --flags proxy"
	exit_error ""
}

# ask for confirmation, loop until valid input is received
confirm() {
	# y/n confirmation. loop until valid response is received
	while true; do
		read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
		case $REPLY in
			[yY]) echo ; return 0 ;;
			[nN]) echo ; return 1 ;;
			*) printf "\\033[31m %s \\n\\033[0m" "invalid input"
		esac 
	done  
}

# function to check for a valid flag (exists in provided arg of array)
# arrays to be used are defined previously
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

# check if we're on a Mac M1 - Docker IO is not ideal yet, and we're IO heavy
# confirm if user really wants to run this on an M1
check_device() {
	# check if we're on a M1 Mac - Disk IO is not ideal on this platform
	if [[ $(uname -m) == "arm64" ]]; then
		log
		log "⚠️  WARNING"
		log "⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
		log "⚠️  see README for details"
		log "⚠️  https://github.com/stacks-network/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
		confirm "Continue Anyway?" || exit_error "Exiting"
	fi
}

# Try to detect a breaking (major version change) in the API by comparing local version to .env definition
# return non-zero if a breaking change is detected
check_api_breaking_change(){
	# Try to detect if there is a breaking API change based on major version change
	if [ $PROFILE != "event-replay" ]; then
		CURRENT_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | cut -f 1 -d "." | head -1)
		CONFIGURED_API_VERSION=$( echo "$STACKS_BLOCKCHAIN_API_VERSION" | cut -f 1 -d ".")
		if [ "$CURRENT_API_VERSION" != "" ]; then
			if [ "$CURRENT_API_VERSION" -lt "$CONFIGURED_API_VERSION" ];then
				log
				log "*** stacks-blockchain-api contains a breaking schema change ( Version: ${STACKS_BLOCKCHAIN_API_VERSION} ) ***"
				return 1
			fi
		fi
	fi
	return 0
}

# Check if services are running
check_network() {
	# check if the services are already running
	if [[ $(docker-compose -f "${SCRIPTPATH}/configurations/common.yaml" ps -q) ]]; then
		# docker is running
		return 0
	fi
	# docker is not running
	return 1
}

# loop through supplied flags and set FLAGS for the yaml files to load
# silently fail if a flag isn't supported or a yaml doesn't exist
set_flags() {
	local array="${*}"
	local flags=""
	for item in ${!array}; do
		if check_flags SUPPORTED_FLAGS "$item"; then
			# add to local flags if found in SUPPORTED_FLAGS array *and* the file exists in the expected path
			# if no file exists, silently fail
			if [ -f "${SCRIPTPATH}/configurations/${item}.yaml" ]; then
				flags="${flags} -f ${SCRIPTPATH}/configurations/${item}.yaml"
			fi
		fi
	done
	echo "$flags"
}

# stop the stacks-blockchain first
# wait for the runloop to end by waiting for STACKS_SHUTDOWN_TIMEOUT
ordered_stop() {
	if eval "docker-compose -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/mainnet.yaml ps -q stacks-blockchain > /dev/null  2>&1"; then
		log
		log "*** Stopping stacks-blockchain first to prevent database errors"
		log "  Timeout is set for ${STACKS_SHUTDOWN_TIMEOUT} seconds to give the blockchain time to complete the current run loop"
		log
		cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml --profile ${PROFILE} stop -t ${STACKS_SHUTDOWN_TIMEOUT} stacks-blockchain"
		log "Running: ${cmd}"
		eval "${cmd}"
	else
		log
		log "*** Stacks Blockchain not running. Continuing"
	fi
}

# Configure options to bring services up
docker_up() {
	# sanity checks before starting services
	local param="-d"
	if ! check_api_breaking_change; then
		log "    Required to perform a stacks-blockchain-api event-replay:"
		log "        https://github.com/hirosystems/stacks-blockchain-api#event-replay "
		# log "    Or downgrade the API version in ${ENV_FILE}: STACKS_BLOCKCHAIN_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | head -1)"
		if confirm "Run event-replay now?"; then
			## docker_down
			docker_down
			## pull new images
			docker_pull
			## run event_replay
			event_replay "import"
		fi
		exit_error "[ ERROR ] - event-replay is required"
	fi
	if check_network; then
		log
		exit_error "*** Stacks Blockchain services are already running"
	fi
	if [[ "${NETWORK}" == "mainnet" ||  "${NETWORK}" == "testnet" ]];then
		if [[ ! -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]];then
			log "Creating persistent-data for ${NETWORK}"
			mkdir -p "${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay"
		fi
	fi
	[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/Config.toml" ]] && cp "${SCRIPTPATH}/configurations/${NETWORK}/Config.toml.sample" "${SCRIPTPATH}/configurations/${NETWORK}/Config.toml"
	if [[ "${NETWORK}" == "private-testnet" ]]; then
		[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml" ]] && cp "${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml.sample" "${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml"
		[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf" ]] && cp "${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf.sample" "${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf"
	fi
	run_docker "up" FLAGS_ARRAY "$PROFILE" "$param"
}

# Configure options to bring services down
docker_down() {
	# sanity checks before stopping services
	if ! check_network; then
		log "*** Stacks Blockchain services are not running"
		return
	fi
	if [[ "${NETWORK}" == "mainnet" || "${NETWORK}" == "testnet" ]];then
		# if this is mainnet/testnet - stop the blockchain service first
		ordered_stop
	fi
	# stop the rest of the services after the blockchain has been stopped
	run_docker "down" SUPPORTED_FLAGS "$PROFILE"
}

# output the service logs
docker_logs(){
	# tail docker logs for the last 100 lines via LOG_TAIL
	local param="$1"
	if ! check_network; then
		usage "[ ERROR ] - No ${NETWORK} services running"
	fi
	run_docker "logs" SUPPORTED_FLAGS "$PROFILE" "$param"

}

# Pull any updated images that may have been published
docker_pull() {
	# pull any newly published images 
	local action="pull"
	run_docker "pull" SUPPORTED_FLAGS "$PROFILE"
}

# Check if the services are running
status() {
	if check_network; then
		log
		log "*** Stacks Blockchain services are running"
		log
	else
		log
		exit_error "*** Stacks Blockchain services are not running"
	fi
}

# Delete data for NETWORK
# does not delete BNS data
reset_data() {
	if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]; then
		log
		if ! check_network; then
			# exit if operation isn't confirmed
			confirm "Delete Persistent data for ${NETWORK}?" || exit_error "Delete Cancelled"
			log "Resetting Persistent data for ${NETWORK}"
			log "Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"  >/dev/null 2>&1 || { 
				# log error and exit if data wasn't deleted (permission denied etc)
				log
				log "[ Error ] - Failed to remove ${SCRIPTPATH}/persistent-data/${NETWORK}"
				exit_error "    Re-run the command with sudo: 'sudo $0 -n $NETWORK -a reset'"
			}
			log "   *** Persistent data deleted"
			log
		else
			# log error and exit if services are already running
			log "[ Error ] - Can't reset while services are running"
			exit_error "    Try again after running: $0 -n ${NETWORK} -a stop"
		fi
	else
		# no data exists, log error and move on
		usage "[ Error ] - No data exists for ${NETWORK}"
	fi
}

# Download V1 BNS data to import via .env file BNS_IMPORT_DIR
download_bns_data() {
	local profile="bns"
	if [ "$BNS_IMPORT_DIR" != "" ]; then
		if ! check_network; then
			SUPPORTED_FLAGS+=("bns")
			FLAGS_ARRAY=(bns)
			log "Downloading and extracting V1 bns-data"
			run_docker "up" FLAGS_ARRAY "$profile"
			run_docker "down" FLAGS_ARRAY "$profile"
			log
			log "Download Operation is complete, start the service with: $0 -n $NETWORK -a start"
			log
		else
			log
			status
			log "Can't download BNS data - services need to be stopped first: $0 -n $NETWORK -a stop"
			exit_error ""
		fi
	else
		log
		exit_error "Undefined or commented BNS_IMPORT_DIR variable in $ENV_FILE"
	fi
	exit 0

}

# Perform the Hiro API event-replay
event_replay(){
	#
	# TODO: run a test that there is data to export/import before starting this process?
	#    else, containers have to be manually removed
	# perform the API event-replay to either restore or save DB state
	if check_network; then
		docker_down
	fi
	PROFILE="event-replay"
	local action="$1"
	SUPPORTED_FLAGS+=("api-${action}-events")
	FLAGS_ARRAY=("api-${action}-events")
	docker_up
	log
	log "*** This operation can take a long while ***"
	log "    check logs for completion: $0 -n $NETWORK -a logs "
	if [ "$action" == "export" ]; then
		log "        - Look for a log entry: \"Export successful.\""
	fi
	if [ "$action" == "import" ]; then
		log "        - Look for a log entry: \"Event import and playback successful.\""
	fi
	log "    Once the operation is complete, restart the service with: $0 -n $NETWORK -a restart"
	log
	exit
}

# Finally, execute the docker-compose command
# the args we send here are what makes this work
run_docker() {
	# execute the docker command using eval
	local action="$1"
	local flags="${2}[@]"
	local profile="$3"
	local param="$4"
	local optional_flags=""
	optional_flags=$(set_flags "$flags")
	cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${optional_flags} --profile ${profile} ${action} ${param}"
	# log the command we'll be running for verbosity
	log "Running: ${cmd}"
	eval "${cmd}"
	local ret="${?}"
	# if return is not zero, it should be apparent. if it worked, print how to see the logs
	if [[ "$ret" -eq 0 && "${action}" == "up" && "${profile}" != "bns" ]]; then
		log
		log "Brought up ${NETWORK}"
		log "  run '$0 -n ${NETWORK} -a logs' to follow log files."
		log
	fi
}

# check for required binaries, exit if missing
for cmd in docker-compose docker; do
	command -v $cmd >/dev/null 2>&1 || exit_error "Missing command: $cmd"
done

# if no args are provided, print usage
if [[ ${#} -eq 0 ]]; then
	usage
fi

# loop through the args and try to determine what options we have
#   - simple check for logs/status/upgrade since these are not network dependent
while [ $# -gt 0 ]
do
	case $1 in
	-n|--network) 
		if [ "$2" == "" ]; then 
			usage "[ Error ] - Missing required value for $1"
		fi
		NETWORK=$(echo "$2" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_NETWORKS "$NETWORK"; then
			usage "[ Error ] - Network (${NETWORK}) not supported"
		fi
		shift
		;;
	-a|--action) 
		if [ "$2" == "" ]; then 
			usage "[ Error ] - Missing required value for $1"
		fi
		ACTION=$(echo "$2" | tr -d ' ' | awk '{print tolower($0)}')
		if ! check_flags SUPPORTED_ACTIONS "$ACTION"; then
			usage "[ Error ] -Action (${ACTION}) not supported"
		fi
		shift
		;;
	-f|--flags)
		if [ "$2" == "" ]; then 
			usage "[ Error ] - Missing required value for $1"
		fi
		FLAGS=$(echo "$2" | tr -d ' ' | awk '{print tolower($0)}')
		set -f; IFS=','
		FLAGS_ARRAY=("$FLAGS")
		shift
		;;
	upgrade)
		if [ "$ACTION" == "status" ]; then
			break
		fi
		docker_pull
		exit 0
		;;
	logs)
		if [ "$ACTION" == "status" ]; then
			break
		fi
		log_opts="-f --tail $LOG_TAIL"
		docker_logs "$log_opts"
		exit 0
		;;
	status)
		if [ "$ACTION" == "logs" ]; then
			break
		fi
		status
		exit 0
		;;		
	(-*) 
		usage "[ Error ] - Unknown arg supplied ($1)"
		;;
	(*)
		usage "[ Error ] - Malformed arguments"
		;;
	esac
	shift
done

# if NETWORK is not set (either cmd line or default of mainnet), exit
if [ ! "$NETWORK" ]; then
	usage "[ Error ] - Missing '-n|--network' Arg";
fi

if [ ! "$ACTION" ]; then
# if ACTION is not set, exit
	usage "[ Error ] - Missing '-a|--action' Arg";
fi

# call relevant function based on ACTION arg
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
	logs)
		log_opts="-f --tail $LOG_TAIL"
		docker_logs "$log_opts"
		;;
	import|export)
		if [ ! -f "${SCRIPTPATH}/configurations/api-${ACTION}-events.yaml" ]; then
			log
			exit_error "[ Error ] - Missing events file: ${SCRIPTPATH}/configurations/api-${ACTION}-events.yaml"
		fi
		event_replay "$ACTION"
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

# finally, exit successfully if we get to this point
exit 0
