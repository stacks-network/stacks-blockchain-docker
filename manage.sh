#!/bin/bash
network=$1
action=$2
if ( [[ $network != "mainnet" ]] && [[ $network != "testnet" ]] && [[ $network != "mocknet" ]] ) || ( [[ $action != "up" ]] && [[ $action != "down" ]] && [[ $action != "logs" ]] && [[ $action != "reset" ]] ); then
	echo "Usage: $0 [mainnet|testnet|mocknet] [up|down|logs|reset]"
	exit
fi
if [[ $action == "reset" ]]; then
	rm -rf ./persistent-data/$network
else
	if [[ $action == "up" ]] && [[ $(docker-compose -f configurations/common.yaml ps -q) ]]; then
		echo "Network already running, bring it down using '$0 $network down' first."
		exit
	fi
	[[ ! -f "./configurations/$network/Config.toml" ]] && cp ./configurations/$network/Config.toml.sample ./configurations/$network/Config.toml
	[[ $action == "up" ]] && param=-d
	[[ $action == "logs" ]] && param=-f
	docker-compose -f ./configurations/common.yaml -f ./configurations/$network.yaml $action $param
	[[ $action == "up" ]] && echo "Brought up $network, use '$0 $network logs' to follow log files."
fi
