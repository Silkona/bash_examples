#!/bin/bash

### Parameter Breakdown
### 0th parameter is the name of the script that is currently running
### 1st parameter is the name of the file currently being worked on
### 2nd parameter is the is the file location currently being worked on
### 3rd parameter is the working directory for the file type
### 4th parameter is the location of the config yml for the XXX
### 5th parameter is the location of the XXX JAR file
### 6th parameter is the failed location for this environment
### 7th parameter is the expected number of columns in the PSV file that has been converted or already exists.

SCRIPT_PATH_NAME=$0
TAG_RAW=$1
### The following will strip the ./ from the parameter to ensure ease of readability
TAG=${TAG_RAW:2}
TAG_SHORT=${TAG%.*}
INPUT=$2
OUTPUT_PATH=$3
OUTPUT=$OUTPUT_PATH/$TAG.json
CONFIG=$4
XXX=$5
FAILED_PATH=$6
SCRIPT_NAME="${SCRIPT_PATH_NAME##*/}"
EXPECTED_COLUMNS=$7
ROW_NUMBER=1
FAILED_COUNT=0

# Count Columns, remove Windows Line endings and last line if empty
COLUMNS=($( sed 's/\r//g;${/^$/d;}' "$INPUT" | awk -F'|' '{ print NF }'))
for COLUMN_COUNT in "${COLUMNS[@]}"
do
   if [ "$EXPECTED_COLUMNS" -ne $COLUMN_COUNT ]; then
      echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Number of Columns did not match expected value for file: $TAG. Expected $EXPECTED_COLUMNS, found $COLUMN_COUNT on row $ROW_NUMBER"
      ((FAILED_COUNT++))
   fi
   ((ROW_NUMBER++))
done


### OMMITTED SECTION ###


if [ "$FAILED_COUNT" == 0 ]; then
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | File $TAG matches the correct number of columns"
else
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Total number of mismatched columns: $FAILED_COUNT for $TAG"
    cp "$3/$TAG_SHORT.SIG" "$FAILED_PATH"
    cp "$INPUT" "$FAILED_PATH"
    cp "$OUTPUT" "$FAILED_PATH"
    if [[ -f "$3/$TAG_SHORT.TXT" ]]; then
        cp "$3/$TAG_SHORT.TXT" "$FAILED_PATH"
        echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | ${TAG_SHORT}.converted.psv, ${TAG}.json, ${TAG_SHORT}.SIG and ${TAG_SHORT}.TXT have been moved to $FAILED_PATH"
    else
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | ${TAG_SHORT}.PSV, ${TAG_SHORT}.PSV.json and ${TAG_SHORT}.SIG have been moved to $FAILED_PATH"
    fi
fi

### This step will check the output from the XXX, if the file failed to process it will be moved to the failed directory
### If the file succeeded in being processed but some lines failed it will move the raw file to the failed directory.
if [ ! -f  "$OUTPUT" ]
then
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | File: $TAG | Failed conversion detected: $TAG.json not found. $TAG has been moved to $FAILED_PATH"
    mv "$INPUT" "$FAILED_PATH"
    mv "$3/$TAG_SHORT*.SIG" "$FAILED_PATH"
    exit 42
else
    ### Check the line count of the input file minus headers
    RAW_COUNT=$(grep . "$INPUT" | wc -l)
    ### Check the line count of the output file
    CONVERTED_COUNT=$(grep . "$OUTPUT" | wc -l)
    ### Compare the line counts of imput and output and log if they are different
    if [ "${RAW_COUNT}" != "${CONVERTED_COUNT}" ]
    then
        echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | File: $TAG | Failed line conversion detected: ${CONVERTED_COUNT} out of ${RAW_COUNT} lines were successfully converted."
        cp "$INPUT" "$FAILED_PATH"
        cp "$3/$TAG_SHORT.SIG" "$FAILED_PATH"
        if [[ -f "$3/$TAG_SHORT.TXT" ]]; then
          cp "$3/$TAG_SHORT.TXT" "$FAILED_PATH"
          echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | $TAG, ${TAG_SHORT}.SIG and ${TAG_SHORT}.TXT has been moved to $FAILED_PATH"
         else
         echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME |  $TAG and ${TAG_SHORT}.SIG has been moved to $FAILED_PATH"
         fi
    fi
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | File: $TAG | $CONVERTED_COUNT lines were converted"
fi

echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | File: $TAG | Successful lines have been passed to the next stage of the batch-controller"
exit 0
