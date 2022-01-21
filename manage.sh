#!/bin/bash

NETWORK=$1
ACTION=$2
PARAM=""
PROFILE="stacks-blockchain"
ENV_FILE=".env"
EVENT_REPLAY=""
WHICH=$(which docker-compose)
if [ $? -ne 0 ]; then
	echo ""
	echo "Missing binary: docker-compose"
	echo "  https://docs.docker.com/compose/install/"
	echo ""
	exit 1
fi

usage() {
	echo
	echo "Usage:"
	echo "  $0 <network> <action>"
	echo "      network: [ mainnet | testnet |mocknet |bns ]"
	echo "      action: [ up | down | logs | reset | upgrade | import | export ]"
	echo "      ex: $0 mainnet up"
	echo
	exit 0
}

check_device() {
    if [[ `uname -m` == 'arm64' ]]; then
        echo "⚠️  WARNING"
        echo "⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
        echo "⚠️  see README for details"
        echo "⚠️  https://github.com/dcsan/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo "
        read -p "Press enter to continue anyway or Ctrl+C to exit"
    fi
}

check_network() {
	if [[ $(docker-compose -f configurations/common.yaml ps -q) ]]; then
		# docker running
		return 0
	fi
	# docker is not running
	return 1
}

download_bns_data() {
	echo "Downloading and extracting V1 bns-data"
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ./configurations/bns.yaml up"
	docker-compose --env-file ${ENV_FILE} -f ./configurations/bns.yaml up
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ./configurations/bns.yaml down"
	docker-compose --env-file ${ENV_FILE} -f ./configurations/bns.yaml down
	usage
	exit 0
}

reset_data() {
	if [ -d ./persistent-data/${NETWORK} ]; then
		# if [[ ! $(docker-compose -f configurations/common.yaml ps -q) ]]; then
		if ! check_network; then
			echo "Resetting Persistent data for ${NETWORK}"
			echo "Running: rm -rf ./persistent-data/${NETWORK}"
			rm -rf ./persistent-data/${NETWORK}
		else
			echo "Can't reset while services are running"
			echo "  Run: $0 ${NETWORK} down"
			echo "  And try again"
			echo
			exit
		fi
	fi
	exit 0
}

ordered_stop() {
	echo "Stopping stacks-blockchain first to prevent database errors"
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml stop stacks-blockchain"
	docker-compose --env-file ${ENV_FILE} -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml --profile ${PROFILE} stop stacks-blockchain
}

docker_logs(){
	PARAM="-f"
	if ! check_network; then
		echo
		echo "*** No ${NETWORK} services running ***"
		usage
	fi
	run_docker
}

docker_down () {
	ACTION="down"
	if ! check_network; then
		echo
		echo "*** stacks-blockchain network is not running ***"
		echo
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
		echo
		echo "*** stacks-blockchain network is already running ***"
		echo
		return
	fi
	if [[ ${NETWORK} == "mainnet" ||  ${NETWORK} == "testnet" ]];then
		if [[ ! -d ./persistent-data/${NETWORK} ]];then
			echo "Creating persistent-data for ${NETWORK}"
			mkdir -p ./persistent-data/${NETWORK}
			mkdir -p ./persistent-data/${NETWORK}/event-replay
		fi
	fi
	[[ ! -f "./configurations/${NETWORK}/Config.toml" ]] && cp ./configurations/${NETWORK}/Config.toml.sample ./configurations/${NETWORK}/Config.toml
	if [[ ${NETWORK} == "private-testnet" ]]; then
		[[ ! -f "./configurations/${NETWORK}/puppet-chain.toml" ]] && cp ./configurations/${NETWORK}/puppet-chain.toml.sample ./configurations/${NETWORK}/puppet-chain.toml
		[[ ! -f "./configurations/${NETWORK}/bitcoin.conf" ]] && cp ./configurations/${NETWORK}/bitcoin.conf.sample ./configurations/${NETWORK}/bitcoin.conf
	fi
	PARAM="-d"
	run_docker
}

run_docker() {
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml ${EVENT_REPLAY} --profile ${PROFILE} ${ACTION} ${PARAM}"
	docker-compose --env-file ${ENV_FILE} -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml ${EVENT_REPLAY} --profile ${PROFILE} ${ACTION} ${PARAM}
	if [[ $? -eq 0 && ${ACTION} == "up" ]]; then
		echo "Brought up ${NETWORK}, use '$0 ${NETWORK} logs' to follow log files."
	fi
}


case ${NETWORK} in
	mainnet | testnet|mocknet | private-testnet)
		;;
	bns)
		download_bns_data
		;;
  	*)
		usage
    	;;
esac


check_device

case ${ACTION} in

	up|start)
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
		EVENT_REPLAY="-f ./configurations/api-import-events.yaml"
		PROFILE="event-replay"
		docker_up
		echo ""
		echo ""
		echo " ** This operation can take a long while....check logs for completion **"
		echo "    $0 $NETWORK logs"
		echo "      - Look for a log \"Event import and playback successful.\""
		echo "Once the import is done, restart the service with: $0 $NETWORK restart"
		echo ""
		;;
	export)
		if check_network; then
			docker_down
		fi
		EVENT_REPLAY="-f ./configurations/api-export-events.yaml"
		PROFILE="event-replay"
		docker_up
		echo ""
		echo " ** This operation can take a long while....check logs for completion **"
		echo "    $0 $NETWORK logs"
		echo "      - Look for a log \"Export successful.\""
		echo "Once the import is done, restart the service with: $0 $NETWORK restart"
		echo ""
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
exit
