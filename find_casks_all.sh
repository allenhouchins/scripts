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
printf "%-35s %-20s %-15s %-60s\n" "NAME" "VERSION" "TYPE" "URL"
printf "%$(tput cols)s" | tr ' ' '-'
echo

# Get all casks
all_casks=$(echo "$cask_data" | jq -c '.[]')

# Initialize counter
count=0

# Process each cask
while IFS= read -r cask; do
    if [ -n "$cask" ]; then
        name=$(echo "$cask" | jq -r '.token')
        version=$(echo "$cask" | jq -r '.version')
        url=$(echo "$cask" | jq -r '.url')
        
        # Determine file type from URL
        if [[ "$url" =~ \.(pkg|dmg|zip|app|tar\.gz|tgz|7z|rar)$ ]]; then
            type="${BASH_REMATCH[1]}"
            # Handle special case for tar.gz
            if [[ "$type" == "gz" ]]; then
                type="tar.gz"
            fi
        else
            type="other"
        fi
        
        # Print table row
        printf "%-35s %-20s %-15s %-60s\n" "$name" "$version" "$type" "$url"
        
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
        "type": "$type",
        "url": "$url"
    }
EOF
        
        ((count++))
    fi
done <<< "$all_casks"

# Close JSON array
echo "]" >> "$temp_file"

# Format JSON file
jq '.' "$temp_file" > cask_urls.json
rm "$temp_file"

echo
echo -e "${GREEN}Found $count casks total${NC}"
echo "Detailed results have been saved to cask_urls.json"
