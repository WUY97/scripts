#!/bin/bash
set -x

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

DATE=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="repo_branches_$DATE.txt"

echo -e "${GREEN}Starting the process...${RESET}"

# Prompt user for desired branch name
read -p "Please enter the name of the branch you want to pull: " DESIRED_BRANCH

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

    # If repo folder exists, remove it to ensure fresh clone
    if [ -d "$REPO_NAME" ]; then
        rm -rf "$REPO_NAME"
    fi

    # Clone the repository
    gtimeout 10m git clone "$REPO_URL" 2>&1
    cd "$REPO_NAME" || exit

    # Fetch all branches from the remote
    git fetch

    # Check if the desired branch exists in the remote
    if git show-ref --verify --quiet "refs/remotes/origin/$DESIRED_BRANCH"; then
        echo -e "${GREEN}Branch $DESIRED_BRANCH exists in $REPO_NAME. Checking it out...${RESET}"
        git checkout -b "$DESIRED_BRANCH" "origin/$DESIRED_BRANCH"
        git pull origin "$DESIRED_BRANCH"
    else
        echo -e "${YELLOW}Branch $DESIRED_BRANCH does not exist in $REPO_NAME. Skipping...${RESET}"
    fi

    CURRENT_BRANCH=$(git symbolic-ref --short HEAD)

    cd ..

    # Record the repo and its current branch
    echo "$REPO_NAME is on branch $CURRENT_BRANCH" >> $OUTPUT_FILE

done

echo -e "${GREEN}Process completed.${RESET}"