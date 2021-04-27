#!/bin/sh
echo  "Setting local vars from ${BASEDIR}/.env file"
export $(echo $(cat ${BASEDIR}/.env | sed 's/#.*//g'| xargs) | envsubst)
## super hacky, but this allows for variable expansion in the .env file
export $(echo $(cat ${BASEDIR}/.env | sed 's/#.*//g'| xargs) | envsubst)

echo ""
echo "*********************************"
echo "Setting up local filesystem"
echo ""
if [ ! -d ${BASEDIR}/${API_BNS_DATA_LOCAL} ]; then
  echo "  Creating BNS DATA dir ${BASEDIR}/${API_BNS_DATA_LOCAL}"
  mkdir -p ${BASEDIR}/${API_BNS_DATA_LOCAL}
fi
if [ ! -d ${BASEDIR}/${POSTGRES_DATA_LOCAL} ]; then
  echo "  Creating Postgres data dir ${BASEDIR}/${POSTGRES_DATA_LOCAL}"
  mkdir -p ${BASEDIR}/${POSTGRES_DATA_LOCAL}
fi

if [ -f ${BASEDIR}/${STACKS_FOLLOWER_CONFIG_TEMPLATE} -a -f ${BASEDIR}/${STACKS_FOLLOWER_CONFIG_TEMPLATE} ];then
  echo "    - Updating Stacks Configs with values from files: ${BASEDIR}/.env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${BASEDIR}/${STACKS_FOLLOWER_CONFIG_TEMPLATE} \
    > ${BASEDIR}/${STACKS_FOLLOWER_CONFIG}
  echo "    - Updating Postgres SQL script with values from files: ${BASEDIR}/.env"
  envsubst "`env | awk -F = '{printf \" $%s\", $1}'`" \
    < ${BASEDIR}/${POSTGRES_SCRIPT_TEMPLATE} \
    > ${BASEDIR}/${POSTGRES_SCRIPT}
else
  echo ""
  echo "  *********************************"
  echo "  Error: missing template file(s)"
  echo "    Try 'git pull'"
  echo "    or:"
  if [ ! -f ${BASEDIR}/${STACKS_FOLLOWER_CONFIG_TEMPLATE} ]; then
    echo "      'git checkout ${STACKS_FOLLOWER_CONFIG_TEMPLATE}'"
  fi
  if [ ! -f ${BASEDIR}/${POSTGRES_SCRIPT_TEMPLATE} ]; then
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

