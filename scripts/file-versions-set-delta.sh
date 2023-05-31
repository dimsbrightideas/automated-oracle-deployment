#!/bin/bash

### VARIABLES ###
# Array of schema object parent folders. Variable is defined in the CD yml.
NON_REPEATABLE_FILES_FILE=${PWD}/non_repeatable_changed_files.txt
NON_REPEATABLE_FILE_NAME="$(basename -- ${NON_REPEATABLE_FILES_FILE})"
REPEATABLE_FILES_FILE=${PWD}/repeatable_changed_files.txt
REPEATABLE_FILE_NAME="$(basename -- ${REPEATABLE_FILES_FILE})"
COMMIT=`echo ${SHA} | head -c10`

### FUNCTIONS ###
# GIT DIFF - COMPARE & FILE CREATE
# This function executes the git diff commands to identify any changed/new files in the current branch
git_diff(){
    DIRECTORIES=("$@")
    # For each directory in the $DIRECTORIES:
    # 1. Execute git diff to between origin/main and current branch on that directory.
    # 2. Add any findings to the $CHANGED_FILES_FILE (either $REPEATABLE_FILES_FILE or $NON_REPEATABLE_FILES_FILE.)
     for DIR in ${DIRECTORIES[@]};
        do
            echo -e "\n[INFO]: Comparing ${CHANGED_FILES_TYPE} files in [${DIR}] for commit [${GITHUB_REF_NAME}/${COMMIT}...] with [origin/main] and adding any file(s) to [${CHANGED_FILE_NAME}].\n"

            # https://git-scm.com/docs/git-diff
            # [ --diff-filter=ACMRT ] - git diff for any files that have been: added, copied, modified, renamed or type changed
            # [ --name-only ] - shows only names of files.
            # [ origin/main ${GITHUB_WORKSPACE} ] - between origin/main and current branch e.g. feature/branch
            # [ grep ${DIR} ] - grep for $DIR to get differneces for each object type based on their directory e.g. origin/main/AAPEN/VIEW between feature/branhc/AAPEN/VIEW
            git diff --diff-filter=ACMRT --name-only origin/main ${GITHUB_WORKSPACE} | grep ${DIR}
            git diff --diff-filter=ACMRT --name-only origin/main ${GITHUB_WORKSPACE} | grep ${DIR} >> ${CHANGED_FILES_FILE}

            # If a change is present in any TABLE folder e.g. AAPEN/TABLE then:
            # 1. Check if any file has .tbl extension:
            # 2. If YES:
            #    1. Construct dynamic $SCHEMA_TABLES variable and set to true e.g. AAPEN_TABLES=true
            #    2. Set variable as $GITHUB_OUTPUT to be used by other jobs in the yml during the workflow run.  
            # 3. If NO:
            #    1. Construct dynamic $SCHEMA_TABLES variable and set to true e.g. AAPEN_TABLES=false
            #    2. Set variable as $GITHUB_OUTPUT to be used by other jobs in the yml during the workflow run.  
            # if [[ $DIR == "${SCHEMA}/TABLE" ]]
            # then
            #     TABLE_CHECK=`git diff --diff-filter=ACMRT --name-only origin/main ${GITHUB_WORKSPACE} | grep ${DIR} | egrep -i '*.tbl'`
            #     if [[ ! -z  ${TABLE_CHECK} ]]
            #     then
            #         echo -e "\n[WARN]: TABLE object founds. Tables flag is set to [true]. Flyway will migrate [${SCHEMA}] .tbl objects!"
            #         SCHEMA_TABLES="${SCHEMA}_TABLES"
            #         eval $SCHEMA_TABLES=true

            #         # Only needed for GitHub deploymnets. Not needed for local runs. 
            #         # Sets output value to be used by yaml jobs that have table deployments deploy tables
            #         # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
            #         echo "${SCHEMA_TABLES}=true" >> "$GITHUB_OUTPUT"

            #         # Only needed for GitHub deploymens. Not needed for local runs.
            #         # Sets the environment variable that determines an approval for the deployment jobs
            #         # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
            #         echo "${SCHEMA_TABLES}=true" >> "$GITHUB_ENV"
            #     else
            #         echo -e "\n[INFO]: Tables flag is set to [false]. Flyway will Flyway will NOT migrate [${SCHEMA}] .tbl objects.\n"
            #         SCHEMA_TABLES="${SCHEMA}_TABLES"
            #         eval $SCHEMA_TABLES=false
                    
            #         # Only needed for GitHub deploymnets. Not needed for local runs. 
            #         # Sets output value to be used by yaml jobs that have table deployments deploy tables
            #         # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-output-parameter
            #         echo "${SCHEMA_TABLES}=false" >> "$GITHUB_OUTPUT"

            #         # Only needed for GitHub deploymens. Not needed for local runs.
            #         # Sets the environment variable that determines an approval for the deployment jobs
            #         # https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
            #         echo "${SCHEMA_TABLES}=false" >> "$GITHUB_ENV"
            #     fi
            # fi
        done
}

# GIT DIFF - REPEATABALE FILES
# This functions executes the git_diff command for any repeatable files/objects
# This function is called by git_diff_repeatable and git_diff_non_repeatable functions 
git_diff_repeatable(){
    # Declare array variable $SCHEMAS and use the values parsed in by external variable $SCHEMAS
    # https://linuxhint.com/bash_declare_command/
    declare -a SCHEMAS="${SCHEMAS[@]}"
    CHANGED_FILES_TYPE="repeatable"    
    CHANGED_FILES_FILE=${REPEATABLE_FILES_FILE}
    CHANGED_FILE_NAME="$(basename -- ${REPEATABLE_FILES_FILE})"

    # For each scheam in the array of schemas:
    # 1. Find all directories for repeatable files (Oracle object folders). Also includes flyway/utils
    # 2. Set as $DIRECTORIES variables
    # 3. Execute git_diff for those directories which compares the objects within these direcotries and the directories in GitHub
    # Example:
    # $SCHEMAS = ('AAPEN' 'GLOBAL' 'DISPORT')
    # $SCHEMA = AAPEN or GLOBAL or DISPORT
    # For AAPEN the output of the find command and the $DIRECTORIES variable should be something like this:
    #   AAPEN/FUNCTION
    #   AAPEN/PROCEDURE
    #   AAPEN/TYPE
    #   AAPEN/VIEW
    for SCHEMA in "${SCHEMAS[@]}";
    do 
        # [ find -type d ] - find directories in current path
        # [ egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW|flyway/utils" ] - extended grep with ignore word casing for a all the directoriees in the list. 
        # [ awk -F/ '{print $(NF-1)"/"$(NF)}' ] - cut the path to show only last 2 directories e.g. ./AAPEN/AAPEN/AAPEN/FUNCTION becomes AAPEN/FUNCTION
        # [ git_diff "${DIRECTORIES[@]}" ] - will be executed for the array of directories. 
        find -type d | egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW|flyway/utils" | awk -F/ '{print $(NF-1)"/"$(NF)}'
        DIRECTORIES=`find -type d | egrep -i "${SCHEMA}/FUNCTION|${SCHEMA}/PROCEDURE|${SCHEMA}/TYPE|${SCHEMA}/TYPE_BODY|${SCHEMA}/UNIT_TEST|${SCHEMA}/VIEW|flyway/utils" | awk -F/ '{print $(NF-1)"/"$(NF)}'`
        git_diff "${DIRECTORIES[@]}"
    done
}

# GIT DIFF - NON-REPEATABALE FILES
# This functions calls the git_diff function for any non-repeatable files/objects
git_diff_non_repeatable(){
    # Declare array variable $SCHEMAS and use the values parsed in by external variable $SCHEMAS
    # https://linuxhint.com/bash_declare_command/
    declare -a SCHEMAS="${SCHEMAS[@]}"
    CHANGED_FILES_TYPE="non-repeatable"    
    CHANGED_FILES_FILE=${NON_REPEATABLE_FILES_FILE}
    CHANGED_FILE_NAME="$(basename -- ${NON_REPEATABLE_FILES_FILE})"
    
    # For each scheam in the array of schemas:
    # 1. Find all directories for non-repeatable files (Oracle object folders). Also includes flyway/utils
    # 2. Set as $DIRECTORIES variables
    # 3. Execute git_diff for those directories which compares the objects within these direcotries and the directories in GitHub
    # Example:
    # $SCHEMAS = ('AAPEN' 'GLOBAL' 'DISPORT')
    # $SCHEMA = AAPEN or GLOBAL or DISPORT
    # For AAPEN the output of the find command and the $DIRECTORIES variable should be something like this:
    #   AAPEN/CONSTRAINT
    #   AAPEN/INDEX
    #   AAPEN/MATERIALIZED_VIEW
    #   AAPEN/PACKAGE
    #   AAPEN/PACKAGE_BODY
    #   AAPEN/SEQUENCE
    #   AAPEN/TABLE
    for SCHEMA in "${SCHEMAS[@]}";
    do
        # [ find -type d ] - find directories in current path
        # [ egrep -i "${SCHEMA}/CONSTRAINT|${SCHEMA}/INDEX|${SCHEMA}/MATERIALIZED_VIEW|${SCHEMA}/PACKAGE|${SCHEMA}/PACKAGE_BODY|${SCHEMA}/SEQUENCE${TABLE}" ] - extended grep with ignore word casing for a all the directoriees in the list.
        # [ awk -F/ '{print $(NF-1)"/"$(NF)}' ] - cut the path to show only last 2 directories e.g. ./AAPEN/AAPEN/AAPEN/FUNCTION becomes AAPEN/FUNCTION
        # [ git_diff "${DIRECTORIES[@]}" ] - will be executed for the array of directories. 
        find -type d | egrep -i "${SCHEMA}/CONSTRAINT|${SCHEMA}/INDEX|${SCHEMA}/MATERIALIZED_VIEW|${SCHEMA}/PACKAGE|${SCHEMA}/PACKAGE_BODY|${SCHEMA}/SEQUENCE|${SCHEMA}/TABLE" | awk -F/ '{print $(NF-1)"/"$(NF)}'
        DIRECTORIES=`find -type d | egrep -i "${SCHEMA}/CONSTRAINT|${SCHEMA}/INDEX|${SCHEMA}/MATERIALIZED_VIEW|${SCHEMA}/PACKAGE|${SCHEMA}/PACKAGE_BODY|${SCHEMA}/SEQUENCE|${SCHEMA}/TABLE" | awk -F/ '{print $(NF-1)"/"$(NF)}'`
        git_diff "${DIRECTORIES[@]}"
    done
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

# RENAME FILES - rename changed files (for commit purposes) and copy files to flyway/sql (for flyway deployments)
# This functions renames the changed files accordingly for both repeatable and non-repeatbale files. 
# This function is called by repeatable_changed_files_version and non_repeatable_changed_files_version functions
rename_files(){
    # If flyway/sql exists:
    #   1. Make direcotry for flyway/sql/${FILE_PATH} e.g. flyway/sql/AAPEN/AAPEN/AAPEN/VIEW    
    #   2. Copy the ${PWD}/${FILE} to ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME} e.g. AAPEN/AAPEN/AAPEN/TABLE/table.tbl is added as flyway/sql/AAPEN/AAPEN/AAPEN/TABLE/V2023.04.28.1113.1__AAPEN.TABLE.tbl
    # If NOT exists:
    #   1. Make direcotry for flyway/sql/${FILE_PATH} e.g. flyway/sql/AAPEN/AAPEN/AAPEN/VIEW
    #   2. Copy the ${PWD}/${FILE} to ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME} e.g. AAPEN/AAPEN/AAPEN/TABLE/table.tbl is added as flyway/sql/AAPEN/AAPEN/AAPEN/TABLE/V2023.04.28.1113.1__AAPEN.TABLE.tbl
    if [[ -d ${PWD}/flyway/sql ]]
    then
        echo -e "\n[INFO]: Renaming [$FILE] to [${FILE_PATH}/${NEW_FILE_NAME}] for flyway purposes"
        echo -e "[INFO]: Making directory [flyway/sql/${FILE_PATH}] and copying [${FILE}] for flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${FILE_PATH} && cp ${PWD}/${FILE} ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME}
    else
        echo -e "\n[INFO]: Renaming [$FILE] to [${FILE_PATH}/${NEW_FILE_NAME}] for flyway purposes."
        echo -e "[INFO]: Making directory [flyway/sql/${FILE_PATH}] and copying [${FILE}] for flyway purposes"
        mkdir -p ${PWD}/flyway/sql/${FILE_PATH} && cp ${PWD}/${FILE} ${PWD}/flyway/sql/${FILE_PATH}/${NEW_FILE_NAME}
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
    echo -e "\n[WARN]: flyway/sql exists. Was it accidentally commited?"
    echo "[INFO]: Removing [${PWD}/flyway/sql]."
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
    echo -e "[INFO]: Executing git diff between [${GITHUB_WORKSPACE}] and origin/main and creating [${REPEATABLE_FILE_NAME}].\n"
    git_diff_repeatable
    repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${REPEATABLE_FILES_FILE}]."
    rm -rf ${REPEATABLE_FILES_FILE}
elif [[ ! -f ${REPEATABLE_FILES_FILE} ]]
then
    # Git diff for repeatable files and update file versions
    echo -e "[INFO]: Executing git diff between [${GITHUB_WORKSPACE}] and origin/main and creating [${REPEATABLE_FILE_NAME}].\n"
    git_diff_repeatable
    repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${REPEATABLE_FILES_FILE}]."
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
    echo "[INFO]: Old [${NON_REPEATABLE_FILE_NAME}] present. Removing before proceeding with git diff."
    echo -e "\n[WARN]: [${NON_REPEATABLE_FILE_NAME}] is created dynamically and should not be committed to repo. Please investigate!"
    rm -rf ${NON_REPEATABLE_FILES_FILE}
   
    # Git diff for non repeatable files and update file versions
    echo -e "[INFO]: Executing git diff between [${GITHUB_WORKSPACE}] and origin/main and creating [${NON_REPEATABLE_FILE_NAME}].\n"
    git_diff_non_repeatable
    non_repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${NON_REPEATABLE_FILES_FILE}]."
    rm -rf ${NON_REPEATABLE_FILES_FILE}
elif [[ ! -f ${NON_REPEATABLE_FILES_FILE} ]]
then
    # Git diff for non repeatable files and update file versions
    echo -e "[INFO]: Executing git diff between [${GITHUB_WORKSPACE}] and origin/main and creating [${NON_REPEATABLE_FILE_NAME}].\n"    
    git_diff_non_repeatable
    non_repeatable_changed_files_version
    
    # Remove temp file and commit
    echo -e "\n[INFO]: Removing temp [${NON_REPEATABLE_FILES_FILE}]."
    rm -rf ${NON_REPEATABLE_FILES_FILE}
fi

update-placeholder "${PWD}/utils" "${COMMIT_ID_PLACEHOLDER}" "${COMMIT}"

# UTILS FILES
# Puts EDITION_CREATE, EDITION_DROP, EDITION_SET files into GITHUB_DEPLOY_USER
# This will then create new editions and set default edition in the deployment 
FILES=("EDITION_CREATE" "EDITION_DROP" "EDITION_SET")
SCHEMA=("GITHUB_DEPLOY_USER")
for FILE in "${FILES[@]}";
do
    utils_files "${FILE[@]}"
done

# EDITION SET
# Puts EDITION_SET_SESSION as a beforeMigrate.sql into each schema
# This will set the newly created editions as the edition to use for each schema deployment 
FILES=("EDITION_SET_SESSION")
SCHEMAS=("AAPEN" "DISPORT" "GLOBAL")
for SCHEMA in "${SCHEMAS[@]}";
do
    for FILE in "${FILES[@]}";
    do  
        utils_files "${FILE[@]}"
    done
done