#!/bin/sh
FOLLOWER_CONFIG="./stacks-node-follower/Config.toml"
MINER_CONFIG="./stacks-node-miner/Config.toml"
echo ""
if [ ! -f .env ]; then
  if [ -f sample.env ]; then
    echo "*********************************"
    echo "Copying sample.env -> .env"
    cp -a sample.env .env
  else
    echo ""
    echo "*********************************"
    echo "Error:"
    echo "  File sample.env is missing"
    echo "  Try 'git pull' or 'git checkout sample.env'"
    echo ""
    exit 2
  fi
fi
echo  "Setting local vars from .env file"
export $(grep -v '^#' .env | xargs)

if [ -f ${FOLLOWER_CONFIG}.template -a -f ${MINER_CONFIG}.template ];then
  echo "Updating Stacks Configs with values from files: .env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${FOLLOWER_CONFIG}.template \
    > ${FOLLOWER_CONFIG}
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${MINER_CONFIG}.template \
    > ${MINER_CONFIG}
else
  echo ""
  echo "*********************************"
  echo "Error: missing template file(s)"
  echo "  Try 'git pull'"
  echo "  or:"
  echo "    'git checkout stacks-node-follower/Config.toml.template; git checkout stacks-node-miner/Config.toml.template'"
  echo ""
  exit 3
fi

# if [ -f ${BTC_CONFIG}.template -a -f ${BTC_CONTROLLER_CONFIG}.template ];then
#   echo "Updating Bitcoin Configs with values from files: .env"
#   envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
#     < ${BTC_CONFIG}.template \
#     > ${BTC_CONFIG}
#   envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
#     < ${BTC_CONTROLLER_CONFIG}.template \
#     > ${BTC_CONTROLLER_CONFIG}
# else
#   echo ""
#   echo "*********************************"
#   echo "Error: missing template file(s)"
#   echo "  Try 'git pull'"
#   echo "  or:"
#   echo "    'git checkout bitcoin/Config.toml.template; git checkout bitcoin/bitcoin.conf.template'"
#   echo ""
#   exit 3
# fi

echo ""
echo "Stacks V2 Configs created:"
echo "  - ${FOLLOWER_CONFIG}"
echo "  - ${MINER_CONFIG}"
# echo "  - ${BTC_CONFIG}"
# echo "  - ${BTC_CONTROLLER_CONFIG}"
echo ""
exit 0
