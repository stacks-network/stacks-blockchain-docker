#!/bin/sh
echo ""
echo "*********************************"
echo "Setting up BNS Data"
echo "*********************************"
echo ""
TARFILE="${BNS_IMPORT_DIR}/export-data.tar.gz"
if [ ! -f "${TARFILE}" ]; then
    echo "Retrieving V1 BNS data as ${BNS_IMPORT_DIR}/export-data.tar.gz"
    wget "https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz" -O "${TARFILE}"
    if [ $? -ne 0 ]; then
        echo "  - Failed to download https://storage.googleapis.com/blockstack-v1-migration-data/export-data.tar.gz -> ${TARFILE}"
        exit 1
    fi
else
    echo "Found existing tarfile: ${TARFILE}"
fi

## Try to extract BNS files individually (faster if we're only missing 1 or 2 of them)
BNS_FILES="
    chainstate.txt
    name_zonefiles.txt 
    subdomain_zonefiles.txt 
    subdomains.csv
"

check_sha256(){
    local file="$1"
    local file_256="${file}.sha256"
    local file_path="${BNS_IMPORT_DIR}/${file}"
    local file_256_path="${BNS_IMPORT_DIR}/${file_256}"
    if [ -f "${file_path}" -a -f "${file_256_path}" ]; then
        echo "Checking sha256 of ${file}"
        local sha256=$(cat ${file_256_path})
        local sha256sum=$(sha256sum ${file_path} | awk {'print $1'})
        if [ "$sha256" != "$sha256sum" ]; then
            echo "[ Warning ] - sha256 mismatch"
            echo "    - Removing ${file} and ${file_256}, re-attempting sha256 verification"
            rm -f "${file_path}"
            rm -f "${file_256_path}"
            counter=$((counter+1))
            if ! extract_files "${file}"; then
                exit 1
            fi            
        else
            echo "  - Matched sha256 of ${file} and $file_256"
            return 0
        fi 
    else
        counter=$((counter+1))
        if ! extract_files "${file}"; then
            exit 1
        fi
    fi
    return 1
}

extract_files() {
    local file="$1"
    local file_256="${file}.sha256"
    local file_path="${BNS_IMPORT_DIR}/${file}"
    local file_256_path="${BNS_IMPORT_DIR}/${file_256}"
    if [ "$counter" -gt "1" ];then
        echo
        echo "[ Error ] - Failed to verify sha56 of $file after 2 attempts"
        exit 1
    fi
    if [ ! -f "${file_256_path}" ]; then
        echo "Extracting BNS sha256 file: ${file_256_path}"
        if ! tar -xzf ${TARFILE} -C ${BNS_IMPORT_DIR}/ ${file_256}; then
            echo "  - Failed to extract ${file_256_path}"
            return 1
        fi
    fi
    if [ ! -f "${file_path}" ]; then
        echo "Extracting BNS text file: ${file_path}"
        if ! tar -xzf ${TARFILE} -C ${BNS_IMPORT_DIR}/ ${file}; then
            echo "  - Failed to extract ${file_path}"
            echo "Exiting"
            return 1
        fi
    fi
    # if [ "$counter" -eq "1" ];then
    #     echo "Re-attempting sha256 verification of $file and $file_256"
    # fi
    check_sha256 "$file"
    return 0
}


for FILE in $BNS_FILES; do
    counter=0
    echo
    check_sha256 "${FILE}"
done
echo
echo "Complete"
exit 0

