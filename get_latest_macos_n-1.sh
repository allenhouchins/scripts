#!/bin/sh

# Fetch the JSON data and extract the ProductVersion strings
versions=$(/usr/bin/curl -s "https://sofafeed.macadmins.io/v1/macos_data_feed.json" | \
/usr/bin/jq -r '.. | objects | select(has("ProductVersion")) | .ProductVersion')

# Find the two highest major versions
highest_two_majors=$(echo "$versions" | /usr/bin/cut -d '.' -f1 | /usr/bin/sort -Vr | /usr/bin/uniq | /usr/bin/head -n 2)

# Extract the highest version for each of the two highest major versions
for major in $highest_two_majors; do
  highest_version=$(echo "$versions" | /usr/bin/grep "^$major\." | /usr/bin/sort -Vr | /usr/bin/head -n 1)
  echo "$highest_version"
done