#!/usr/bin/env bash

# Exit on error
set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Homebrew API URL
API_URL="https://formulae.brew.sh/api/cask.json"

echo -e "${BLUE}Fetching cask data from Homebrew API...${NC}"

# Fetch and process cask data
if ! cask_data=$(curl -s "$API_URL"); then
    echo -e "${RED}Error: Failed to fetch data from Homebrew API${NC}"
    exit 1
fi

# Create temporary file for JSON output
temp_file=$(mktemp)
echo "[" > "$temp_file"
first_entry=true

# Print header for table
printf "%-35s %-20s %-60s\n" "NAME" "VERSION" "URL"
printf "%$(tput cols)s" | tr ' ' '-'
echo

# Get all pkg casks data first
pkg_casks=$(echo "$cask_data" | jq -c '.[] | select(.url | endswith(".pkg"))')

# Initialize counter
count=0

# Process each matching cask
while IFS= read -r cask; do
    if [ -n "$cask" ]; then
        name=$(echo "$cask" | jq -r '.token')
        version=$(echo "$cask" | jq -r '.version')
        url=$(echo "$cask" | jq -r '.url')
        
        # Print table row
        printf "%-35s %-20s %-60s\n" "$name" "$version" "$url"
        
        # Add to JSON output
        if [ "$first_entry" = true ]; then
            first_entry=false
        else
            echo "," >> "$temp_file"
        fi
        
        # Create JSON entry
        cat << EOF >> "$temp_file"
    {
        "name": "$name",
        "version": "$version",
        "url": "$url"
    }
EOF
        
        ((count++))
    fi
done <<< "$pkg_casks"

# Close JSON array
echo "]" >> "$temp_file"

# Format JSON file
jq '.' "$temp_file" > pkg_casks.json
rm "$temp_file"

echo
echo -e "${GREEN}Found $count casks with .pkg download URLs${NC}"
echo "Detailed results have been saved to pkg_casks.json"
