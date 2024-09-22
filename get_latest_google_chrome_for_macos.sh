#!/bin/sh

# URL to the latest.json file
url="https://raw.githubusercontent.com/berstend/chrome-versions/master/data/stable/mac/version/latest.json"

# Fetch the JSON data and extract the version field
latest_chrome_version=$(curl -s "$url" | jq -r '.version')

# Output the version
echo "Chrome stable version: "$latest_chrome_version""


# Write updated Google Chrome policy
echo "SELECT 1 FROM apps WHERE name = "Google Chrome.app" AND version_compare(bundle_short_version, '"$latest_chrome_version"') >= 0;"