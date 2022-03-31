#!/bin/bash
### Parameter Breakdown
### 0th parameter is the name of the script that is currently running
### 1st parameter is the Location of the File to start with
### 2nd parameter is the failed location for this environment
### 3rd parameter is the is the working directory for the environment example : /batch/prod/
SCRIPT_PATH_NAME=$0
RAW_NEW_FILE=$1
FAILED_PATH=$2
WORKING_DIR=$3
FILE_TYPE=$4
FILENAME=$(echo "$1" | cut -f 1 -d '.')
### This step strips the path out of the script so that only the filename.sh shows in logs and will auto-update if filename ever changes
SCRIPT_NAME="${SCRIPT_PATH_NAME##*/}"
CURRENT_FILE_SHORT="${RAW_NEW_FILE##*/}"

    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | FileName: ${FILENAME}, Length: $(wc -l $RAW_NEW_FILE) "

if ls ${WORKING_DIR}${FILE_TYPE}* &> /dev/null; then
    mv "$WORKING_DIR/$FILE_TYPE"* "$FAILED_PATH"
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | Checking for previous incomplete processing. Files found and moved to $FAILED_PATH"
fi

if [[ -f ${FILENAME}.SIG ]]; then
    ### Stripping Windows NewLines from the file
    sed -i 's/\r//g' $RAW_NEW_FILE
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | ${FILENAME} Windows New Lines have been removed"
    mv "${FILENAME}".SIG "$WORKING_DIR"
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | Moving ${FILENAME}.SIG File to working directory"
    mv "$1" "$WORKING_DIR"
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | Moving ${CURRENT_FILE_SHORT} File to working directory"
    exit 0
else
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | No signature found for $CURRENT_FILE_SHORT, process is restarting"
    exit 42
fi

