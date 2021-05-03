#!/bin/bash

NETWORK=$1
ACTION=$2
PARAM=""
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
	echo "      network: [mainnet|testnet|mocknet|bns]"
	echo "      action: [up|down|logs|reset|upgrade]"
	echo
	exit 0
} 

download_bns_data() {
	echo "Downloading and extracting V1 bns-data"
	echo "Running: docker-compose -f ./configurations/bns.yaml up"
	docker-compose -f ./configurations/bns.yaml up
	echo "Running: docker-compose -f ./configurations/bns.yaml down"
	docker-compose -f ./configurations/bns.yaml down
	usage
	exit 0
}

reset_data() {
	if [ -d ./persistent-data/${NETWORK} ]; then
		if [[ ! $(docker-compose -f configurations/common.yaml ps -q) ]]; then
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
	echo "Stopping stacks-node-follower first to prevent database errors"
	echo "Running: docker-compose -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml stop stacks-node-follower"
	docker-compose -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml stop stacks-node-follower
}

run_docker() {
	echo "Running: docker-compose -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml ${ACTION} ${PARAM}"
	docker-compose -f ./configurations/common.yaml -f ./configurations/${NETWORK}.yaml ${ACTION} ${PARAM}
	if [[ $? -eq 0 && ${ACTION} == "up" ]]; then
		echo "Brought up ${NETWORK}, use '$0 ${NETWORK} logs' to follow log files."
	fi
	exit $?
}


case ${NETWORK} in
	mainnet | testnet | mocknet)
		if [[ ${NETWORK} != "mocknet" && ${ACTION} != "reset" ]];then
			echo "Creating persistent-data for ${NETWORK}"
			mkdir -p ./persistent-data/${NETWORK}
		fi
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
		ACTION="up"
		[[ ! -f "./configurations/${NETWORK}/Config.toml" ]] && cp ./configurations/${NETWORK}/Config.toml.sample ./configurations/${NETWORK}/Config.toml
		PARAM="-d"
		;;
	down|stop)
		ACTION="down"
		if [ ${NETWORK} != "mocknet" ];then
			ordered_stop
		fi
		;;
	logs)
		PARAM="-f"
		if [[ ! $(docker-compose -f configurations/common.yaml ps -q) ]]; then
			echo 
			echo "*** No ${NETWORK} services running ***"
			usage
		fi
		;;
	upgrade|pull)
		ACTION="pull"
		;;
	reset)
		reset_data
		;;
	*)
		usage
		;;
esac
run_docker
exit
