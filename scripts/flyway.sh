#!/bin/bash

if ${DEBUG} || ${DEBUG} = true;
then
    # Enable debug (-X at end of flyway command)
    echo -e "[WARN]: Debug flag is set to [true]. Executing flyway commands in debug mode.\n"
    DEBUG="-X"
else 
    echo -e "[INFO]: Debug flag is set to [false]. Executing flyway commands as normal.\n"
    DEBUG=""
fi

if [[ (${TABLES} = "true" || ${TABLES} = true) && (${ENVIRONMENT} = "DEVELOPMENT") ]];
then
    echo -e "[WARN]: Tables flag is set to [true] for [${SCHEMA}]. Deploying .tbl objects!"
fi

FLYWAY_CONF=${FLYWAY_CONF_PATH}/flyway.conf

# flyway functions for makefile
function flyway_baseline(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 baseline ${DEBUG}
}

function flyway_info(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 info ${DEBUG}
}

function flyway_validate(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 validate ${DEBUG}
}

function flyway_repair(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 repair ${DEBUG}
}

function flyway_migrate(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 migrate ${DEBUG}
}

function flyway_clean(){
    flyway -configFiles=${FLYWAY_CONF} -outOfOrder=true -connectRetries=60 clean ${DEBUG}
}

function flyway_deploy(){
    flyway_info

    # Flyway validate, if error trigger repair
    if flyway_validate;
    then
        echo "[INFO]: Flyway validate complete."
        echo "[INFO]: Flyway migrate started."        
        flyway_migrate
    else
        echo "[WARN]: Flyway validate failed!"
        echo "[INFO]: Execution flyway repair."
        flyway_repair
        flyway_migrate
    fi
}

"$@"
