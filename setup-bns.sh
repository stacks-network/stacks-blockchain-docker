#!/bin/sh
echo ""
echo "*********************************"
echo "Setting up BNS Data"
echo ""
echo "  Checking for existing file export-data.tar.gz"
if [ ! -f /bns-data/export-data.tar.gz ]; then
  echo "    - Retrieving V1 BNS data as /bns-data/export-data.tar.gz"
  wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O /bns-data/export-data.tar.gz
  if [ $? -ne 0 ]; then
    echo "      - Failed to download https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -> export-data.tar.gz"
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
  if [ ! -f /bns-data/$FILE ]; then
    echo "  Extracting Missing BNS text file: /bns-data/$FILE"
    tar -xzf /bns-data/export-data.tar.gz -C /bns-data/ ${FILE}
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  fi
  if [ ! -f /bns-data/${FILE}.sha256 ]; then
    echo "  Extracting Missing BNS sha256 file: /bns-data/${FILE}.sha256"
    tar -xzf /bns-data/export-data.tar.gz -C /bns-data/ ${FILE}.sha256
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  fi
done
echo "Exiting"
exit 0

