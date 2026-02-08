#!/bin/sh
#Script for assignment1

if [ $# -ne 2 ] 
then 
	echo "Invalid arguments" 
        exit 1
else 
	FILEDIR=$1 SEARCHSTR=$2

fi

# check filedir represent directory on filesystem
if [ ! -d "$FILEDIR" ]; then
    echo "Error: Directory '$FILEDIR' not on file system."
    exit 1
fi

# Count number of files
FILECOUNT=$(find "$FILEDIR" -type f | wc -l)

# Count number of files in directory matching to the search string
NUM_MATCHES=$(grep -r "$SEARCHSTR" "$FILEDIR" 2>/dev/null | wc -l)

# Output result
echo "The number of files are $FILECOUNT and the number of matching lines are $NUM_MATCHES"
