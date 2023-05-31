#!/bin/bash

# TO DO #
# - Ensure there are no duplicate files with different versions
# - If there are duplicate files only update version of the latest in the commit
# - This will force the deployment to only run a migrate for the latest file.
# - Include EBR into deployment

### VARIABLES ###
# Array of schema object parent folders. Variable is defined in the CD yml.
NON_REPEATABLE_FILES_FILE=${PWD}/non_repeatable_changed_files.txt
NON_REPEATABLE_FILE_NAME="$(basename -- ${NON_REPEATABLE_FILES_FILE})"
REPEATABLE_FILES_FILE=${PWD}/repeatable_changed_files.txt
REPEATABLE_FILE_NAME="$(basename -- ${REPEATABLE_FILES_FILE})"
COMMIT=`echo ${SHA} | head -c10`

### FUNCTIONS ###
# LIST FILES - REPEATABALE FILES
list_files_repeatable(){
    SCHEMA=("$@")
    CHANGED_FILES_FILE=${REPEATABLE_FILES_FILE}
    CHANGED_FILE_NAME="$(basename -- ${REPEATABLE_FILES_FILE})"

    # [ find -type f ] - find files in current path
    # [ egrep -i egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW" ] - extended grep with ignore word casing for a all the directoriees in the list. 
    # [ sed 's:[^/]*/\(.*\):\1:' ] - show fil and path with file extension ./AAPEN/AAPEN/AAPEN/FUNCTION/FUNCTION.FNC
    # [ > ${CHANGED_FILES_FILE} ] - add list to $REPEATABLE_FILES_FILE
    find -type f | egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW" | sed 's:[^/]*/\(.*\):\1:' > ${CHANGED_FILES_FILE}
}

# LIST FILES - NON-REPEATABALE FILES 
list_files_non_repeatable(){
    SCHEMA=("$@")
    CHANGED_FILES_FILE=${NON_REPEATABLE_FILES_FILE}
    CHANGED_FILE_NAME="$(basename -- ${NON_REPEATABLE_FILES_FILE})"

    # Check if table deployments flag is on include TABLE directort
    if ${TABLES} || ${TABLES} = true;
    then
        echo -e "\m[WARN]: Tables flag is set to [true]. Flyway will migrate .tbl objects."
        TABLE="|${SCHEMA}/TABLE"
    else
        echo -e "[INFO]: Tables flag is set to [false]. Flyway will migrate without .tbl objects.\n"
    fi

    # [ find -type f ] - find files in current path
    # [ egrep -i egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW" ] - extended grep with ignore word casing for a all the directoriees in the list. 
    # [ sed 's:[^/]*/\(.*\):\1:' ] - show fil and path with file extension ./AAPEN/AAPEN/AAPEN/FUNCTION/FUNCTION.FNC
    # [ > ${CHANGED_FILES_FILE} ] - add list to $REPEATABLE_FILES_FILE
    find -type f | grep -v ".git*" | egrep -i "${SCHEMA}/CONSTRAINT|${SCHEMA}/INDEX|${SCHEMA}/MATERIALIZED_VIEW|${SCHEMA}/PACKAGE|${SCHEMA}/PACKAGE_BODY|${SCHEMA}/SEQUENCE${TABLE}" | sed 's:[^/]*/\(.*\):\1:' > ${CHANGED_FILES_FILE}
}

# RENAME FILES - rename changed files (for commit purposes) and copy files to flyway/sql (for flyway deployments)
rename_files(){
    if [[ -d ${PWD}/flyway/sql ]]
    then
        echo -e "[INFO]: Renaming [$FILE] to [${NEW_FILE_NAME}] for flyway purposes"
        echo -e "[INFO]: Making directory [${PWD}/flyway/sql/${FILE_PATH}] and adding [${FILE}] for flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${FILE_PATH} && cp ${PWD}/${FILE} ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME}
    else
        echo -e "\n[INFO]: Renaming [$FILE] to [${NEW_FILE_NAME}] for flyway purposes"
        echo -e "[INFO]: Making directory [${PWD}/flyway/sql/${FILE_PATH}] and adding [${FILE}] for flyway purposes"
        mkdir -p ${PWD}/flyway/sql/${FILE_PATH} && cp ${PWD}/${FILE} ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME}
    fi   
}

# UTILS FILES - Logic for versioning of files
# This functions copies utils files for Edition Based Redefinitions to flyway/sql so that are then run before the flyway migrate process is run for each schema deployment
utils_files(){
# $FILE is each file from the array of files that is parsed in e.g. EDITION_CREATE
FILE=("$@")
    # If flyway/sql/${SCHEMA} exists:
    #   1. Make direcotry for flyway/sql/${SCHEMA}/${FILE} e.g. flyway/sql/AAPEN/EDITION_CREATE
    #   2. Copy the ${PWD}/utils/${FILE} from utils to ${PWD}/flyway/sql/${SCHEMA}/${FILE} and rename it to beforeMigrate.sql e.g. utils/EDITION_CREATE.sql is added as flyway/sql/AAPEN/EDITION_CREATE/beforeMigrate.sql
    # If NOT exists:
    #   1. Make direcotry for flyway/sql/${SCHEMA}/${FILE} e.g. flyway/sql/AAPEN/EDITION_CREATE
    #   2. Copy the ${PWD}/utils/${FILE} from utils to ${PWD}/flyway/sql/${SCHEMA}/${FILE} and rename it to beforeMigrate.sql e.g. utils/EDITION_CREATE.sql is added as flyway/sql/AAPEN/EDITION_CREATE/beforeMigrate.sql   
    if [[ -d ${PWD}/flyway/sql/${SCHEMA} ]]
    then
        echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}] flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/${FILE}/beforeMigrate.sql
    else     
        echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}] flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/${FILE}/beforeMigrate.sql
    fi
}

# REPEATABLE FILES - Logic for versioning of files
# This functions handles the naming for repeatable files.
# Repeatable files have to start with R and end with __ 
# https://www.red-gate.com/blog/database-devops/flyway-naming-patterns-matter
repeatable_changed_files_version(){
    # For each file in the $REPEATABLE_FILES_FILE
    # 1. Break down the file and reconstruct it correctly
    # 2. Parse the variable to renam_files functions 
    for FILE in $(cat ${REPEATABLE_FILES_FILE});
    do 
        echo "[INFO]: REPEATABLE FILE DETAILS:"
        # [ $(dirname -- ${FILE} ] - Get directory path only e.g. AAPEN/AAPEN/AAPEN/FUNCTION
        # [ tr '[:lower:]' '[:upper:]')" ] - Translate form lower casing to upper
        FILE_PATH="$(dirname -- ${FILE} | tr '[:lower:]' '[:upper:]')"

        # [ $(basename -- ${FILE} ] - Get the file name only e.g. FUNCTION.FNC
        # [ tr '[:lower:]' '[:upper:]')" ] - Translate form lower casing to upper
        FILE_NAME="$(basename -- ${FILE} | tr '[:lower:]' '[:upper:]')"
    
        # [ sed 's/\.[^.]*$//' ] - regex pattern match the file extension at the end of a string.
        # [ s ] - used to search and replace operations on the input text. 
        # [ / ] - used for pattern matching and sed use s/// for substitution e.g. s///
        # [ . ] - match any character, including newline
        # [ ^ ] - match start of
        # [ * ] - match 0 or more occurances
        # [ $ ] - match the end of a string.
        # [ \ ] - used to escape character
        # https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html
        # https://en.wikipedia.org/wiki/Sed
        FILE_NAME_ONLY=`echo ${FILE_NAME} | sed 's/\.[^.]*$//'`
        
        FILE_SIZE=`stat --printf="%s" ${FILE}`

        # Append the file to start with R__
        NEW_VERSION="R" 
        NEW_FILE_NAME="${NEW_VERSION}__$FILE_NAME"

        echo "FILE PATH: ${FILE_PATH}"
        echo "FILE NAME: ${FILE_NAME_ONLY}"
        echo "FILE SIZE: ${FILE_SIZE}B"
        echo "NEW FILE NAME: $NEW_FILE_NAME" 
        echo "NEW FILE: ${FILE_PATH}/${NEW_FILE_NAME}"
        rename_files
    done
}

# NON REPEATABLE FILES - Logic for versioning of files
# This functions handles the naming for non-repeatable files.
# Non-repeatable files have to start with V and follow a version patter with that ends with __
# The version pattern used for non-repeatable files is: VYYYY.MM.DD.HH.MM.$NEW_VERSION_NUMBER__
# https://www.red-gate.com/blog/database-devops/flyway-naming-patterns-matter
non_repeatable_changed_files_version(){
    # NEW_VERSION_NUMBER is used as a counter to allow for multiple versioned files to be deployed. 
    # This is needed because flyway cannot migrate files with the same version number. e.g. V2023.01.16.15.00.1__AAPEN.TABLE.TBL & V2023.01.16.15.00.2__AAPEN.FUNCTION.FNC
    NEW_VERSION_NUMBER=0 

    # For each file in the $NON_REPEATABLE_FILES_FILE
    # 1. Break down the file and reconstruct it correctly
    # 2. Parse the variable to renam_files functions 
    for FILE in $(cat ${NON_REPEATABLE_FILES_FILE});
    do 
        # Existing (branch) file details
        echo "[INFO]: NON-REPEATABLE FILE DETAILS:"
        # [ $(dirname -- ${FILE} ] - Get directory path only e.g. AAPEN/AAPEN/AAPEN/TABLE
        # [ tr '[:lower:]' '[:upper:]')" ] - Translate form lower casing to upper        
        FILE_PATH="$(dirname -- ${FILE} | tr '[:lower:]' '[:upper:]')"

        # [ $(basename -- ${FILE} ] - Get directory path only e.g. TABLE.tbl
        # [ tr '[:lower:]' '[:upper:]')" ] - Translate form lower casing to upper              
        FILE_NAME="$(basename -- ${FILE} | tr '[:lower:]' '[:upper:]')"

        # [ sed 's/\.[^.]*$//' ] - regex pattern match the file extension at the end of a string.
        # [ s ] - used to search and replace operations on the input text. 
        # [ / ] - used for pattern matching and sed use s/// for substitution e.g. s///
        # [ . ] - match any character, including newline
        # [ ^ ] - match start of
        # [ * ] - match 0 or more occurances
        # [ $ ] - match the end of a string.
        # [ \ ] - used to escape character
        # https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html
        # https://en.wikipedia.org/wiki/Sed

        FILE_NAME_ONLY=`echo ${FILE_NAME} | sed 's/\.[^.]*$//'`
        CURRENT_VERSION=${FILE_NAME_ONLY}
        FILE_SIZE=`stat --printf="%s" ${FILE}`

        echo "FILE PATH: ${FILE_PATH}"
        echo "FILE NAME: ${FILE_NAME_ONLY}"
        echo "FILE SIZE: ${FILE_SIZE}B"

        # New file details (new file version)
        # NEW_VERSION NUMBER is used to increment the counter
        ((NEW_VERSION_NUMBER++))
        DATE=`date +"%Y.%m.%d.%H%M"`
        NEW_VERSION="V${DATE}.${NEW_VERSION_NUMBER}"
        NEW_FILE_NAME="${NEW_VERSION}__${FILE_NAME}"
        
        echo "NEW FILE VERSION: ${NEW_VERSION}"
        echo "NEW FILE NAME: $NEW_FILE_NAME"        
        echo "NEW FILE: ${FILE_PATH}/${NEW_FILE_NAME}"
        rename_files
    done
}

update-placeholder() {
  dir="$1"
  keyword="$2"
  value="$3"
  files=$(find "$dir" -name '*.sql' -type f)
  # Replace the keyword in all files
  for file in $files; do
    # q - not print anything to the console
    if grep -q "$keyword" "$file"; then
      # i - modify the file rather than printing to terminal
      # s -substitute
      # g - replace all occurance
      sed -i "s/$keyword/$value/g" "$file"
      echo -e "\n[INFO]: Keyword '$keyword' found and replaced with '$value' in [$file]"
    else
      echo -e "\n[INFO]: Keyword '$keyword' not found in [$file]"
    fi
  done
}

### SCRIPT STARTS HERE ###
# Get current banch (only needed for re-runs of pipeline)
git pull

# Check if flyway/sql exists and remove before creating.
# Flyway/sql should not exist in an initial run because it should not be committed.
if [[ -d ${PWD}/flyway/sql ]]
then
    echo -e "\n[WARN]: /flyway/sql exists. Was it accidentally commited?"
    echo "[INFO] Removing [${PWD}/flyway/sql]."
    rm -rf ${PWD}/flyway/sql
fi

# REPEATABLE FILES #
# 1. Check if repeatable_changed_files.txt exists. If yes then first delete it.
# 2. Execute git diff, create and add a list of different/changed files to repeatable_changed_files.txt
# 3. Get file versions and update with new R. This will rename the existing files and copy a version of renamed files to flyway/sql.
# 4. Commit renamed files to repository. 
# ** flyway/sql is not commited!!! .gitignore prevents this. flyway/sql is only stored as an artifact and used for flyway deployments in the CD.) 
if [[ -f ${REPEATABLE_FILES_FILE} ]]
then
    # Check if repeatable list files exists and remove
    echo "[INFO]: Old [${REPEATABLE_FILE_NAME}] present. Removing before proceeding with git diff."
    echo -e "\n[WARN]: [${REPEATABLE_FILE_NAME}] is created dynamically and should not be committed to repo. Please investigate!"
    rm -rf ${REPEATABLE_FILES_FILE}
   
    # Git diff for repeatable files and update file versions
    echo "[INFO]: Creating [${REPEATABLE_FILE_NAME}] and renaming for flyway."
    list_files_repeatable "${SCHEMA[@]}"
    repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${REPEATABLE_FILES_FILE}]."
    rm -rf ${REPEATABLE_FILES_FILE}
elif [[ ! -f ${REPEATABLE_FILES_FILE} ]]
then
    # Git diff for repeatable files and update file versions
    echo "[INFO]: Creating [${REPEATABLE_FILE_NAME}] and renaming for flyway."
    list_files_repeatable "${SCHEMA[@]}"
    repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${REPEATABLE_FILES_FILE}] and renaming for flyway"
    rm -rf ${REPEATABLE_FILES_FILE}
fi

# NON-REPEATABLE FILES #
# 1. Check if repeatable_changed_files.txt exists. If yes then first delete it.
# 2. Execute git diff, create and add a list of different/changed files to repeatable_changed_files.txt
# 3. Get file versions and update with new VDDDD.MM.HH.SS.<i>. This will rename the existing files and copy a version of renamed files to flyway/sql.
# 4. Commit renamed files to repository. 
# ** flyway/sql is not commited!!! .gitignore prevents this. flyway/sql is only stored as an artifact and used for flyway deployments in the CD.) 
if [[ -f ${NON_REPEATABLE_FILES_FILE} ]]
then
    # Check if non repeatable list files exists and remove
    echo "[INFO]: Old [${NON_REPEATABLE_FILE_NAME}] present. Removing before proceeding."
    echo -e "\n[WARN]: [${NON_REPEATABLE_FILE_NAME}] is created dynamically and should not be committed to repo. Please investigate!"
    rm -rf ${NON_REPEATABLE_FILES_FILE}
   
    # Git diff for non repeatable files and update file versions
    echo "[INFO]: Creating [${NON_REPEATABLE_FILE_NAME}]."
    list_files_non_repeatable "${SCHEMA[@]}"
    non_repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${NON_REPEATABLE_FILES_FILE}]."
    rm -rf ${NON_REPEATABLE_FILES_FILE}
elif [[ ! -f ${NON_REPEATABLE_FILES_FILE} ]]
then
    # Git diff for non repeatable files and update file versions
    echo "[INFO]: Creating [${NON_REPEATABLE_FILE_NAME}]."    
    list_files_non_repeatable "${SCHEMA[@]}"
    non_repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${NON_REPEATABLE_FILES_FILE}]."
    rm -rf ${NON_REPEATABLE_FILES_FILE}
fi

update-placeholder "${PWD}/utils" "${COMMIT_ID_PLACEHOLDER}" "${COMMIT}"

# UTILS FILES
FILES=("EDITION_CREATE" "EDITION_DROP" "EDITION_SET")
SCHEMA=("GITHUB_DEPLOY_USER")
for FILE in "${FILES[@]}";
do
    utils_files "${FILE[@]}"
done

# EDITION SET
FILES=("EDITION_SET_SESSION")
SCHEMAS=("AAPEN" "DISPORT" "GLOBAL")
for SCHEMA in "${SCHEMAS[@]}";
do
    for FILE in "${FILES[@]}";
    do  
        utils_files "${FILE[@]}"
    done
done
