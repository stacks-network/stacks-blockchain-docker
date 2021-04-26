#!/bin/sh
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
echo  "  Setting local vars from .env file"
export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)
## super hacky, but this allows for variable expansion in the .env file
export $(echo $(cat .env | sed 's/#.*//g'| xargs) | envsubst)

echo ""
echo "*********************************"
echo "Setting up local filesystem"
echo ""
if [ ! -d ${API_BNS_DATA_LOCAL} ]; then
  echo "  Creating BNS DATA dir ${API_BNS_DATA_LOCAL}"
  mkdir -p ${API_BNS_DATA_LOCAL}
fi
if [ ! -d ${POSTGRES_DATA_LOCAL} ]; then
  echo "  Creating Postgres data dir ${POSTGRES_DATA_LOCAL}"
  mkdir -p ${POSTGRES_DATA_LOCAL}
fi

if [ -f ${STACKS_FOLLOWER_CONFIG_TEMPLATE} -a -f ${STACKS_FOLLOWER_CONFIG_TEMPLATE} ];then
  echo "    - Updating Stacks Configs with values from files: .env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${STACKS_FOLLOWER_CONFIG_TEMPLATE} \
    > ${STACKS_FOLLOWER_CONFIG}
  echo "    - Updating Postgres SQL script with values from files: .env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${POSTGRES_SCRIPT_TEMPLATE} \
    > ${POSTGRES_SCRIPT}
else
  echo ""
  echo "  *********************************"
  echo "  Error: missing template file(s)"
  echo "    Try 'git pull'"
  echo "    or:"
  if [ ! -f ${STACKS_FOLLOWER_CONFIG_TEMPLATE} ]; then
    echo "      'git checkout ${STACKS_FOLLOWER_CONFIG_TEMPLATE}'"
  fi
  if [ ! -f ${POSTGRES_SCRIPT_TEMPLATE} ]; then
    echo "      'git checkout ${POSTGRES_SCRIPT_TEMPLATE}'"
  fi
  echo ""
  exit 3
fi
echo ""
echo "  Stacks V2 Configs created:"
echo "    - ${STACKS_FOLLOWER_CONFIG}"
echo "    - ${POSTGRES_SCRIPT}"
echo "Exiting"
exit 0

