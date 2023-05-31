#!/bin/bash

# FUNCTIONS
get_latest_artifacts(){
    # list all workflows for branch
    # list in json format
    # show url of json array and use head -1 to select latest
    # awk to print last value of URL (ID)
    
    PIPELINE_NAME='CD - Development'
    PIPELINE_RUN_ID=`gh run list --workflow "${PIPELINE_NAME}" --json name,displayTitle,workflowName,url,headBranch,startedAt,url  --jq '.[].url' | head -1 | awk -F / '{print $NF}'`
    BRANCH=`gh run list --workflow "${PIPELINE_NAME}" --json name,displayTitle,workflowName,url,headBranch,startedAt,url  --jq '.[].headBranch' | head -1 | awk -F / '{print $NF}'`
    # View pipeline with artifacts
    echo "[INFO]: Artifacts run ID: [$PIPELINE_RUN_ID]"
    echo "[INFO]: Artifacts branch name: [$BRANCH]"
    echo -e "[INFO]: Checking artifacts for branch [$BRANCH] in [$PIPELINE_NAME]\n"
    gh run view "${PIPELINE_RUN_ID}"
}

download_artifacts() {
    # Download artifacts
    echo "[INFO]: Downloading artifacts to flyway/sql..."
    gh run download "${PIPELINE_RUN_ID}" --dir flyway/sql
    ls -ltr "${PWD}/flyway/sql/sql-files"
}

# check if artifacts exists and delete if yes
if [ -d "${PWD}/flyway/sql" ]
then
    rm -rf ${PWD}/flyway/sql
fi

# SCRIPT STARTS HERE
if get_latest_artifacts;
then
    echo -e "\n[INFO]: Artifacts found for branch [$BRANCH] in [$PIPELINE_NAME]."
    download_artifacts
else
    echo -e "\n[WARN]: No Artifacts found! Deployment may fail."
fi
