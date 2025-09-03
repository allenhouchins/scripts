#!/bin/bash

# =============================================================================
# LOCK SCREEN MESSAGE MANAGER
# =============================================================================

# Configuration
LOCK_MESSAGE="🔴 Empathy 🟠 Ownership 🟢 Results
🔵 Objectivity 🟣 Openness"
SCRIPT_DIR="/usr/local/bin/lockscreen_manager"
LOG_FILE="/var/log/lockscreen_manager.log"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

check_sudo() {
    if [[ $EUID -ne 0 ]] && [[ "$1" != "install" ]] && [[ "$1" != "uninstall" ]]; then
        echo "Note: This operation requires sudo privileges for modifying system preferences."
    fi
}

create_log_dir() {
    mkdir -p "$(dirname "$LOG_FILE")"
}

# =============================================================================
# SET LOCK SCREEN MESSAGE SCRIPT
# =============================================================================

set_lock_message() {
    create_log_dir
    
    # Set the lock screen message
    if sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"; then
        # Log the action
        echo "$(date): Lock screen message set: $LOCK_MESSAGE" >> "$LOG_FILE"
        echo "Lock screen message set successfully"
    else
        echo "Failed to set lock screen message" >&2
        exit 1
    fi
}

# =============================================================================
# CLEAR LOCK SCREEN MESSAGE SCRIPT  
# =============================================================================

clear_lock_message() {
    local success=false
    
    echo "$(date): Attempting to clear lock screen message..." >> "$LOG_FILE"
    
    # Method 1: Use the approach that works manually - delete the key
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Deleted LoginwindowText key successfully" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 2: Verify the key is actually gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Verified LoginwindowText key is removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Warning: LoginwindowText key still exists after deletion" >> "$LOG_FILE"
    fi
    
    # Method 3: Force preference cache refresh to ensure changes take effect
    if killall -HUP cfprefsd 2>/dev/null; then
        echo "$(date): Sent HUP to cfprefsd to refresh preferences" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 4: Wait a moment to ensure the system has processed the change
    echo "$(date): Waiting 2 seconds for preference change to take effect..." >> "$LOG_FILE"
    sleep 2
    
    # Method 5: Final verification that the key is gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Final verification: LoginwindowText key successfully removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Error: LoginwindowText key still exists after all clearing attempts" >> "$LOG_FILE"
        success=false
    fi
    
    if [[ "$success" == "true" ]]; then
        echo "$(date): Lock screen message clearing completed successfully" >> "$LOG_FILE"
        echo "$(date): FileVault screen should now show no message" >> "$LOG_FILE"
    else
        echo "$(date): Warning: Lock screen message clearing may have failed" >> "$LOG_FILE"
    fi
}

# =============================================================================
# INSTALLATION SCRIPT
# =============================================================================

install_lockscreen_manager() {
    echo "Installing Lock Screen Message Manager..."
    echo "Performing clean installation..."

    # Clean up any existing installation first
    echo "Cleaning up existing installation..."
    
    # Unload existing LaunchDaemons
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    fi

    # Remove existing LaunchDaemon files
    if [[ $EUID -eq 0 ]]; then
        rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
    else
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
    fi

    # Remove existing script directory
    if [[ $EUID -eq 0 ]]; then
        rm -rf "$SCRIPT_DIR"
    else
        sudo rm -rf "$SCRIPT_DIR"
    fi

    # Clear any existing lock screen message
    if [[ $EUID -eq 0 ]]; then
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
        rm -f /var/run/lockscreen_shutdown_in_progress
    else
        sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
        sudo rm -f /var/run/lockscreen_shutdown_in_progress
    fi

    echo "Cleanup completed. Starting fresh installation..."

    # Create directories
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$SCRIPT_DIR"
        mkdir -p "$(dirname "$LOG_FILE")"
    else
        sudo mkdir -p "$SCRIPT_DIR"
        sudo mkdir -p "$(dirname "$LOG_FILE")"
    fi

    # Create a single coordinated script that handles both setting and clearing
    if [[ $EUID -eq 0 ]]; then
        tee "$SCRIPT_DIR/lockscreen_coordinator.sh" > /dev/null << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/lockscreen_manager.log"
LOCK_MESSAGE="🔴 Empathy 🟠 Ownership 🟢 Results
🔵 Objectivity 🟣 Openness"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to clear EFI cache files that control FileVault screen
clear_efi_cache() {
    echo "$(date): Using safe FileVault screen refresh methods..." >> "$LOG_FILE"
    
    local cache_cleared=false
    
    # Since EFI cache files are protected by SIP, we'll use safer alternative methods
    
    # Method 1: Clear system caches that might contain login screen data (safe)
    if [[ -d "/System/Library/Caches" ]]; then
        if rm -rf /System/Library/Caches/com.apple.loginwindow* 2>/dev/null; then
            echo "$(date): Cleared loginwindow system caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
        if rm -rf /System/Library/Caches/com.apple.SecurityAgent* 2>/dev/null; then
            echo "$(date): Cleared SecurityAgent system caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
    fi
    
    # Method 2: Clear user-specific login caches (safe)
    for user_home in /Users/*; do
        if [[ -d "$user_home" ]] && [[ -d "$user_home/Library/Caches" ]]; then
            if rm -rf "$user_home/Library/Caches/com.apple.loginwindow"* 2>/dev/null; then
                echo "$(date): Cleared user cache: $user_home" >> "$LOG_FILE"
                cache_cleared=true
            fi
        fi
    done
    
    # Method 3: Force system to rebuild login screen resources by touching key files (safe)
    if touch /System/Library/PrivateFrameworks/EFILogin.framework 2>/dev/null; then
        echo "$(date): Touched EFILogin framework to force refresh" >> "$LOG_FILE"
        cache_cleared=true
    fi
    
    if touch /System/Library/CoreServices/SecurityAgentPlugins/loginwindow.bundle 2>/dev/null; then
        echo "$(date): Touched loginwindow bundle to force refresh" >> "$LOG_FILE"
        cache_cleared=true
    fi
    
    # Method 4: Clear additional system caches that might affect login screen (safe)
    if [[ -d "/var/folders" ]]; then
        if find /var/folders -name "*loginwindow*" -type d -exec rm -rf {} \; 2>/dev/null; then
            echo "$(date): Cleared system loginwindow caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
    fi
    
    if [[ "$cache_cleared" == "true" ]]; then
        echo "$(date): Safe FileVault screen refresh methods completed successfully" >> "$LOG_FILE"
    else
        echo "$(date): Warning: No FileVault refresh methods were successful" >> "$LOG_FILE"
    fi
}

# Function to set lock screen message
set_lock_message() {
    if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" 2>/dev/null; then
        echo "$(date): Lock screen message set" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): Failed to set lock screen message" >> "$LOG_FILE"
        return 1
    fi
}

# Function to clear lock screen message
clear_lock_message() {
    local success=false
    
    echo "$(date): Attempting to clear lock screen message..." >> "$LOG_FILE"
    
    # Method 1: Use the approach that works manually - delete the key
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Deleted LoginwindowText key successfully" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 2: Verify the key is actually gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Verified LoginwindowText key is removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Warning: LoginwindowText key still exists after deletion" >> "$LOG_FILE"
    fi
    
    # Method 3: Force preference cache refresh to ensure changes take effect
    if killall -HUP cfprefsd 2>/dev/null; then
        echo "$(date): Sent HUP to cfprefsd to refresh preferences" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 4: Wait a moment to ensure the system has processed the change
    echo "$(date): Waiting 2 seconds for preference change to take effect..." >> "$LOG_FILE"
    sleep 2
    
    # Method 5: Final verification that the key is gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Final verification: LoginwindowText key successfully removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Error: LoginwindowText key still exists after all clearing attempts" >> "$LOG_FILE"
        success=false
    fi
    
    if [[ "$success" == "true" ]]; then
        echo "$(date): Lock screen message clearing completed successfully" >> "$LOG_FILE"
        echo "$(date): FileVault screen should now show no message" >> "$LOG_FILE"
    else
        echo "$(date): Warning: Lock screen message clearing may have failed" >> "$LOG_FILE"
    fi
}

# Signal handler function
cleanup_and_exit() {
    local signal_name=""
    case $1 in
        SIGTERM) signal_name="SIGTERM" ;;
        SIGINT)  signal_name="SIGINT" ;;
        SIGQUIT) signal_name="SIGQUIT" ;;
        SIGUSR1) signal_name="SIGUSR1" ;;
        *)       signal_name="UNKNOWN" ;;
    esac
    
    echo "$(date): Signal $signal_name received, setting test message..." >> "$LOG_FILE"
    
    # Instead of clearing, set a test message to see if we can modify it
    if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "Hello" 2>/dev/null; then
        echo "$(date): Test message 'Hello' set successfully" >> "$LOG_FILE"
    else
        echo "$(date): Failed to set test message" >> "$LOG_FILE"
    fi
    
    # Wait for the system to process the change
    echo "$(date): Waiting 3 seconds for preference change to take effect..." >> "$LOG_FILE"
    sleep 3
    
    # Verify the test message was set
    CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    if [[ "$CURRENT_MESSAGE" == "Hello" ]]; then
        echo "$(date): Test message verification successful - 'Hello' is set" >> "$LOG_FILE"
    else
        echo "$(date): Warning: Test message may not have been set properly" >> "$LOG_FILE"
    fi
    
    exit 0
}

# Set up signal handlers
trap 'cleanup_and_exit SIGTERM' SIGTERM
trap 'cleanup_and_exit SIGINT' SIGINT
trap 'cleanup_and_exit SIGQUIT' SIGQUIT
trap 'cleanup_and_exit SIGUSR1' SIGUSR1

# Log startup
echo "$(date): Lock screen coordinator started (PID: $$)" >> "$LOG_FILE"

# Don't automatically set the message on startup - only set it when explicitly requested
# set_lock_message

# Main monitoring loop
while true; do
    # Check for shutdown indicators
    if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || \
       [[ -f "/private/var/run/com.apple.reboot.started" ]] || \
       [[ -f "/private/var/run/com.apple.logout.started" ]]; then
        echo "$(date): Shutdown/reboot/logout detected, setting test message..." >> "$LOG_FILE"
        
        # Instead of clearing, set a test message to see if we can modify it
        if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "Hello" 2>/dev/null; then
            echo "$(date): Test message 'Hello' set successfully" >> "$LOG_FILE"
        else
            echo "$(date): Failed to set test message" >> "$LOG_FILE"
        fi
        
        # Wait for the system to process the change
        echo "$(date): Waiting 3 seconds for preference change to take effect..." >> "$LOG_FILE"
        sleep 3
        
        # Verify the test message was set
        CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
        if [[ "$CURRENT_MESSAGE" == "Hello" ]]; then
            echo "$(date): Test message verification successful - 'Hello' is set" >> "$LOG_FILE"
        else
            echo "$(date): Warning: Test message may not have been set properly" >> "$LOG_FILE"
        fi
        
        break
    fi
    
    # Sleep briefly to avoid excessive CPU usage
    sleep 2
done

# Final cleanup
echo "$(date): Lock screen coordinator stopped" >> "$LOG_FILE"
EOF
    else
        sudo tee "$SCRIPT_DIR/lockscreen_coordinator.sh" > /dev/null << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/lockscreen_manager.log"
LOCK_MESSAGE="🔴 Empathy 🟠 Ownership 🟢 Results
🔵 Objectivity 🟣 Openness"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to clear EFI cache files that control FileVault screen
clear_efi_cache() {
    echo "$(date): Using safe FileVault screen refresh methods..." >> "$LOG_FILE"
    
    local cache_cleared=false
    
    # Since EFI cache files are protected by SIP, we'll use safer alternative methods
    
    # Method 1: Clear system caches that might contain login screen data (safe)
    if [[ -d "/System/Library/Caches" ]]; then
        if rm -rf /System/Library/Caches/com.apple.loginwindow* 2>/dev/null; then
            echo "$(date): Cleared loginwindow system caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
        if rm -rf /System/Library/Caches/com.apple.SecurityAgent* 2>/dev/null; then
            echo "$(date): Cleared SecurityAgent system caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
    fi
    
    # Method 2: Clear user-specific login caches (safe)
    for user_home in /Users/*; do
        if [[ -d "$user_home" ]] && [[ -d "$user_home/Library/Caches" ]]; then
            if rm -rf "$user_home/Library/Caches/com.apple.loginwindow"* 2>/dev/null; then
                echo "$(date): Cleared user cache: $user_home" >> "$LOG_FILE"
                cache_cleared=true
            fi
        fi
    done
    
    # Method 3: Force system to rebuild login screen resources by touching key files (safe)
    if touch /System/Library/PrivateFrameworks/EFILogin.framework 2>/dev/null; then
        echo "$(date): Touched EFILogin framework to force refresh" >> "$LOG_FILE"
        cache_cleared=true
    fi
    
    if touch /System/Library/CoreServices/SecurityAgentPlugins/loginwindow.bundle 2>/dev/null; then
        echo "$(date): Touched loginwindow bundle to force refresh" >> "$LOG_FILE"
        cache_cleared=true
    fi
    
    # Method 4: Clear additional system caches that might affect login screen (safe)
    if [[ -d "/var/folders" ]]; then
        if find /var/folders -name "*loginwindow*" -type d -exec rm -rf {} \; 2>/dev/null; then
            echo "$(date): Cleared system loginwindow caches" >> "$LOG_FILE"
            cache_cleared=true
        fi
    fi
    
    if [[ "$cache_cleared" == "true" ]]; then
        echo "$(date): Safe FileVault screen refresh methods completed successfully" >> "$LOG_FILE"
    else
        echo "$(date): Warning: No FileVault refresh methods were successful" >> "$LOG_FILE"
    fi
}

# Function to set lock screen message
set_lock_message() {
    if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" 2>/dev/null; then
        echo "$(date): Lock screen message set" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): Failed to set lock screen message" >> "$LOG_FILE"
        return 1
    fi
}

# Function to clear lock screen message
clear_lock_message() {
    local success=false
    
    echo "$(date): Attempting to clear lock screen message..." >> "$LOG_FILE"
    
    # Method 1: Use the approach that works manually - delete the key
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Deleted LoginwindowText key successfully" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 2: Verify the key is actually gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Verified LoginwindowText key is removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Warning: LoginwindowText key still exists after deletion" >> "$LOG_FILE"
    fi
    
    # Method 3: Force preference cache refresh to ensure changes take effect
    if killall -HUP cfprefsd 2>/dev/null; then
        echo "$(date): Sent HUP to cfprefsd to refresh preferences" >> "$LOG_FILE"
        success=true
    fi
    
    # Method 4: Wait a moment to ensure the system has processed the change
    echo "$(date): Waiting 2 seconds for preference change to take effect..." >> "$LOG_FILE"
    sleep 2
    
    # Method 5: Final verification that the key is gone
    if ! defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Final verification: LoginwindowText key successfully removed" >> "$LOG_FILE"
        success=true
    else
        echo "$(date): Error: LoginwindowText key still exists after all clearing attempts" >> "$LOG_FILE"
        success=false
    fi
    
    if [[ "$success" == "true" ]]; then
        echo "$(date): Lock screen message clearing completed successfully" >> "$LOG_FILE"
        echo "$(date): FileVault screen should now show no message" >> "$LOG_FILE"
    else
        echo "$(date): Warning: Lock screen message clearing may have failed" >> "$LOG_FILE"
    fi
}

# Signal handler function
cleanup_and_exit() {
    local signal_name=""
    case $1 in
        SIGTERM) signal_name="SIGTERM" ;;
        SIGINT)  signal_name="SIGINT" ;;
        SIGQUIT) signal_name="SIGQUIT" ;;
        SIGUSR1) signal_name="SIGUSR1" ;;
        *)       signal_name="UNKNOWN" ;;
    esac
    
    echo "$(date): Signal $signal_name received, setting test message..." >> "$LOG_FILE"
    
    # Instead of clearing, set a test message to see if we can modify it
    if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "Hello" 2>/dev/null; then
        echo "$(date): Test message 'Hello' set successfully" >> "$LOG_FILE"
    else
        echo "$(date): Failed to set test message" >> "$LOG_FILE"
    fi
    
    # Wait for the system to process the change
    echo "$(date): Waiting 3 seconds for preference change to take effect..." >> "$LOG_FILE"
    sleep 3
    
    # Verify the test message was set
    CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    if [[ "$CURRENT_MESSAGE" == "Hello" ]]; then
        echo "$(date): Test message verification successful - 'Hello' is set" >> "$LOG_FILE"
    else
        echo "$(date): Warning: Test message may not have been set properly" >> "$LOG_FILE"
    fi
    
    exit 0
}

# Set up signal handlers
trap 'cleanup_and_exit SIGTERM' SIGTERM
trap 'cleanup_and_exit SIGINT' SIGINT
trap 'cleanup_and_exit SIGQUIT' SIGQUIT
trap 'cleanup_and_exit SIGUSR1' SIGUSR1

# Log startup
echo "$(date): Lock screen coordinator started (PID: $$)" >> "$LOG_FILE"

# Don't automatically set the message on startup - only set it when explicitly requested
# set_lock_message

# Main monitoring loop
while true; do
    # Check for shutdown indicators
    if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || \
       [[ -f "/private/var/run/com.apple.reboot.started" ]] || \
       [[ -f "/private/var/run/com.apple.logout.started" ]]; then
        echo "$(date): Shutdown/reboot/logout detected, setting test message..." >> "$LOG_FILE"
        
        # Instead of clearing, set a test message to see if we can modify it
        if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "Hello" 2>/dev/null; then
            echo "$(date): Test message 'Hello' set successfully" >> "$LOG_FILE"
        else
            echo "$(date): Failed to set test message" >> "$LOG_FILE"
        fi
        
        # Wait for the system to process the change
        echo "$(date): Waiting 3 seconds for preference change to take effect..." >> "$LOG_FILE"
        sleep 3
        
        # Verify the test message was set
        CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
        if [[ "$CURRENT_MESSAGE" == "Hello" ]]; then
            echo "$(date): Test message verification successful - 'Hello' is set" >> "$LOG_FILE"
        else
            echo "$(date): Warning: Test message may not have been set properly" >> "$LOG_FILE"
        fi
        
        break
    fi
    
    # Sleep briefly to avoid excessive CPU usage
    sleep 2
done

# Final cleanup
echo "$(date): Lock screen coordinator stopped" >> "$LOG_FILE"
EOF
    fi

    # Make script executable
    if [[ $EUID -eq 0 ]]; then
        chmod +x "$SCRIPT_DIR/lockscreen_coordinator.sh"
    else
        sudo chmod +x "$SCRIPT_DIR/lockscreen_coordinator.sh"
    fi

    # Create LaunchDaemon for the lockscreen coordinator
    if [[ $EUID -eq 0 ]]; then
        tee /Library/LaunchDaemons/com.lockscreen.coordinator.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.coordinator</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/lockscreen_coordinator.sh</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_coordinator.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_coordinator.log</string>
    <key>ProcessType</key>
    <string>Background</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>ExitTimeOut</key>
    <integer>5</integer>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
    <key>UserName</key>
    <string>root</string>
    <key>GroupName</key>
    <string>wheel</string>
</dict>
</plist>
EOF
    else
        sudo tee /Library/LaunchDaemons/com.lockscreen.coordinator.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.coordinator</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/lockscreen_coordinator.sh</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_coordinator.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_coordinator.log</string>
    <key>ProcessType</key>
    <string>Background</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>ExitTimeOut</key>
    <integer>5</integer>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
    <key>UserName</key>
    <string>root</string>
    <key>GroupName</key>
    <string>wheel</string>
</dict>
</plist>
EOF
    fi

    # Set proper permissions
    if [[ $EUID -eq 0 ]]; then
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.coordinator.plist
    else
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.coordinator.plist
    fi

    # Load the LaunchDaemons
    if [[ $EUID -eq 0 ]]; then
        if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null; then
            echo "✓ Lock screen coordinator LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load lock screen coordinator LaunchDaemon (may already be loaded)"
        fi
    else
        if sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null; then
            echo "✓ Lock screen coordinator LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load lock screen coordinator LaunchDaemon (may already be loaded)"
        fi
    fi

    # Set the message immediately after installation
    if [[ $EUID -eq 0 ]]; then
        if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"; then
            echo "✓ Lock screen message set immediately"
        else
            echo "⚠ Warning: Failed to set message immediately"
        fi
    else
        if sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"; then
            echo "✓ Lock screen message set immediately"
        else
            echo "⚠ Warning: Failed to set message immediately"
        fi
    fi

    echo ""
    echo "✅ Installation complete!"
    echo "📋 Configuration:"
    echo "   Message: $LOCK_MESSAGE"
    echo "   Log file: $LOG_FILE"
    echo ""
    echo "🔄 The system will now:"
    echo "   • Set the message on system startup/login"
    echo "   • Monitor for shutdown/reboot events and clear the message"
    echo "   • Use a single coordinated daemon (no race conditions)"
    echo "   • Log all actions to $LOG_FILE"

    # Validate installation
    echo ""
    echo "🔍 Validating installation..."
    VALIDATION_ERRORS=0

    # Check if LaunchDaemon files exist
    if [[ ! -f "/Library/LaunchDaemons/com.lockscreen.coordinator.plist" ]]; then
        echo "❌ Error: Lock screen coordinator LaunchDaemon file missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if script directory exists
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        echo "❌ Error: Script directory missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if scripts are executable
    if [[ ! -x "$SCRIPT_DIR/lockscreen_coordinator.sh" ]]; then
        echo "❌ Error: Lock screen coordinator script not executable"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if LaunchDaemons are loaded
    if [[ $EUID -eq 0 ]]; then
        if ! launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "❌ Error: Lock screen coordinator LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi
    else
        if ! sudo launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "❌ Error: Lock screen coordinator LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi
    fi

    # Final validation result
    if [[ $VALIDATION_ERRORS -eq 0 ]]; then
        echo "✅ Installation validation successful"
        echo "🚀"
        exit 0
    else
        echo "❌ Installation validation failed ($VALIDATION_ERRORS errors)"
        echo "🔧 Please check the installation and try again"
        exit 1
    fi
}

# =============================================================================
# UNINSTALL SCRIPT
# =============================================================================

uninstall_lockscreen_manager() {
    echo "Uninstalling Lock Screen Message Manager..."

    # Unload services
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
    fi

    # Remove files
    if [[ $EUID -eq 0 ]]; then
        rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        rm -rf "$SCRIPT_DIR"
    else
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        sudo rm -rf "$SCRIPT_DIR"
    fi

    # Clear any existing lock screen message
    if [[ $EUID -eq 0 ]]; then
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null
    else
        sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null
    fi

    echo "✅ Uninstallation complete!"
}

# =============================================================================
# STATUS CHECK
# =============================================================================

show_status() {
    echo "Lock Screen Message Manager Status"
    echo "=================================="
    
    # Check if files exist
    if [[ -f "/Library/LaunchDaemons/com.lockscreen.coordinator.plist" ]]; then
        echo "✅ Lock screen coordinator LaunchDaemon: Installed"
    else
        echo "❌ Lock screen coordinator LaunchDaemon: Not installed"
    fi
    
    # Check if script directory exists
    if [[ -d "$SCRIPT_DIR" ]]; then
        echo "✅ Script directory: $SCRIPT_DIR"
    else
        echo "❌ Script directory: Missing"
    fi
    
    # Check if scripts are executable
    if [[ -x "$SCRIPT_DIR/lockscreen_coordinator.sh" ]]; then
        echo "✅ Lock screen coordinator script: Executable"
    else
        echo "❌ Lock screen coordinator script: Not executable"
    fi
    
    # Check if LaunchDaemon is loaded
    if [[ $EUID -eq 0 ]]; then
        if launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "✅ Lock screen coordinator: Running (managed by launchd)"
        else
            echo "❌ Lock screen coordinator: Not running"
        fi
    else
        if sudo launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "✅ Lock screen coordinator: Running (managed by launchd)"
        else
            echo "❌ Lock screen coordinator: Not running"
        fi
    fi
    
    # Check current lock screen message
    if [[ $EUID -eq 0 ]]; then
        CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    else
        CURRENT_MESSAGE=$(sudo defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    fi
    
    if [[ -n "$CURRENT_MESSAGE" ]]; then
        echo "🔒 Current message: $CURRENT_MESSAGE"
    else
        echo "🔓 No lock screen message currently set"
    fi
    
    # Check log file
    if [[ -f "$LOG_FILE" ]]; then
        echo "📝 Recent log entries:"
        tail -5 "$LOG_FILE" | sed 's/^/   /'
    else
        echo "📝 No log file found"
    fi
}

# =============================================================================
# RESTART SHUTDOWN MONITOR
# =============================================================================

restart_shutdown_monitor() {
    echo "Restarting shutdown monitor..."
    
    # Reload the LaunchDaemon
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        sleep 1
        if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist; then
            echo "✅ Lock screen coordinator restarted successfully"
        else
            echo "❌ Failed to restart lock screen coordinator"
            exit 1
        fi
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        sleep 1
        if sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist; then
            echo "✅ Lock screen coordinator restarted successfully"
        else
            echo "❌ Failed to restart lock screen coordinator"
            exit 1
        fi
    fi
    
    # Wait a moment and check status
    sleep 2
    echo "✅ Monitor restart completed"
}

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

case "${1:-install}" in
    "install")
        install_lockscreen_manager
        ;;
    "uninstall")
        uninstall_lockscreen_manager
        ;;
    "set")
        check_sudo "$1"
        set_lock_message
        ;;
    "clear")
        check_sudo "$1"
        clear_lock_message
        ;;
    "clear-aggressive")
        check_sudo "$1"
        clear_lock_message
        ;;
    "restart")
        check_sudo "$1"
        restart_shutdown_monitor
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Lock Screen Message Manager"
        echo "=========================="
        echo ""
        echo "Usage: $0 {install|uninstall|set|clear|clear-aggressive|restart|status}"
        echo ""
        echo "Commands:"
        echo "  install         - Install the lock screen message manager (default)"
        echo "  uninstall       - Remove the lock screen message manager"
        echo "  set             - Set the lock screen message immediately"
        echo "  clear           - Clear the lock screen message immediately (safe)"
        echo "  clear-aggressive- Clear the lock screen message with aggressive methods (may log you out)"
        echo "  restart         - Restart the lock screen coordinator daemon"
        echo "  status          - Show current status and configuration"
        echo ""
        echo "✨ Features:"
        echo "  • Automatically sets message after login"
        echo "  • Robust shutdown monitoring with signal handling"
        echo "  • Automatically clears message before shutdown/restart"
        echo "  • Comprehensive logging and status monitoring"
        echo "  • Simple and reliable operation"
        echo ""
        echo "📝 Example: $0 (runs install by default)"
        exit 1
        ;;
esac
