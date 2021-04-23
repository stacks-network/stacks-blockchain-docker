#!/bin/sh
echo ""
echo "*********************************"
echo "Setting up BNS Data"
echo ""
echo "  Checking for existing file ${API_BNS_DATA}/export-data.tar.gz"
if [ ! -f ${API_BNS_DATA}/export-data.tar.gz ]; then
  echo "    - Retrieving V1 BNS data as ${API_BNS_DATA}/export-data.tar.gz"
  wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O ${API_BNS_DATA}/export-data.tar.gz
  if [ $? -ne 0 ]; then
    echo "      - Failed to download https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -> ${API_BNS_DATA}/export-data.tar.gz"
    exit 1
  fi
fi
## Try to extract BNS files individually (faster if we're only missing 1 or 2 of them)
BNS_FILES="
  chainstate.txt
  name_zonefiles.txt 
  subdomain_zonefiles.txt 
  subdomains.csv
"
for FILE in $BNS_FILES; do
  if [ ! -f ${API_BNS_DATA}/$FILE ]; then
    echo "  Extracting Missing BNS text file: ${API_BNS_DATA}/$FILE"
    tar -xzf ${API_BNS_DATA}/export-data.tar.gz -C ${API_BNS_DATA}/ ${FILE}
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  fi
  if [ ! -f ${API_BNS_DATA}/${FILE}.sha256 ]; then
    echo "  Extracting Missing BNS sha256 file: ${API_BNS_DATA}/${FILE}.sha256"
    tar -xzf ${API_BNS_DATA}/export-data.tar.gz -C ${API_BNS_DATA}/ ${FILE}.sha256
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  fi
done
echo "Exiting"
exit 0

