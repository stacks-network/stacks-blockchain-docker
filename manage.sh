#!/bin/bash

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
export SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENV_FILE="${SCRIPTPATH}/.env"

# if no .env exists, copy the sample env
if [ ! -f "$ENV_FILE" ];then
	cp -a "${SCRIPTPATH}/sample.env" "${ENV_FILE}"
fi
source "${ENV_FILE}"
set -eo pipefail
set -Eo functrace

SUPPORTED_FLAGS=(
	bitcoin
	proxy
)

SUPPORTED_NETWORKS=(
	mainnet
	testnet
	mocknet
	private-testnet
)

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


log() {
	printf >&2 "%s\\n" "$1"
}

exit_error() {
	printf "%s\\n\\n" "$1" >&2
	exit 1
}

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

confirm() {
	# y/n confirmation to do something. loop until valid response is received
	while true; do
		read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
		case $REPLY in
			[yY]) echo ; return 0 ;;
			[nN]) echo ; return 1 ;;
			*) printf "\\033[31m %s \\n\\033[0m" "invalid input"
		esac 
	done  
}

check_flags() {
	# function to check for a valid flag (exists in provided array)
	local array="${1}[@]"
	local element="${2}"
	for i in ${!array}; do
		if [[ ${i} == "${element}" ]]; then
			return 0
		fi
	done
	return 1
}

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

check_network() {
	# check if the services are already running
	if [[ $(docker-compose -f "${SCRIPTPATH}/configurations/common.yaml" ps -q) ]]; then
		# docker is running
		return 0
	fi
	# docker is not running
	return 1
}

set_flags() {
	# loop through supplied flags and set FLAGS for the yaml files to load
	# silently fail if a flag isn't supported or a yaml doesn't exist
	local array="${*}"
	local flags=""
	for item in ${!array}; do
		if check_flags SUPPORTED_FLAGS "$item"; then
			# add to local flags if found in SUPPORTED_FLAGS array *and* the file exists in the expected path
			if [ -f "${SCRIPTPATH}/configurations/${item}.yaml" ]; then
				flags="${flags} -f ${SCRIPTPATH}/configurations/${item}.yaml"
			fi
		fi
	done
	echo "$flags"
}

ordered_stop() {
	# stop the stacks-blockchain first, wait for the runloop to end by waiting for STACKS_SHUTDOWN_TIMEOUT
	log
	log "*** Stopping stacks-blockchain first to prevent database errors"
	log "  Timeout is set for ${STACKS_SHUTDOWN_TIMEOUT} seconds to give the chainstate time to complete all operations"
	log
	cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml --profile ${PROFILE} stop -t ${STACKS_SHUTDOWN_TIMEOUT} stacks-blockchain"
	log "Running: ${cmd}"
	eval "${cmd}"
}

docker_up() {
	# sanity checks before starting services
	local param="-d"
	if ! check_api_breaking_change; then
		log "    Required to perform a stacks-blockchain-api event-replay:"
		log "        https://github.com/hirosystems/stacks-blockchain-api#event-replay "
		# log "    Or downgrade the API version in ${ENV_FILE}: STACKS_BLOCKCHAIN_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api  | head -1)"
		if confirm "241 Run event-replay now?"; then
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

docker_logs(){
	# tail docker logs for the last 100 lines via LOG_TAIL
	local param="$1"
	if ! check_network; then
		usage "[ ERROR ] - No ${NETWORK} services running"
	fi
	run_docker "logs" SUPPORTED_FLAGS "$PROFILE" "$param"

}

docker_pull() {
	# pull any newly published images 
	local action="pull"
	run_docker "pull" SUPPORTED_FLAGS "$PROFILE"
}

status() {
	# simple print if the services are running
	if check_network; then
		log
		log "*** Stacks Blockchain services are running"
		log
	else
		log
		exit_error "*** Stacks Blockchain services are not running"
	fi
}

reset_data() {
	# delete data for NETWORK based on demand
	# exit if operation isn't confirmed
	if [ -d "${SCRIPTPATH}/persistent-data/${NETWORK}" ]; then
		log
		if ! check_network; then
			confirm "Delete Persistent data for ${NETWORK}?" || exit_error "Delete Cancelled"
			log "Resetting Persistent data for ${NETWORK}"
			log "Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf "${SCRIPTPATH}/persistent-data/${NETWORK}"  >/dev/null 2>&1 || { 
				log
				log "[ Error ] - Failed to remove ${SCRIPTPATH}/persistent-data/${NETWORK}"
				exit_error "    Re-run the command with sudo: 'sudo $0 -n $NETWORK -a reset'"
			}
			log "   *** Persistent data deleted"
			log
		else
			log "[ Error ] - Can't reset while services are running"
			exit_error "    Try again after running: $0 -n ${NETWORK} -a stop"
		fi
	else
		usage "[ Error ] - No data exists for ${NETWORK}"
	fi
}

download_bns_data() {
	# Download V1 BNS data to import via .env file BNS_IMPORT_DIR
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
			log "Can't download BNS data"
			exit_error ""
		fi
	else
		log
		exit_error "Undefined or commented BNS_IMPORT_DIR variable in $ENV_FILE"
	fi
	exit 0

}

event_replay(){
	#
	# TODO: run a test that there is data to export/import before starting this process?
	#    else, containers have to be manually removed
	# perform the API event-replay to either restore or save DB state
	PROFILE="event-replay"
	local action="$1"
	SUPPORTED_FLAGS+=("api-${action}-events")
	FLAGS_ARRAY=("api-${action}-events")
	if ! check_network; then
		usage "[ ERROR ] - No ${NETWORK} services running"
	fi
	docker_up
	log
	log "*** This operation can take a long while ***"
	log "    check logs for completion: $0 -n $NETWORK -a logs "
	log "    Once the operation is complete, restart the service with: $0 -n $NETWORK -a restart"
	log
	exit
}

run_docker() {
	# execute the docker command using eval
	local action="$1"
	local flags="${2}[@]"
	local profile="$3"
	local param="$4"
	local optional_flags=""
	optional_flags=$(set_flags "$flags")
	cmd="docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${optional_flags} --profile ${profile} ${action} ${param}"
	log "Running: ${cmd}"
	eval "${cmd}"
	local ret="${?}"
	if [[ "$ret" -eq 0 && "${action}" == "up" ]]; then
		log "Brought up ${NETWORK}"
		log "  run '$0 -n ${NETWORK} -a logs' to follow log files."
		log
	fi
}

# check for required binaries, exit if missing
for cmd in docker-compose docker; do
	command -v $cmd >/dev/null 2>&1 || exit_error "Missing command: $cmd"
done

# if not args are provided, print usage
if [[ ${#} -eq 0 ]]; then
	usage
fi

# loop through the args and try to determine what options we have
# simple check for logs/status/upgrade since these are not network dependent
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

# call relevant function based on ACTION
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
		if check_network; then
			docker_down
		fi
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

# finally, exit successfully
exit 0