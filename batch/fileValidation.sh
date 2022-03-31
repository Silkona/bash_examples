#!/bin/bash
### Parameter Breakdown
### 0th parameter is the name of the script that is currently running
### 1st parameter is the Location of the File to start with
### 2nd parameter is the number of columns we expect in the current and previous CSV
### 3rd parameter is the failed location for this environment
### 4th parameter is the working directory for the environment example : /batch/prod/
FILENAME=$(echo "$1" | cut -f 1 -d '.')
FILE_LENGTH=$(awk -F, 'END {printf "%s", NR}' "$1")
COMPONENTS=( $(grep -Eo '[A-Z_/a-z]+|[0-9_.]+' <<<"$1") )
RAW_PREV_FILE="${COMPONENTS[0]}PREV_${COMPONENTS[1]}${COMPONENTS[2]}"
SCRIPT_PATH_NAME=$0
RAW_NEW_FILE=$1
EXPECTED_COLUMNS=$2
FAILED_PATH=$3
WORKING_DIR=$4
ROW_NUMBER=1
ROW_NUMBER_PREV=1
FAILED_COUNT=0
FILE_TYPE=$(echo $COMPONENTS | awk -F / '{print $5}')
### This step strips the path out of the script so that only the filename.sh shows in logs and will auto-update if filename ever changes
SCRIPT_NAME="${SCRIPT_PATH_NAME##*/}"
CURRENT_FILE_SHORT="${RAW_NEW_FILE##*/}"

if ls ${WORKING_DIR}${FILE_TYPE}* &> /dev/null; then
    mv "$WORKING_DIR/$FILE_TYPE"* "$FAILED_PATH"
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | Checking for previous incomplete processing. Files found and moved to $FAILED_PATH"
fi

if [[ -f ${FILENAME}.SIG ]]; then
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | FileName: $RAW_NEW_FILE, FileEncoding: $(file -i "$RAW_NEW_FILE" | awk -F = '{print $2}'), Number of Rows: $FILE_LENGTH"
else
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | No signature found for $RAW_NEW_FILE, process is restarting"
    exit 42
fi
if [ -f "$RAW_PREV_FILE" ]; then
    PREV_FILE_LENGTH=$(awk -F, 'END {printf "%s", NR}' "$RAW_PREV_FILE")
    LENGTH_DIFFERENCE=$((FILE_LENGTH-PREV_FILE_LENGTH))
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | Previous FileName: $RAW_PREV_FILE, FileEncoding: $(file -i "$RAW_PREV_FILE" | awk -F = '{print $2}'), Number of Rows: $PREV_FILE_LENGTH, Difference in File Lengths:  ${LENGTH_DIFFERENCE#-}"
else
    echo "$(date +%FT%T) | WARN | $SCRIPT_NAME | $RAW_PREV_FILE File could not be found, $FILE_TYPE Files moved to $FAILED_PATH"
    mv "$RAW_NEW_FILE" "$FAILED_PATH"
    mv "$RAW_PREV_FILE" "$FAILED_PATH"
    mv ${FILENAME}.SIG "$FAILED_PATH"
    exit 42
fi
# Count Columns, remove Windows Line endings and last line if empty
COLUMNS=($( sed 's/\r//g;${/^$/d;}' $1 | awk -F, '{ print NF }'))
for COLUMN_COUNT in "${COLUMNS[@]}"
do
   if [ $EXPECTED_COLUMNS -ne $COLUMN_COUNT ]; then
      echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Number of Columns did not match expected value for file: $CURRENT_FILE_SHORT. Expected $EXPECTED_COLUMNS, found $COLUMN_COUNT on row $ROW_NUMBER"
      ((FAILED_COUNT++))
   fi
   ((ROW_NUMBER++))
done

if [ $FAILED_COUNT == 0 ]; then
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | File $RAW_NEW_FILE matches the correct number of columns"
else
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Total number of mismatched columns: $FAILED_COUNT for $RAW_NEW_FILE"
    mv "$RAW_NEW_FILE" "$FAILED_PATH"
    mv "$RAW_PREV_FILE" "$FAILED_PATH"
    mv ${FILENAME}.SIG "$FAILED_PATH"
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | ${RAW_NEW_FILE##*/}, ${RAW_PREV_FILE##*/}, $FILENAME.SIG have been moved to $FAILED_PATH"
    exit 42
fi

# Count Columns, remove Windows Line endings and last line if empty
COLUMNS_PREV=($( sed 's/\r//g;${/^$/d;}' $RAW_PREV_FILE | awk -F, '{ print NF }'))
for COLUMN_COUNT_PREV in "${COLUMNS_PREV[@]}"
do
   if [ $EXPECTED_COLUMNS -ne $COLUMN_COUNT_PREV ]; then
      echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Number of Columns did not match expected value for file: ${RAW_PREV_FILE##*/}. Expected $EXPECTED_COLUMNS, found $COLUMN_COUNT_PREV on row $ROW_NUMBER_PREV"
      ((FAILED_COUNT++))
   fi
   ((ROW_NUMBER_PREV++))
done

if [ $FAILED_COUNT == 0 ]; then
    echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | File $RAW_PREV_FILE matches the correct number of columns"
else
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | Total number of mismatched columns: $FAILED_COUNT for $RAW_PREV_FILE"
    mv "$RAW_NEW_FILE" "$FAILED_PATH"
    mv "$RAW_PREV_FILE" "$FAILED_PATH"
    mv ${FILENAME}.SIG "$FAILED_PATH"
    echo "$(date +%FT%T) | ERROR | $SCRIPT_NAME | ${RAW_NEW_FILE##*/}, ${RAW_PREV_FILE##*/}, $FILENAME.SIG have been moved to $FAILED_PATH"
    exit 42
fi

cp "$RAW_PREV_FILE" "$RAW_PREV_FILE".orig
cp "$RAW_NEW_FILE" "$RAW_NEW_FILE".orig
# Remove first line (header) remove Windows Line endings and last line if empty
sed -i 's/\r//g;${/^$/d;};1d' "$RAW_PREV_FILE"
sed -i 's/\r//g;${/^$/d;};1d' "$RAW_NEW_FILE"
echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | Header Line of $RAW_NEW_FILE and $RAW_PREV_FILE have been removed"
# Move Previous RAW file to working dir
mv "$RAW_PREV_FILE"* "$WORKING_DIR"
# Copy New Raw file to working dir
mv "$RAW_NEW_FILE"* "$WORKING_DIR"
mv "${FILENAME}".SIG "$WORKING_DIR"
echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | Moving ${RAW_NEW_FILE}, ${RAW_PREV_FILE}, $FILENAME.SIG File to working directory"

echo "$(date +%FT%T) | INFO | $SCRIPT_NAME | $RAW_NEW_FILE has been passed to XXX to begin processing"
exit 0
