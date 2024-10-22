#!/bin/bash

# Configuration
OKTA_DOMAIN="https://okta-dev-09740072-admin.okta.com"
API_TOKEN="00WOmzN3giooFU5N_HROJrtg3odOAFZYm29rKkaI11"
USER_ID="00ukjcffn4usjTCsF5d7"

# Function to fetch user information
get_user_info() {
  local username="$1"
  curl -s -L "$OKTA_DOMAIN/api/v1/users/$username" -H "Authorization: SSWS $API_TOKEN" -H "Accept: application/json"
}

# Function to create a plist file
create_plist() {
  local user_data="$1"
  local plist_filename="$2"

  # Extract relevant fields from the JSON response
  local name=$(echo "$user_data" | jq -r '.profile.displayName // (.profile.firstName + " " + .profile.lastName)')
  local email=$(echo "$user_data" | jq -r '.profile.email')
  local login=$(echo "$user_data" | jq -r '.profile.login')
  local department=$(echo "$user_data" | jq -r '.profile.department // ""')
  local title=$(echo "$user_data" | jq -r '.profile.title // ""')
  local mobilePhone=$(echo "$user_data" | jq -r '.profile.mobilePhone // ""')
  local city=$(echo "$user_data" | jq -r '.profile.city // ""')
  local state=$(echo "$user_data" | jq -r '.profile.state // ""')
  local zipCode=$(echo "$user_data" | jq -r '.profile.zipCode // ""')

  # Create a plist file with the extracted data
  cat <<EOF > "$plist_filename"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Name</key>
    <string>$name</string>
    <key>Email</key>
    <string>$email</string>
    <key>Login</key>
    <string>$login</string>
    <key>Department</key>
    <string>$department</string>
    <key>Title</key>
    <string>$title</string>
    <key>MobilePhone</key>
    <string>$mobilePhone</string>
    <key>City</key>
    <string>$city</string>
    <key>State</key>
    <string>$state</string>
    <key>ZipCode</key>
    <string>$zipCode</string>
</dict>
</plist>
EOF
  echo "Plist file '$plist_filename' created successfully."
}

# Main script
read -p "Enter Okta ID: " username

# Fetch user info from Okta
user_info=$(get_user_info "$username")

# Check if the user was found and generate plist
if echo "$user_info" | jq -e '.id' &>/dev/null; then
  plist_filename="$(echo "$user_info" | jq -r '.profile.login').plist"
  create_plist "$user_info" "$plist_filename"
else
  echo "User not found or an error occurred."
fi
