#!/bin/sh
#
# This is used for testing purposes
#

echo  "Setting local vars from .env file"
export $(grep -v '^#' .env | xargs)
echo  "Retrieving private seed from keychain"
if [ ! -f .stx_keychain ]; then
  echo ""
  echo "*********************************"
  echo "Error:"
  echo "  File .stx_keychain wasn't found"
  echo "    Manually Run: npx blockstack-cli@1.1.0-beta.1 make_keychain -t > .stx_keychain"
  echo "    And note any error output"
  exit 1
fi
export PRIVATE_KEY=$(cat .stx_keychain | jq .keyInfo.privateKey | tr -d '"')
# PUBLIC_KEY=$(cat .stx_keychain | jq .keyInfo.publicKey | tr -d '"')

if [ ! $PRIVATE_KEY ]; then
  echo ""
  echo "*********************************"
  echo "Error:"
  echo "  Private Key missing from .stx_keychain"
  echo "    Likely there were errors creating the file."
  echo "    Manually Run: npx blockstack-cli@1.1.0-beta.1 make_keychain -t"
  echo "    And note any error output"
  exit 2
fi

echo "Updating configs with values from files: .env, .stx_keychain"
envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
  < stacks-node-follower/Config.toml.template \
  > stacks-node-follower/Config.toml
envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
  < stacks-node-miner/Config.toml.template \
  > stacks-node-miner/Config.toml


export NETWORK="mocknet"
docker stop ${POSTGRES_NAME} ${STACKS_MINER_NAME} ${STACKS_FOLLOWER_NAME} ${API_NAME} ${EXPLORER_NAME}
docker network create ${NETWORK}

echo "Starting Postgres"
docker run -d \
  --name ${POSTGRES_NAME} \
  --network ${NETWORK} \
  --rm \
  -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
  -v ${PWD}/postgres/stacks-node-api.sql:/docker-entrypoint-initdb.d/stacks-node-api.sql \
  -p ${POSTGRES_PORT_LOCAL}:${POSTGRES_PORT} \
${POSTGRES_IMAGE}
# export PGPASSWORD='postgres' && psql --host localhost -p 5432 -U postgres -d stacks_node_api

echo "Starting Miner"
docker run -d \
  --name ${STACKS_MINER_NAME} \
  --network ${NETWORK} \
  --rm \
  -v ${PWD}/stacks-node-miner/Config.toml:/src/stacks-node/Config.toml \
  -p ${STACKS_RPC_PORT_LOCAL}:${STACKS_RPC_PORT} \
  -p ${STACKS_P2P_PORT_LOCAL}:${STACKS_P2P_PORT} \
  ${STACKS_IMAGE} \
/bin/stacks-node start --config /src/stacks-node/Config.toml

echo "Starting Follower"
docker run -d \
  --name ${STACKS_FOLLOWER_NAME} \
  --network ${NETWORK} \
  --rm \
  -v ${PWD}/stacks-node-follower/Config.toml:/src/stacks-node/Config.toml \
  --expose ${STACKS_RPC_PORT} \
  --expose ${STACKS_P2P_PORT} \
  ${STACKS_IMAGE} \
/bin/stacks-node start --config /src/stacks-node/Config.toml

echo "Starting Api"
docker run -d \
  --name ${API_NAME} \
  --network ${NETWORK} \
  --rm \
  -e NODE_ENV=${API_NODE_ENV} \
  -e GIT_TAG=${API_GIT_TAG} \
  -e PG_HOST=${POSTGRES_NAME}.mocknet \
  -e PG_PORT=${POSTGRES_PORT_LOCAL} \
  -e PG_USER=${API_PG_USER} \
  -e PG_PASSWORD=${POSTGRES_PASSWORD} \
  -e PG_DATABASE=${API_PG_DATABASE} \
  -e PG_SCHEMA=${API_PG_SCHEMA} \
  -e STACKS_CORE_EVENT_PORT=${API_STACKS_CORE_EVENT_PORT} \
  -e STACKS_CORE_EVENT_HOST=${API_STACKS_CORE_EVENT_HOST} \
  -e STACKS_BLOCKCHAIN_API_PORT=${API_STACKS_BLOCKCHAIN_API_PORT} \
  -e STACKS_BLOCKCHAIN_API_HOST=${API_STACKS_BLOCKCHAIN_API_HOST} \
  -e STACKS_BLOCKCHAIN_API_DB=${API_STACKS_BLOCKCHAIN_API_DB} \
  -e STACKS_CORE_RPC_HOST=${STACKS_FOLLOWER_NAME}.${NETWORK} \
  -e STACKS_CORE_RPC_PORT=${STACKS_RPC_PORT} \
  -e STACKS_FAUCET_NODE_HOST=${STACKS_MINER_NAME}.${NETWORK} \
  -e STACKS_FAUCET_NODE_PORT=${STACKS_RPC_PORT} \
  -e BTC_FAUCET_PK=${BTC_FAUCET_PK} \
  -e BTC_RPC_PORT=${BTC_RPC_PORT} \
  -e BTC_RPC_HOST=http://${BTC_HOST} \
  -e BTC_RPC_PW=${BTC_PW} \
  -e BTC_RPC_USER=${BTC_USER} \
  -p ${API_STACKS_CORE_EVENT_PORT_LOCAL}:${API_STACKS_CORE_EVENT_PORT} \
  -p ${API_STACKS_BLOCKCHAIN_API_PORT_LOCAL}:${API_STACKS_BLOCKCHAIN_API_PORT} \
${API_IMAGE}

echo "Starting explorer"
docker run -d \
  --name ${EXPLORER_NAME} \
  --network ${NETWORK} \
  --rm \
  -e MOCKNET_API_SERVER=${EXPLORER_MOCKNET_API_SERVER}:${API_STACKS_BLOCKCHAIN_API_PORT} \
  -e TESTNET_API_SERVER=${EXPLORER_TESTNET_API_SERVER}:${API_STACKS_BLOCKCHAIN_API_PORT} \
  -e API_SERVER=${EXPLORER_API_SERVER}:${API_STACKS_BLOCKCHAIN_API_PORT} \
  -e NODE_ENV=${EXPLORER_NODE_ENV} \
  -p ${EXPLORER_PORT_LOCAL}:${EXPLORER_PORT} \
${EXPLORER_IMAGE}


unset $(grep -v '^#' .env | sed -E 's/(.*)=.*/\1/' | xargs)
unset PRIVATE_KEY
