#!/bin/bash

# TO DO #
# - Ensure there are no duplicate files with different versions
# - If there are duplicate files only update version of the latest in the commit
# - This will force the deployment to only run a migrate for the latest file.
# - Include EBR into deployment

# Check if flyway/sql exists and remove before creating.
# Flyway/sql should not exist in an initial run because it should not be committed.
if [[ -d ${PWD}/flyway/sql ]]
then
    echo -e "\n[WARN]: /flyway/sql exists. Was it accidentally commited?"
    echo "[INFO] Removing [${PWD}/flyway/sql]."
    rm -rf ${PWD}/flyway/sql
fi

# UTILS FILES - Logic for versioning of files
utils_files(){
FILE=("$@")
    if [[ -d ${PWD}/flyway/sql/${SCHEMA} ]]
    then
        echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}] flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/${FILE}/beforeMigrate.sql
    else     
        echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}] flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/${FILE}/beforeMigrate.sql
    fi
}

utils_files_actualization() {
    FILE="$1"
    if [[ "$FILE" = "EDITION_ACTUALIZATION_02_POST" ]]
    then
    echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}]/afterMigrate.sql flyway purposes."
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/EDITION_ACTUALIZATION/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/EDITION_ACTUALIZATION/${FILE}/afterMigrate.sql
    else
    echo -e "\n[INFO]: Copying [${FILE}.sql] into [${PWD}/flyway/sql/${SCHEMA}/${FILE}]/beforeMigrate.sql flyway purposes."   
        mkdir -p ${PWD}/flyway/sql/${SCHEMA}/EDITION_ACTUALIZATION/${FILE} && cp ${PWD}/utils/${FILE}.sql ${PWD}/flyway/sql/${SCHEMA}/EDITION_ACTUALIZATION/${FILE}/beforeMigrate.sql
    fi
}


# UTILS FILES
# EDITION_DROP handles the compile and dropping of any unused editions.
FILES=("EDITION_DROP")
SCHEMA=("GITHUB_DEPLOY_USER")
for FILE in "${FILES[@]}";
do
    utils_files "${FILE[@]}"
done

#EDITION_ACTUALIZATION handles copying of objects from previous editions to latest edition
FILES=("EDITION_ACTUALIZATION_01_PRE" "EDITION_ACTUALIZATION_02_POST" )
SCHEMAS=("AAPEN" "DISPORT" "GLOBAL")
for SCHEMA in "${SCHEMAS[@]}";
do
    for FILE in "${FILES[@]}";
    do  
        utils_files_actualization "${FILE[@]}"
    done
done
