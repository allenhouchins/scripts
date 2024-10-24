#!/bin/bash
# This script runs one last recon and then removes the jamf binary. This should be distributed by any means other than Jamf Pro and must be run as root.

# Identify the location of the jamf binary for the jamf_binary variable.
CheckBinary (){
    # Identify location of jamf binary.
    jamf_binary=`/usr/bin/which jamf`

    if [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ ! -e "/usr/local/bin/jamf" ]]; then
        jamf_binary="/usr/sbin/jamf"
    elif [[ "$jamf_binary" == "" ]] && [[ ! -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
        jamf_binary="/usr/local/bin/jamf"
    elif [[ "$jamf_binary" == "" ]] && [[ -e "/usr/sbin/jamf" ]] && [[ -e "/usr/local/bin/jamf" ]]; then
        jamf_binary="/usr/local/bin/jamf"
    else
        echo "Jamf binary not found. Exiting..."
        exit 0
    fi

    echo "The jamf binary is installed at $jamf_binary"
}

# Update the computer inventory
RunRecon (){
    $jamf_binary recon
}

CheckBinary
RunRecon

# Remove framework
$jamf_binary removeFramework
echo "Jamf has been removed from this Mac!"