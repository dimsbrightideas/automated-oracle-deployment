#!/bin/bash

echo "[INFO]: AAPEN table flag: [${AAPEN_TABLES}]"
echo "[INFO]: DISPORT table flag: [${DISPORT_TABLES}]"
echo "[INFO]: GLOBAL table flag: [${GLOBAL_TABLES}"]

if [[ (${AAPEN_TABLES} = "true" || ${AAPEN_TABLES} = true) || (${DISPORT_TABLES} = "true" || ${DISPORT_TABLES} = true) || (${GLBOAL_TABLES} = "true" || ${GLOBAL_TABLES} = true) ]]; 
then
    echo -e "\n[INFO]: Table object detected for one or more of the schemas."
    echo "[INFO]: Additional approval required! Approval group has been notified with a request."
    echo "[INFO]: Flyway-Actions-DEV will not complete, until approved"

    echo -e "\n[INFO]: DEPLOYMENT_ENVIRONMENT will be set to [Development - Tables]"
    echo "DEPLOYMENT_ENVIRONMENT=Development - Tables" >> "$GITHUB_OUTPUT"
else
    echo -e "\n[INFO]: No table objects detected for any schemas."
    echo -e "\n[INFO]: DEPLOYMENT_ENVIRONMENT will be set to [Development]"

    echo "DEPLOYMENT_ENVIRONMENT=Development" >> "$GITHUB_OUTPUT"
fi