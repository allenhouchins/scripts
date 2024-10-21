#!/bin/bash

# Configuration
OKTA_DOMAIN="https://your-okta-domain.okta.com"
API_TOKEN="your-okta-api-token"

# Function to fetch user information
get_user_info() {
  local username="$1"
  curl -s -X GET \
    -H "Authorization: SSWS $API_TOKEN" \
    -H "Accept: application/json" \
    "$OKTA_DOMAIN/api/v1/users/${username}"
}

# Function to create a plist file
create_plist() {
  local user_data="$1"
  local plist_filename="$2"

  # Extract relevant fields from the JSON response
  local name=$(echo "$user_data" | jq -r '.profile.firstName + " " + .profile.lastName')
  local email=$(echo "$user_data" | jq -r '.profile.email')
  local login=$(echo "$user_data" | jq -r '.profile.login')
  local department=$(echo "$user_data" | jq -r '.profile.department // ""')
  local title=$(echo "$user_data" | jq -r '.profile.title // ""')

  # Create a plist file
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
</dict>
</plist>
EOF
  echo "Plist file '$plist_filename' created successfully."
}

# Main script
read -p "Enter the Okta username or email: " username

# Fetch user info from Okta
user_info=$(get_user_info "$username")

# Check if the user was found
if echo "$user_info" | jq -e '.status' &>/dev/null; then
  plist_filename="$(echo "$user_info" | jq -r '.profile.login').plist"
  create_plist "$user_info" "$plist_filename"
else
  echo "User not found or an error occurred."
fi
