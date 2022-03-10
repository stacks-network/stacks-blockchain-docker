#!/bin/env bash

NETWORK=$1
ACTION=$2
FLAG=$3
PARAM=""
PROFILE="stacks-blockchain"
EVENT_REPLAY=""
FLAGS=""
export SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENV_FILE="${SCRIPTPATH}/.env"
source ${ENV_FILE}


exit_error() {
   printf "%s" "$1\n" >&2
   exit 1
}

for cmd in docker-compose docker; do
   command -v $cmd >/dev/null 2>&1 || exit_error "Missing command: $cmd"
done


set -uo pipefail
set -Eo functrace

failure() {
  local lineno=$1
  local msg=$2
  echo >&2 "Command failed at $lineno: $msg"
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

log() {
   printf >&2 "%s\n" "$1"
}

usage() {
	log "Usage:"
	log "  $0 <network> <action> <optional flags>"
	log "      network: [ mainnet | testnet | mocknet | bns ]"
	log "      action: [ up | down | logs | reset | upgrade | import | export ]"
	log "		optional flags: [ proxy ]"
	exit_error "      ex: $0 mainnet up"
}

confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac 
  done  
}

check_device() {
    if [[ `uname -m` == 'arm64' ]]; then
        log "⚠️  WARNING"
        log "⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
        log "⚠️  see README for details"
        log "⚠️  https://github.com/stacks-network/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
        # read -p "Press enter to continue anyway or Ctrl+C to exit"
		confirm "Continue Anyway?" || exit_error "Cancelled"
    fi
}

check_api_breaking_change(){
	CURRENT_API_VERSION=$(docker images --format "{{.Tag}}" blockstack/stacks-blockchain-api | awk '{print substr ($0, 0, 1)}' | head -1)
	CONFIGURED_API_VERSION=$( echo $STACKS_BLOCKCHAIN_API_VERSION | awk '{print substr ($0, 0, 1)}')
	echo "CURRENT_API_VERSION: $CURRENT_API_VERSION"
	echo "CONFIGURED_API_VERSION: $CONFIGURED_API_VERSION"
	if [ "$CURRENT_API_VERSION" != "" ]; then
		echo "CURRENT_API_VERSION Defined"
		if [ $CURRENT_API_VERSION -lt $CONFIGURED_API_VERSION ];then
			log "BREAKING API CHANGE DETECTED"
			log "return 1"
			return 1
		fi
	fi
	log "return 0"
	return 0
}

check_network() {
	if [[ $(docker-compose -f ${SCRIPTPATH}/configurations/common.yaml ps -q) ]]; then
		# docker running
		return 0
	fi
	# docker is not running
	return 1
}

event_replay(){
	EVENT_REPLAY="-f ${SCRIPTPATH}/configurations/api-import-events.yaml"
	PROFILE="event-replay"
	docker_up
	log " ** This operation can take a long while - check logs for completion **"
	log "    $0 $NETWORK logs"
	log "Once the operation is complete, restart the service with: $0 $NETWORK restart"
}

download_bns_data() {
	log "Downloading and extracting V1 bns-data"
	log "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml up"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml up
	log "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml down"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml down
	usage
	exit 0
}

reset_data() {
	if [ -d ${SCRIPTPATH}/persistent-data/${NETWORK} ]; then
		if ! check_network; then
			log "Resetting Persistent data for ${NETWORK}"
			log "Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}
		else
			exit_error "Can't reset while services are running\n	Run: $0 ${NETWORK} down\n	And try again"
		fi
	fi
	exit 0
}

ordered_stop() {
	log "Stopping stacks-blockchain first to prevent database errors"
	log "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml stop stacks-blockchain"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml --profile ${PROFILE} stop stacks-blockchain
}

docker_logs(){
	PARAM="-f"
	if ! check_network; then
		log "*** No ${NETWORK} services running ***"
		usage
	fi
	run_docker
}

docker_down () {
	ACTION="down"
	if ! check_network; then
		log "*** stacks-blockchain network is not running ***"
		return
	fi
	if [[ ${NETWORK} == "mainnet" || ${NETWORK} == "testnet" ]];then
		ordered_stop
	fi
	run_docker
}

docker_up() {
	ACTION="up"
	if check_network; then
		exit_error "*** stacks-blockchain network is already running ***"
	fi
	if [[ ${NETWORK} == "mainnet" ||  ${NETWORK} == "testnet" ]];then
		if [[ ! -d ${SCRIPTPATH}/persistent-data/${NETWORK} ]];then
			log "Creating persistent-data for ${NETWORK}"
			mkdir -p ${SCRIPTPATH}/persistent-data/${NETWORK}/event-replay
		fi
	fi
	[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/Config.toml" ]] && cp ${SCRIPTPATH}/configurations/${NETWORK}/Config.toml.sample ${SCRIPTPATH}/configurations/${NETWORK}/Config.toml
	if [[ ${NETWORK} == "private-testnet" ]]; then
		[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml" ]] && cp ${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml.sample ${SCRIPTPATH}/configurations/${NETWORK}/puppet-chain.toml
		[[ ! -f "${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf" ]] && cp ${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf.sample ${SCRIPTPATH}/configurations/${NETWORK}/bitcoin.conf
	fi
	PARAM="-d"
	run_docker
}

run_docker() {
	if ! check_api_breaking_change; then
		echo "Action: $ACTION"
		if [ $ACTION != "pull" ]; then
			log "*** stacks-blockchain-api contains a breaking schema change ***"
			log " Recommended to perform a stacks-blockchain-api event-replay:"
			log "    https://github.com/hirosystems/stacks-blockchain-api#event-replay "
			if confirm "Run event-replay now?"; then
				log "*** RUNNING EVENT REPLAY ***"
				if check_network; then
					docker_down
				fi
				EVENT_REPLAY="-f ${SCRIPTPATH}/configurations/api-import-events.yaml"
				event_replay
			fi
		fi
	fi
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${EVENT_REPLAY} ${FLAGS} --profile ${PROFILE} ${ACTION} ${PARAM}"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${EVENT_REPLAY} ${FLAGS} --profile ${PROFILE} ${ACTION} ${PARAM}
	if [[ $? -eq 0 && ${ACTION} == "up" ]]; then
		log "Brought up ${NETWORK}, use '$0 ${NETWORK} logs' to follow log files."
	fi
}


case ${ACTION} in
	# ensure we also act on any proxy containers based on ACTION
    down|stop|logs|upgrade|pull|export|import)
        FLAGS="-f ${SCRIPTPATH}/configurations/proxy.yaml" 
        ;;
    *)
		# set the FLAG regardless of ACTION if defined 
        case ${FLAG} in
            proxy|nginx)
                FLAGS="-f ${SCRIPTPATH}/configurations/proxy.yaml"
                ;;
        esac
        ;;
esac 


case ${NETWORK} in
	mainnet|testnet|mocknet|private-testnet)
		;;
	bns)
		download_bns_data
		;;
  	*)
		usage
    	;;
esac


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
		docker_logs
		;;
	import)
		if check_network; then
			docker_down
		fi
		EVENT_REPLAY="-f ${SCRIPTPATH}/configurations/api-import-events.yaml"
		event_replay
		;;
	export)
		if check_network; then
			docker_down
		fi
		EVENT_REPLAY="-f ${SCRIPTPATH}/configurations/api-export-events.yaml"
		event_replay
		;;
	upgrade|pull)
		ACTION="pull"
		run_docker
		;;
	reset)
		reset_data
		run_docker
		;;
	*)
		usage
		;;
esac
exit 0