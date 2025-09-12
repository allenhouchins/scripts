#!/bin/bash

# FileVault Key Rotation Script
# Purpose: Rotate FileVault recovery key using Netflix Escrow-Buddy
# Requirements: Must run as root
# Usage: sudo ./rotate-filevault-key.sh

# Configuration
SCRIPT_NAME="FileVault Key Rotator"
LOG_FILE="/var/log/filevault-key-rotation.log"
PLIST_PATH="/Library/Preferences/com.netflix.Escrow-Buddy.plist"
PLIST_DOMAIN="com.netflix.Escrow-Buddy"
KEY_NAME="GenerateNewKey"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages with timestamp
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_status "$RED" "❌ Error: This script must be run as root"
        print_status "$YELLOW" "   Usage: sudo $0"
        exit 1
    fi
}

# Function to check if Escrow-Buddy is installed
check_escrow_buddy() {
    if [ ! -f "$PLIST_PATH" ]; then
        print_status "$RED" "❌ Error: Escrow-Buddy not found"
        print_status "$YELLOW" "   Expected location: $PLIST_PATH"
        print_status "$YELLOW" "   Please ensure Netflix Escrow-Buddy is installed"
        log_message "ERROR: Escrow-Buddy plist not found at $PLIST_PATH"
        exit 1
    fi
    
    # Check if the plist is readable
    if ! plutil -p "$PLIST_PATH" >/dev/null 2>&1; then
        print_status "$RED" "❌ Error: Cannot read Escrow-Buddy plist"
        print_status "$YELLOW" "   File may be corrupted or inaccessible"
        log_message "ERROR: Cannot read plist at $PLIST_PATH"
        exit 1
    fi
}

# Function to backup current plist
backup_plist() {
    local backup_path="${PLIST_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$PLIST_PATH" "$backup_path" 2>/dev/null; then
        print_status "$BLUE" "📋 Backup created: $backup_path"
        log_message "Backup created: $backup_path"
    else
        print_status "$YELLOW" "⚠️  Warning: Could not create backup"
        log_message "WARNING: Could not create backup of $PLIST_PATH"
    fi
}

# Function to set the GenerateNewKey flag
set_generate_key_flag() {
    print_status "$BLUE" "🔄 Setting GenerateNewKey flag..."
    
    if defaults write "$PLIST_DOMAIN" "$KEY_NAME" -bool true; then
        print_status "$GREEN" "✅ GenerateNewKey flag set successfully"
        log_message "SUCCESS: GenerateNewKey flag set to true"
        return 0
    else
        print_status "$RED" "❌ Failed to set GenerateNewKey flag"
        log_message "ERROR: Failed to set GenerateNewKey flag"
        return 1
    fi
}

# Function to verify the setting was applied
verify_setting() {
    print_status "$BLUE" "🔍 Verifying setting..."
    
    local current_value
    current_value=$(defaults read "$PLIST_DOMAIN" "$KEY_NAME" 2>/dev/null)
    
    if [ "$current_value" = "1" ] || [ "$current_value" = "true" ]; then
        print_status "$GREEN" "✅ Verification successful: GenerateNewKey = $current_value"
        log_message "SUCCESS: Verification confirmed GenerateNewKey = $current_value"
        return 0
    else
        print_status "$RED" "❌ Verification failed: GenerateNewKey = $current_value"
        log_message "ERROR: Verification failed - GenerateNewKey = $current_value"
        return 1
    fi
}

# Function to show next steps
show_next_steps() {
    echo ""
    print_status "$YELLOW" "📋 Next Steps Required:"
    echo ""
    print_status "$BLUE" "   1. Log out of your current session"
    print_status "$BLUE" "   2. Log back in"
    print_status "$BLUE" "   3. The new FileVault recovery key will be generated automatically"
    echo ""
    print_status "$YELLOW" "💡 Note: The key generation happens during the login process"
    print_status "$YELLOW" "   You may see a brief delay during login while the key is generated"
    echo ""
}

# Function to show current status
show_status() {
    print_status "$BLUE" "📊 Current Status:"
    echo ""
    
    # Check if plist exists
    if [ -f "$PLIST_PATH" ]; then
        print_status "$GREEN" "   ✅ Escrow-Buddy: Installed"
        
        # Show current GenerateNewKey value
        local current_value
        current_value=$(defaults read "$PLIST_DOMAIN" "$KEY_NAME" 2>/dev/null)
        if [ -n "$current_value" ]; then
            print_status "$GREEN" "   ✅ GenerateNewKey: $current_value"
        else
            print_status "$YELLOW" "   ⚠️  GenerateNewKey: Not set"
        fi
    else
        print_status "$RED" "   ❌ Escrow-Buddy: Not installed"
    fi
    
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --status    Show current FileVault key rotation status"
    echo "  --help      Show this help message"
    echo ""
    echo "Without options, script will rotate the FileVault key."
    echo ""
    echo "Requirements:"
    echo "  - Must run as root (use sudo)"
    echo "  - Netflix Escrow-Buddy must be installed"
    echo "  - User must logout/login after running for key generation"
}

# Main execution
main() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE" 2>/dev/null || {
        print_status "$YELLOW" "⚠️  Warning: Could not create log file at $LOG_FILE"
        print_status "$YELLOW" "   Logging will be disabled"
    }
    
    log_message "=== FileVault Key Rotation Script Started ==="
    
    # Show header
    echo ""
    print_status "$BLUE" "🔐 $SCRIPT_NAME"
    print_status "$BLUE" "=================================="
    echo ""
    
    # Check if running as root
    check_root
    
    # Check if Escrow-Buddy is installed
    check_escrow_buddy
    
    # Show current status
    show_status
    
    # Create backup
    backup_plist
    
    # Set the GenerateNewKey flag
    if set_generate_key_flag; then
        # Verify the setting
        if verify_setting; then
            echo ""
            print_status "$GREEN" "🎉 FileVault key rotation initiated successfully!"
            log_message "SUCCESS: FileVault key rotation completed successfully"
            
            # Show next steps
            show_next_steps
        else
            print_status "$RED" "❌ Key rotation failed during verification"
            log_message "ERROR: Key rotation failed during verification"
            exit 1
        fi
    else
        print_status "$RED" "❌ Key rotation failed"
        log_message "ERROR: Key rotation failed"
        exit 1
    fi
    
    log_message "=== FileVault Key Rotation Script Completed ==="
    echo ""
}

# Handle command line arguments
case "${1:-}" in
    --status)
        check_root
        show_status
        exit 0
        ;;
    --help)
        show_usage
        exit 0
        ;;
    "")
        # No arguments - run main function
        main
        ;;
    *)
        print_status "$RED" "Error: Unknown option '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac
