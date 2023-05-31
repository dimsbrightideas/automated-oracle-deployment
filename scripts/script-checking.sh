#!/bin/bash

### VARIABLES ###
ROOT=${PWD}/flyway/sql
KEYWORDS=("DROP\s*TABLE" "TRUNCATE\s*TABLE" "DROP\s*FROM")

APPROVAL_FLAG="false"

### FUNCTIONS ###
# This function validates the checks against all the changed files in the given SCHEMA
check-script(){
    echo -e "[INFO]: Checking scripts in $1"
    # Find all changed files in the SCHEMA
    FILES=$(find $1 -type f)
    
    # Validate check for all the files
    for FILE in $FILES;
    do  
        check-for-tables $FILE
        check-for-specific-keywords $FILE
    done
}

# This function checks if the file is a TABLE object
check-for-tables(){
    if [[ $1 == *.TBL ]]
    then
        echo -e "[INFO]: TABLE object found: $1"
        APPROVAL_FLAG="true"
    fi
}

# This function checks if there are any of the keywords definned in KEYWORDS in the file
check-for-specific-keywords(){
    for keyword in "${KEYWORDS[@]}"; 
    do
        if grep -iwz "$keyword" "$1" > /dev/null;
        then
            keyword=$(echo "$keyword" | sed -r 's/\\s+|\\s\*|  / /g')
            echo "Keyword '$keyword' found in file $1"
            APPROVAL_FLAG="true"
        fi
    done
}

# Checks if there are changes in the SCHEMA and validates the checks against that SCHEMA
declare -a SCHEMAS="${SCHEMAS[@]}"
for SCHEMA in "${SCHEMAS[@]}";
do
    echo "Schema=$SCHEMA"
    SCHEMA_PATH=$ROOT/$SCHEMA/$SCHEMA/$SCHEMA
    if [[ -d ${SCHEMA_PATH} ]]
    then
        echo -e "[INFO]: Changes present in AAPEN"
        check-script ${SCHEMA_PATH}
    fi
done

if [[ ${APPROVAL_FLAG} = "true" ]]
then
    echo -e "\n[INFO]: DEPLOYMENT_ENVIRONMENT will be set to [Development - Tables]"
    echo "DEPLOYMENT_ENVIRONMENT=Development - Tables" >> "$GITHUB_OUTPUT"
else
    echo -e "\n[INFO]: DEPLOYMENT_ENVIRONMENT will be set to [Development]"
    echo "DEPLOYMENT_ENVIRONMENT=Development" >> "$GITHUB_OUTPUT"
fi
