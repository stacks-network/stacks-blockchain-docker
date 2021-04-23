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
# echo ""
# echo "*********************************"
# echo "Setting up BNS Data"
# echo ""
# if [ ! -d ./bns-data ]; then
#   echo "  Creating BNS DATA dir ./bns-data"
#   mkdir ./bns-data
# fi
# echo "  Checking for existing file export-data.tar.gz"
# if [ ! -f export-data.tar.gz ]; then
#   echo "    - Retrieving V1 BNS data as ./export-data.tar.gz"
#   wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O export-data.tar.gz
#   if [ $? -ne 0 ]; then
#     echo "      - Failed to download https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -> export-data.tar.gz"
#     exit 1
#   fi
# fi
# ## Try to extract BNS files individually (faster if we're only missing 1 or 2 of them)
# BNS_FILES="
#   chainstate.txt
#   name_zonefiles.txt 
#   subdomain_zonefiles.txt 
#   subdomains.csv
# "
# for FILE in $BNS_FILES; do
#   if [ ! -f ./bns-data/$FILE ]; then
#     echo "  Extracting Missing BNS text file: ./bns-data/$FILE"
#     tar -xzf export-data.tar.gz -C ./bns-data/ ${FILE}
#     if [ $? -ne 0 ]; then
#       echo "    - Failed to extract ${FILE}"
#     fi
#   fi
#   if [ ! -f ./bns-data/${FILE}.sha256 ]; then
#     echo "  Extracting Missing BNS sha256 file: ./bns-data/${FILE}.sha256"
#     tar -xzf export-data.tar.gz -C ./bns-data/ ${FILE}.sha256
#     if [ $? -ne 0 ]; then
#       echo "    - Failed to extract ${FILE}"
#     fi
#   fi
# done
echo "Exiting"
exit 0

