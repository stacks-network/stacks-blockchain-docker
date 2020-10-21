#/bin/sh
FOLLOWER_TOML="./stacks-node-follower/Config.toml"
MINER_TOML="./stacks-node-miner/Config.toml"
echo ""
if [ ! -f .env ]; then
  echo ""
  echo "*********************************"
  echo "Error:"
  echo "  File .env is missing"
  echo "  Try 'git pull' or 'git checkout .env'"
  echo ""
  exit 2
fi
echo  "Setting local vars from .env file"
export $(grep -v '^#' .env | xargs)

if [ -f ${FOLLOWER_TOML}.template -a -f ${MINER_TOML}.template ];then
  echo "Updating configs with values from files: .env, .stx_keychain"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${FOLLOWER_TOML}.template \
    > ${FOLLOWER_TOML}
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${MINER_TOML}.template \
    > ${MINER_TOML}
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
echo  "Unsetting local vars from .env file"
echo "Now, run:"
echo "  docker-compose up -d"
echo "  Hint: to stop everything, run 'docker-compose down'"
echo ""
exit 0
