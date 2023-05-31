#!/bin/bash

# Function: close_pull_request()
# Closes the specified pull request on GitHub using the API.
check_pull_request() {
    PULL_REQUEST=("$@")
    gh pr view ${PULL_REQUEST} --json title,state,body,url,author,number,labels
}

add_labels(){
    LABEL=("$@")
    gh pr edit ${URL} --add-label ${LABEL}
}

remove_labels(){
    LABEL=("$@")
    gh pr edit ${URL} --remove-label ${LABEL}
}

# neeed for merged pr. gets last merged one
get_latest_merged_pr() {
    gh api --method GET -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/pulls?state=closed | jq '[.[] | {title: .title, closed_at: .closed_at, merged_at: .merged_at, url: .url, number: .number, labels: .labels[].name, state: .state}] | sort_by(.merged_at) | last'
}


# if run in DEVELOPMENT environment add label READY-FOR-TEST 
if [[ ${ENVIRONMENT} == "DEVELOPMENT" || ${ENVIRONMENT} == "TEST" ]]; 
then
    # check if pr exists and is open for $BRANCH_NAME
    STATE=$(check_pull_request "${BRANCH_NAME[@]}" | jq -r '.state')

    # if pr is open handle DEV and TEST
    if [[ ${STATE} == "OPEN" ]]; 
    then
        URL=$(check_pull_request "${BRANCH_NAME[@]}" | jq -r '.url')
        LABELS=$(check_pull_request "${BRANCH_NAME[@]}" | jq -r '.labels')
        TITLE=$(check_pull_request "${BRANCH_NAME[@]}" | jq -r '.title')

        echo -e "\n[INFO]: Open pull request for ${TITLE} is found."
        
        # use branch name from GitHub events
        check_pull_request "${BRANCH_NAME[@]}"

        # DEVELOPMENT
        # if run in DEVELOPMENT environment add label READY-FOR-TEST
        if [[ ${ENVIRONMENT} == "DEVELOPMENT" ]]; 
        then

            ADD_READY_FOR_ENVIRONMENT="READY-FOR-TEST"
            add_labels "${ADD_READY_FOR_ENVIRONMENT[@]}"
    
            # If table flag is on then add table label to pr
            if [[ (${AAPEN_TABLES} = "true" || ${AAPEN_TABLES} = true) || (${DISPORT_TABLES} = "true" || ${DISPORT_TABLES} = true) || (${GLOBAL_TABLES} = "true" || ${GLOBAL_TABLES} = true) ]];
            then
                echo -e "\n[INFO]: AAPEN table flag: [${AAPEN_TABLES}]"
                echo "[INFO]: DISPORT table flag: [${DISPORT_TABLES}]"
                echo "[INFO]: GLOBAL table flag: [${GLOBAL_TABLES}"]
                echo -e "\n[INFO]: Tables flag is set to [true]. Updating PR with TABLE-DEPLOYMENT label.\n"
                
                TABLE_DEPLOYMENT="TABLE-DEPLOYMENT"
                add_labels "${TABLE_DEPLOYMENT[@]}"          
            fi

        # TEST
        # if run in TEST environment add label READY-FOR-PRODUCTION and remove DEVELOPMENT label 
        elif [[ ${ENVIRONMENT} == "TEST" ]]; 
        then
            ADD_READY_FOR_ENVIRONMENT="READY-FOR-PRODUCTION"
            REMOVE_READY_FOR_ENVIRONMENT="READY-FOR-TEST"

            remove_labels "${REMOVE_READY_FOR_ENVIRONMENT[@]}"
            add_labels "${ENVIRONMENT[@]}"
            add_labels "${ADD_READY_FOR_ENVIRONMENT[@]}"
        fi
    fi
     
# if pr is closed (PROD) and PROD environment
elif [[ ${ENVIRONMENT} == "PRODUCTION" ]]; 
then
    get_latest_merged_pr

    # url here is a number becuase url doesnt work for merged pr some reason e.g. 314
    URL=$(get_latest_merged_pr | jq -r '.number')
    REMOVE_READY_FOR_ENVIRONMENT="READY-FOR-PRODUCTION"

    # use pr number from $URL
    check_pull_request "${URL[@]}" 
    remove_labels "${REMOVE_READY_FOR_ENVIRONMENT[@]}"      
    add_labels "${ENVIRONMENT[@]}"
else
    echo -e "\n[WARN]: No pull request for ${TITLE} found."
fi

            