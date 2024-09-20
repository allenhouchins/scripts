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
done

# Construct the SQL query string with the highest versions
sql_query="SELECT 1 FROM os_version WHERE version >= '${highest_versions[0]}' OR version >= '${highest_versions[1]}';"

# Path to the YAML file
yml_file="../lib/operating-system-up-to-date-macos.yml"

# Use sed to replace the line that starts with 'query:' with the new SQL query
sed -i.bak "s|^query:.*|query: \"$sql_query\"|" "$yml_file"

# Output a success message
echo "The query in the YAML file has been updated successfully."
