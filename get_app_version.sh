#!/bin/sh

# Get the app name or token as input from the user
APP_NAME="$1"

# Convert the contents of $1 to lowercase and replace spaces with dashes
token=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g')

# Define the temp file location
TMP_FILE="/tmp/cask.json"

# Download the JSON data to the temporary file
curl -s --compressed "https://formulae.brew.sh/api/cask.json" -o "$TMP_FILE"

# Use trap to ensure the temporary file is deleted when the script exits
trap 'rm -f "$TMP_FILE"' EXIT

# Validate JSON data using jq (with explicit error output redirected)
jq empty "$TMP_FILE" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Invalid JSON data. Aborting."
    exit 1
fi

# Use jq to extract the version based on the app name or token
VERSION=$(jq -r --arg token "$token" '.[] | select(.token == $token) | .version' "$TMP_FILE")

# Check if a version was found
if [ -n "$VERSION" ]; then
    echo "The latest version of $APP_NAME is $VERSION."
else
    echo "App $APP_NAME not found."
fi

# The temporary file will be automatically deleted here due to the trap

