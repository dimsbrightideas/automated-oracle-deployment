#!/bin/bash

# Function: close_pull_request()
# Closes the specified pull request on GitHub using the API.
check_pull_request() {
    gh pr view ${GITHUB_REF_NAME} --json title,state,body,url,author,number,labels
}

#Function: close_pull_request
# Obtain the URL of the pull request associated with the current branch using check_pull_request().
# Close the pull request using the gh pr close command.
close_pull_request() {
    URL=$(check_pull_request | jq -r '.url')
    echo -e "\n[INFO]: Closing pull request for [${GITHUB_REF_NAME}]."
    gh pr close ${URL}
}

#Function: keyword_scanning
#scans a directory recursively for files containing keywords defined in the variable KEYWORDS
keyword_scanning() {
    echo -e "\n[INFO]: Scanning started for ["$1"]."
    ROOT_DIR="$1"
    
    # List of keywords to search for
    KEYWORDS=("DROP\s*TABLE" "TRUNCATE\s*TABLE" "DROP\s*FROM")
    # Loop through all files and subfolders in the root directory
    if [ ! -d "$ROOT_DIR" ]; then
        echo "Directory $ROOT_DIR not found. Skipping schema ${SCHEMA}..."
        return
    fi

    while IFS= read -r -d '' file; do
        # Check if the file contains any of the keywords
        for keyword in "${KEYWORDS[@]}"; do
            #-iwz "-i" case-insensitive search
            # w- match only whole words
            # Z - input file as null-separated,useful for dealing with files that contain special characters or spaces in their names
            # searches for text patterns in files.
            if grep -iwz "$keyword" "$file" >/dev/null; then
                # Remove \s+ and \s* from the keyword and replace with a space
                # \s+ matches one or more consecutive whitespace characters
                # \s\* matches zero or more whitespace characters
                # / / matches two consecutive spaces.
                # g - substitution globally
                keyword=$(echo "$keyword" | sed -r 's/\\s+|\\s\*|  / /g')
                #$(echo $file | sed "s|^.*${SCHEMA}/||") -  output the file path with the ${SCHEMA} directory and everything before it removed.
                echo "Keyword '$keyword' found in file '${SCHEMA}/$(echo $file | sed "s|^.*${SCHEMA}/||")'" >> "$OUTPUT_FILE"
            fi
        done
        #-type f tells find to only return regular files (i.e., not directories or other types of files).
    done < <(find "$ROOT_DIR" -type f -print0)
}

#Function: create_pull_request
#creates a pull request on GitHub for a specific branch, and if the scanning is required, it calls the create_pull_request_with_scanning function
create_pull_request() {

    if ${SCANNING_REQUIRED} || ${SCANNING_REQUIRED} = true; then
        create_pull_request_with_scanning
    else
        echo -e "\n[INFO]: Creating pull request for [${GITHUB_REF_NAME}]."
        gh pr create --title "[${GITHUB_REF_NAME}]" --body "Updates all changed sql file versions" --label ${ENVIRONMENT}
    fi
}

# Function: create_pull_request_with_scanning
# Performs a keyword scanning for sensitive information and creates a pull request with approver if keywords are found; 
# otherwise, creates a pull request without comment.
create_pull_request_with_scanning() {

    # Dropping file
    if [ -f "${OUTPUT_FILE}" ]; then
        rm "${OUTPUT_FILE}"
        echo "File ${OUTPUT_FILE} deleted"
    fi

    SCHEMAS=("AAPEN" "DISPORT" "GLOBAL")
    for SCHEMA in "${SCHEMAS[@]}"; do
        keyword_scanning "${PWD}/flyway/sql/${SCHEMA}"
    done
    if check_file_exists "${OUTPUT_FILE}"; then
        echo -e "\n[INFO]: Sensitive keywords found"
        create_pull_request_with_approver
    else
        echo -e "\n[INFO]: Creating pull request for [${GITHUB_REF_NAME}]."
        gh pr create --title "[${GITHUB_REF_NAME}]" --body "Updates all changed sql file versions" --label ${ENVIRONMENT}
    fi
}

# Function: create_pull_request_with_approver
# creates a pull request for the specified branch, including an approver as a reviewer if specified.
create_pull_request_with_approver() {
    echo -e "\n[INFO]: Creating pull request for [${GITHUB_REF_NAME}] with approver."
    gh pr create --title "[${GITHUB_REF_NAME}]" --body "Updates all changed sql file versions" --reviewer ${REVIEWER} --label ${ENVIRONMENT}
    create_pull_request_comment
}

# Function: create_pull_request_comment
# creates a comment on the pull request
create_pull_request_comment() {
    echo -e "\n[INFO]: adding comment for pull request [${GITHUB_REF_NAME}]."
    gh pr review --comment -b "$(cat ${PWD}/${OUTPUT_FILE})"
    #dropping file after posting comment
    if [ -f "${OUTPUT_FILE}" ]; then
        rm "${OUTPUT_FILE}"
        echo "File ${OUTPUT_FILE} deleted"
    fi
}

#Function: check_file_exists
#checks for file exists
check_file_exists() {
    FILE_PATH="$1"
    if [ ! -f "$FILE_PATH" ]; then
        echo "File $FILE_PATH does not exist."
        return 1
    else
        echo "File $FILE_PATH exist."
        return 0
    fi
}

#clearing the contnents of file
STATE=$(check_pull_request | jq -r '.state')

if [[ $STATE == "OPEN" ]]; then
    echo -e "\n[INFO]: Pull request for [${GITHUB_REF_NAME}] already exists.\n"
    check_pull_request
    close_pull_request
    create_pull_request
else
    create_pull_request
fi
