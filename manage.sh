#!/bin/bash

NETWORK=$1
ACTION=$2
FLAG=$3
FLAG2=$4
PARAM=""
PROFILE="stacks-blockchain"
EVENT_REPLAY=""
FLAGS=""
WHICH=$(which docker-compose)
export SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
ENV_FILE="${SCRIPTPATH}/.env"


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
	echo "  $0 <network> <action> <optional flags>"
	echo "      network: [ mainnet | testnet | mocknet | bns ]"
	echo "      action: [ up | down | logs | reset | upgrade | import | export ]"
	echo "      optional flags: [ proxy | bitcoin ]"
	echo "      example: $0 mainnet up"
	echo
	exit 0
}

check_device() {
    if [[ `uname -m` == 'arm64' ]]; then
        echo "⚠️  WARNING"
        echo "⚠️  MacOS M1 CPU detected - NOT recommended for this repo"
        echo "⚠️  see README for details"
        echo "⚠️  https://github.com/stacks-network/stacks-blockchain-docker#macos-with-an-m1-processor-is-not-recommended-for-this-repo"
        read -p "Press enter to continue anyway or Ctrl+C to exit"
    fi
}

check_network() {
	if [[ $(docker-compose -f ${SCRIPTPATH}/configurations/common.yaml ps -q) ]]; then
		# docker running
		return 0
	fi
	# docker is not running
	return 1
}

download_bns_data() {
	echo "Downloading and extracting V1 bns-data"
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml up"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml up
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml down"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bns.yaml down
	usage
	exit 0
}

run_bitcoin_node() {
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml up"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml up -d
	echo "Running bitcoin node. Performing sync..."
	echo "Process will wait to fully sync the bitcoin node before it continues. Please be patient. First sync could take several hours or even days to complete."
	echo "Bitcoin blockchain is quite large (around 500GB and growing), so you can optionaly choose where this data is stored in the .env file, by changing the variable BITCOIN_BLOCKCHAIN_FOLDER".
	docker logs -f bitcoin-core 2>&1 | grep -m 1 " progress=1.000000 cache="
	echo "Bitcoin node sync complete. Bitcoin node is fully operational."
}

reset_data() {
	if [ -d ${SCRIPTPATH}/persistent-data/${NETWORK} ]; then
		if ! check_network; then
			echo "Resetting Persistent data for ${NETWORK}"
			echo "Running: rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}"
			rm -rf ${SCRIPTPATH}/persistent-data/${NETWORK}
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
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml --profile ${PROFILE} stop stacks-blockchain"
	               docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml --profile ${PROFILE} stop stacks-blockchain
	# Check if bitcoin blockchain is also running. If it is, stop it.
	if [[ $(docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml ps -q bitcoin-core) ]]; then
		echo "Bitcoin blockchain is currently running. Stopping..."
		# "Not Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml --profile ${PROFILE} down" because it would also remove the Stacks network
		# Instead I need to first stop and then remove only the container (so the network stays on)
		echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml --profile ${PROFILE} stop bitcoin-core"
		               docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml --profile ${PROFILE} stop bitcoin-core
		echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml --profile ${PROFILE} rm -f bitcoin-core"
			           docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/bitcoin.yaml --profile ${PROFILE} rm -f bitcoin-core
	fi
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
		if [[ ! -d ${SCRIPTPATH}/persistent-data/${NETWORK} ]];then
			echo "Creating persistent-data for ${NETWORK}"
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
	# case will run if word bitcoin in contained in flag1 or flag2
	# If bitcoin flag is detected, I should run bitcoin node before anything else
	case ${FLAG}${FLAG2} in
		*bitcoin*)
			# echo "BITCOIN FLAG IN ON!"
			if [[ ${NETWORK} == "mainnet" ||  ${NETWORK} == "testnet"  ]]; then 
				run_bitcoin_node
			else
				echo "UNSUPPORTED OPTION: You can only run the bitcoin node on mainnet or testnet, not on ${NETWORK}."
				usage
			fi			
			;;
	esac
	echo "Running: docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${EVENT_REPLAY} ${FLAGS} --profile ${PROFILE} ${ACTION} ${PARAM}"
	docker-compose --env-file ${ENV_FILE} -f ${SCRIPTPATH}/configurations/common.yaml -f ${SCRIPTPATH}/configurations/${NETWORK}.yaml ${EVENT_REPLAY} ${FLAGS} --profile ${PROFILE} ${ACTION} ${PARAM}
	if [[ $? -eq 0 && ${ACTION} == "up" ]]; then
		echo "Brought up ${NETWORK}, use '$0 ${NETWORK} logs' to follow log files."
	fi
}

case ${ACTION} in
	# ensure we also act on any proxy containers based on ACTION
    down|stop|logs|upgrade|pull|export|import)
        FLAGS="${FLAGS}-f ${SCRIPTPATH}/configurations/proxy.yaml" 
        ;;
    *)
		# set the FLAG regardless of ACTION if defined
		# case will run if word proxy or nginx is contained in flag1 or flag2
        case ${FLAG}${FLAG2} in
            *proxy*|*nginx*)
                FLAGS="${FLAGS}-f ${SCRIPTPATH}/configurations/proxy.yaml"
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
		PROFILE="event-replay"
		docker_up
		echo ""
		echo ""
		echo " ** This operation can take a long while - check logs for completion **"
		echo "    $0 $NETWORK logs"
		echo "      - Look for a log \"Event import and playback successful.\""
		echo "Once the import is done, restart the service with: $0 $NETWORK restart"
		echo ""
		;;
	export)
		if check_network; then
			docker_down
		fi
		EVENT_REPLAY="-f ${SCRIPTPATH}/configurations/api-export-events.yaml"
		PROFILE="event-replay"
		docker_up
		echo ""
		echo " ** This operation can take a long while - check logs for completion **"
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
exit 0