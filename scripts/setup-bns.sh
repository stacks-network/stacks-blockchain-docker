#!/usr/bin/env bash

# list of files needed to import BNS names
BNS_FILES=(
    chainstate.txt
    name_zonefiles.txt 
    subdomain_zonefiles.txt 
    subdomains.csv
)

echo ""
echo "*********************************"
echo "Setting up BNS Data"
echo "*********************************"
echo ""
TARFILE="${BNS_IMPORT_DIR}/export-data.tar.gz"
# if tarfile doesn't exist, download it
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

check_sha256(){
    local file="${1}" # text file
    local file_256="${file}.sha256" # text file sha256
    local file_path="${BNS_IMPORT_DIR}/${file}" # full path to file
    local file_256_path="${BNS_IMPORT_DIR}/${file_256}" # full path to sha256 file
    # if both files exist, compare sha1sum
    if [ -f "${file_path}" -a -f "${file_256_path}" ]; then
        # retrieve/calculate the sha1sum
        local sha256=$(cat ${file_256_path})
        local sha256sum=$(sha256sum ${file_path} | awk {'print $1'})
        # if sha1sum doesn't match, remove the files and extract them
        # then, retrty this function 1 more time
        if [ "${sha256}" != "${sha256sum}" ]; then
            echo "[ Warning ] - sha256 mismatch"
            echo "    - Removing ${file} and ${file_256}, re-attempting sha256 verification"
            rm -f "${file_path}"
            rm -f "${file_256_path}"
            counter=$((counter+1))
            if ! extract_files "${file}"; then
                # if the files couldn't extract, exit
                exit 1
            fi            
        else
            # matched the sha1sum, move on to the next file in the list
            printf "  - %-25s: %-20s Matched sha256 with %s\n" "${file}" "${sha256sum}" "${file_256}" 
            return 0
        fi 
    else
        # inc counter and try the function again
        counter=$((counter+1))
        if ! extract_files "${file}"; then
            exit 1
        fi
    fi
    return 1
}

extract_files() {
    local file="${1}" # text file
    local file_256="${file}.sha256" # text file sha256
    local file_path="${BNS_IMPORT_DIR}/${file}" # full path to file
    local file_256_path="${BNS_IMPORT_DIR}/${file_256}" # full path to sha256 file
    if [ "${counter}" -gt "1" ];then
        # if we've tried extracting more than once (i.e. checked sha2sum 2x already) - exit
        echo
        echo "[ Error ] - Failed to verify sha56 of ${file} after 2 attempts"
        exit 1
    fi
    if [ ! -f "${file_256_path}" ]; then
        # extract the named file
        echo "Extracting BNS sha256 file: ${file_256_path}"
        if ! tar -xzf ${TARFILE} -C ${BNS_IMPORT_DIR}/ ${file_256}; then
            # return non-zero if we can't extract the file
            echo "  - Failed to extract ${file_256_path}"
            return 1
        fi
    fi
    if [ ! -f "${file_path}" ]; then
        # extract the named file's sha256 file
        echo "Extracting BNS text file: ${file_path}"
        if ! tar -xzf ${TARFILE} -C ${BNS_IMPORT_DIR}/ ${file}; then
            # return non-zero if we can't extract the file
            echo "  - Failed to extract ${file_path}"
            echo "Exiting"
            return 1
        fi
    fi
    # if both files were extracted, recheck the sha1sum
    check_sha256 "${file}"
    return 0
}


for FILE in ${BNS_FILES[@]}; do
    counter=0 # reset sha1sum comparison counter to 0 for each file 
    echo
    check_sha256 "${FILE}"
done
echo "Setting dir ownership"
echo "cmd: chown -R ${USER_ID} ${BNS_IMPORT_DIR}"
chown -R ${USER_ID} ${BNS_IMPORT_DIR}
echo
echo "Complete"
exit 0

