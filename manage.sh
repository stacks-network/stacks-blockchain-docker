#!/bin/bash
network=$1
action=$2

usage() {
	echo ""
	echo "Usage: $0 [mainnet|testnet|mocknet] [up|down|logs|reset]"
	exit 0
}

ordered_stop() {
	# if we're not mocknet, we have to bring down stacks-node before the api or the data is corrupt
	echo "Stopping stacks-node-follower first to prevent database errors"
	docker-compose -f ./configurations/common.yaml -f ./configurations/$network.yaml stop stacks-node-follower
}

if [[ $network == "bns" ]]; then
	echo "Downloading and extracting V1 bns-data"
	docker-compose -f ./configurations/bns.yaml up
	docker-compose -f ./configurations/bns.yaml down
	usage
fi

if ( [[ $network != "mainnet" ]] && [[ $network != "testnet" ]] && [[ $network != "mocknet" ]] ) || ( [[ $action != "up" ]] && [[ $action != "down" ]] && [[ $action != "logs" ]] && [[ $action != "reset" ]]); then
	usage
fi
if [[ $action == "reset" ]]; then
	# bring down containers
	if [ -d ./persistent-data/$network ]; then
		echo "Resetting Persistent data for $network"
		rm -rf ./persistent-data/$network
	fi
else
	if [[ $action == "up" ]] && [[ $(docker-compose -f configurations/common.yaml ps -q) ]]; then
		echo "Network already running, bring it down using '$0 $network down' first."
		exit 1
	fi
	if [[ $network != "mocknet" ]];then
		if [[ $action == "down" ]]; then
			# we have to bring down the follower node first, else the DB can have missing data
			ordered_stop
			# continue to the generic "down" later in script
		else
			mkdir -p ./persistent-data/$network
		fi
	fi
	[[ ! -f "./configurations/$network/Config.toml" ]] && cp ./configurations/$network/Config.toml.sample ./configurations/$network/Config.toml
	[[ $action == "up" ]] && param=-d
	[[ $action == "logs" ]] && param=-f
	docker-compose -f ./configurations/common.yaml -f ./configurations/$network.yaml $action $param
	[[ $action == "up" ]] && echo "Brought up $network, use '$0 $network logs' to follow log files."
fi
exit 0
