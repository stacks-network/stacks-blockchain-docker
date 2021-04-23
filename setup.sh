#!/bin/sh
FOLLOWER_CONFIG="./stacks-node-follower/Config.toml"
FOLLOWER_CONFIG_TEMPLATE="./stacks-node-follower/Config.toml.template"
PSQL_SCRIPT="./postgres/stacks-node-api.sql"
PSQL_SCRIPT_TEMPLATE="./postgres/stacks-node-api.sql.template"

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
echo ""
echo "*********************************"
echo "Setting up local filesystem"
echo ""
if [ ! -d ./bns-data ]; then
  echo "  Creating BNS DATA dir ./bns-data"
  mkdir ./bns-data
fi
if [ ! -d ./postgres-data ]; then
  echo "  Creating Postgres data dir ./postgres-data"
  mkdir ./postgres-data
fi
echo  "  Setting local vars from .env file"
export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
## super hacky, but this allows for variable expansion in the .env file
export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
if [ -f ${FOLLOWER_CONFIG_TEMPLATE} -a -f ${PSQL_SCRIPT_TEMPLATE} ];then
  echo "    - Updating Stacks Configs with values from files: .env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${FOLLOWER_CONFIG_TEMPLATE} \
    > ${FOLLOWER_CONFIG}
  echo "    - Updating Postgres SQL script with values from files: .env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${PSQL_SCRIPT_TEMPLATE} \
    > ${PSQL_SCRIPT}
else
  echo ""
  echo "  *********************************"
  echo "  Error: missing template file(s)"
  echo "    Try 'git pull'"
  echo "    or:"
  if [ ! -f ${FOLLOWER_CONFIG_TEMPLATE} ]; then
    echo "      'git checkout ${FOLLOWER_CONFIG_TEMPLATE}'"
  fi
  if [ ! -f ${PSQL_SCRIPT_TEMPLATE} ]; then
    echo "      'git checkout ${PSQL_SCRIPT_TEMPLATE}'"
  fi
  echo ""
  exit 3
fi
echo ""
echo "  Stacks V2 Configs created:"
echo "    - ${FOLLOWER_CONFIG}"
echo "    - ${PSQL_SCRIPT}"
echo "Exiting"
exit 0

