#!/bin/sh

# URL to the latest.json file
url="https://raw.githubusercontent.com/berstend/chrome-versions/master/data/stable/mac/version/latest.json"

# Fetch the JSON data and extract the version field
version=$(curl -s "$url" | jq -r '.version')

# Output the version
echo "Chrome stable version: $version"
