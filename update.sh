#!/bin/bash
set -x

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${GREEN}Starting the process...${RESET}"

# Use gh to fetch the repositories
REPOS=$(gh api orgs/svinfo6250/repos -X GET --paginate --field per_page=200)

# Extract SSH URLs and names for further checks
SSH_URLS=($(echo "$REPOS" | jq -r .[].ssh_url))
REPO_NAMES=($(echo "$REPOS" | jq -r .[].name))

# Check if any repositories were returned
if [ ${#SSH_URLS[@]} -eq 0 ]; then
    echo -e "${RED}No repositories found or error parsing JSON.${RESET}"
    exit 1
fi

# Outputting number of repositories found
echo -e "${GREEN}Found ${#SSH_URLS[@]} repositories. Starting the process...${RESET}"

for idx in "${!SSH_URLS[@]}"; do
    REPO_URL="${SSH_URLS[$idx]}"
    REPO_NAME="${REPO_NAMES[$idx]}"

    # Check if repo folder exists
    if [ -d "$REPO_NAME" ]; then
        echo -e "${YELLOW}Repository $REPO_NAME exists, updating...${RESET}"
        cd "$REPO_NAME" || exit
        git checkout main
        gtimeout 1m git pull origin main 2>&1
        if [ $? -eq 124 ]; then
            echo -e "${RED}Timeout occurred during git pull for $REPO_NAME. Resetting and retrying...${RESET}"
            
            # Reset the repo to the state of the remote
            git reset --hard origin/main
            
            # Retry git pull
            gtimeout 1m git pull origin main 2>&1
            if [ $? -eq 124 ]; then
                echo -e "${RED}Timeout occurred again during git pull for $REPO_NAME. Skipping this repo.${RESET}"
            fi
        fi
        cd ..
    else
        MAX_RETRIES=3
        RETRY_COUNT=0
        while (( RETRY_COUNT < MAX_RETRIES )); do
            gtimeout 10m git clone "$REPO_URL" 2>&1
            if [ $? -ne 124 ]; then
                break
            else
                echo -e "${RED}Timeout occurred during git clone for $REPO_NAME. Retrying... ($((RETRY_COUNT+1))/$MAX_RETRIES)${RESET}"
                rm -rf "$REPO_NAME"
                ((RETRY_COUNT++))
            fi
        done
        if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
            echo -e "${RED}Max retries reached for $REPO_NAME. Skipping...${RESET}"
        fi
    fi
done

echo -e "${GREEN}Process completed.${RESET}"