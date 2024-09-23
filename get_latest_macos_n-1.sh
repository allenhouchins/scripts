#!/bin/sh

# Fetch the JSON data and extract the ProductVersion strings
versions=$(curl -s "https://sofafeed.macadmins.io/v1/macos_data_feed.json" | \
jq -r '.. | objects | select(has("ProductVersion")) | .ProductVersion')

# Find the two highest major versions
highest_two_majors=$(echo "$versions" | cut -d '.' -f1 | sort -Vr | uniq | head -n 2)

# Initialize an array to store the highest versions
highest_versions=()

# Extract the highest version for each of the two highest major versions
for major in $highest_two_majors; do
  highest_version=$(echo "$versions" | grep "^$major\." | sort -Vr | head -n 1)
  highest_versions+=("$highest_version")
  echo "$highest_version"
done