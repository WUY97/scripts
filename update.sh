#!/bin/bash

echo "Starting the process..."

# Use gh to fetch the repositories
REPOS=$(gh api orgs/svinfo6250/repos -X GET --paginate --field per_page=200)

# Extract SSH URLs and names for further checks
SSH_URLS=($(echo "$REPOS" | jq -r .[].ssh_url))
REPO_NAMES=($(echo "$REPOS" | jq -r .[].name))

# Check if any repositories were returned
if [ ${#SSH_URLS[@]} -eq 0 ]; then
    echo "No repositories found or error parsing JSON."
    exit 1
fi

# Outputting number of repositories found
echo "Found ${#SSH_URLS[@]} repositories. Starting the process..."

for idx in "${!SSH_URLS[@]}"; do
    REPO_URL="${SSH_URLS[$idx]}"
    REPO_NAME="${REPO_NAMES[$idx]}"

    # Check if repo folder exists
    if [ -d "$REPO_NAME" ]; then
        echo "Repository $REPO_NAME exists, updating..."
        cd "$REPO_NAME" || exit
        git checkout main
        git pull origin main
        cd ..
    else
        git clone "$REPO_URL"
    fi
done

echo "Process completed."