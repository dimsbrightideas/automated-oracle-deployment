#!/bin/bash

# Function: list_latest_workflow()
# Lists latests CD - Test workflow based on StartedAt date
list_latest_workflow() {
    gh run list --json headBranch,displayTitle,url,workflowName,startedAt,conclusion,databaseId,number | jq '[.[] | select(.workflowName=="CD - Test") | {workflowName: .workflowName, headBranch: .headBranch, databaseId: .databaseId, url: .url, startedAt: .startedAt, conclusion: .conclusion, number: .number}] | sort_by(.startedAt) | last'
}

get_workflow() {
    gh api --method GET -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$DATABASE_ID 
}

delete_workflow() {
    gh api --method DELETE -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" repos/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions/runs/$DATABASE_ID 
}

# Workflow name: CD - DEV, CD - TEST, CD - PROD
WORKFLOW_NAME=$(list_latest_workflow | jq -r '.workflowName')
# Workflow run id: 4742056895
DATABASE_ID=$(list_latest_workflow | jq -r '.databaseId')
# Workflow number - 123
WORKFLOW_NUMBER=$(list_latest_workflow | jq -r '.number')
# Workflow url - https://api.github.com/repos/frasers-group/te-oracle-devops-poc/actions/runs/4786356689
URL=$(get_workflow | jq -r '.url')
# Pull request number associated with worflow - 123
WORKFLOW_PR_NUMBER=$(get_workflow | jq -r '.pull_requests[].number')

list_latest_workflow

# if workflow run includes skipped, match branch condition and worflowName is 'CD - TEST' then remove
if [[ ${PR_NUMBER} == ${WORKFLOW_PR_NUMBER}  ]]; then

    echo -e "\n[INFO]: Workflow [$URL] GET.\n"
    get_workflow
    
    # may require a PAT because GH_TOKEN seems to lack read/write Worfklow permissions
    echo -e "\nINFO]: Deleting workflow [$WORKFLOW_NAME#$WORKFLOW_NUMBER]" 
    echo -e "\n[INFO]: Workflow [$URL] DELETE.\n"
    delete_workflow
fi 

