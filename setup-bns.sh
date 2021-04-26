#!/bin/sh
echo ""
echo "*********************************"
echo "Setting up BNS Data"
echo ""
echo "  Checking for existing file ${BNS_IMPORT_DIR}/export-data.tar.gz"
if [ ! -f ${BNS_IMPORT_DIR}/export-data.tar.gz ]; then
  echo "    - Retrieving V1 BNS data as ${BNS_IMPORT_DIR}/export-data.tar.gz"
  wget https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -O ${BNS_IMPORT_DIR}/export-data.tar.gz
  if [ $? -ne 0 ]; then
    echo "      - Failed to download https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -> ${BNS_IMPORT_DIR}/export-data.tar.gz"
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
  if [ ! -f ${BNS_IMPORT_DIR}/$FILE ]; then
    echo "  Extracting Missing BNS text file: ${BNS_IMPORT_DIR}/$FILE"
    tar -xzf ${BNS_IMPORT_DIR}/export-data.tar.gz -C ${BNS_IMPORT_DIR}/ ${FILE}
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  else
    echo "  Using Existing BNS text file: ${BNS_IMPORT_DIR}/$FILE"
  fi
  if [ ! -f ${BNS_IMPORT_DIR}/${FILE}.sha256 ]; then
    echo "  Extracting Missing BNS sha256 file: ${BNS_IMPORT_DIR}/${FILE}.sha256"
    tar -xzf ${BNS_IMPORT_DIR}/export-data.tar.gz -C ${BNS_IMPORT_DIR}/ ${FILE}.sha256
    if [ $? -ne 0 ]; then
      echo "    - Failed to extract ${FILE}"
    fi
  else
    echo "  Using Existing BNS sha256 file: ${BNS_IMPORT_DIR}/$FILE"
  fi
done
echo "Exiting"
exit 0


