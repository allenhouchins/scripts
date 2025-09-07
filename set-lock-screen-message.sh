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
    
    if sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"; then
        echo "$(date): Lock screen message set" >> "$LOG_FILE"
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
    echo "$(date): Clearing lock screen message..." >> "$LOG_FILE"
    
    # Clear the message
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Message cleared from system preferences" >> "$LOG_FILE"
    fi
    
    # Update preboot volume for FileVault compatibility
    if diskutil apfs updatePreboot / 2>/dev/null; then
        echo "$(date): Preboot volume updated for FileVault screen" >> "$LOG_FILE"
    fi
    
    # Wait for changes to take effect
    sleep 2
    
    echo "$(date): Lock screen message clearing completed" >> "$LOG_FILE"
}

# =============================================================================
# INSTALLATION SCRIPT
# =============================================================================

install_lockscreen_manager() {
    echo "Installing Lock Screen Message Manager..."

    # Clean up any existing installation
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
        rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        rm -rf "$SCRIPT_DIR"
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        sudo rm -rf "$SCRIPT_DIR"
        sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
    fi

    # Create directories
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$SCRIPT_DIR"
        mkdir -p "$(dirname "$LOG_FILE")"
    else
        sudo mkdir -p "$SCRIPT_DIR"
        sudo mkdir -p "$(dirname "$LOG_FILE")"
    fi

    # Create the coordinator script
    if [[ $EUID -eq 0 ]]; then
        tee "$SCRIPT_DIR/lockscreen_coordinator.sh" > /dev/null << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/lockscreen_manager.log"
LOCK_MESSAGE="🔴 Empathy 🟠 Ownership 🟢 Results
🔵 Objectivity 🟣 Openness"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

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
    echo "$(date): Clearing lock screen message..." >> "$LOG_FILE"
    
    # Clear the message
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Message cleared from system preferences" >> "$LOG_FILE"
    fi
    
    # Update preboot volume for FileVault compatibility
    if diskutil apfs updatePreboot / 2>/dev/null; then
        echo "$(date): Preboot volume updated for FileVault screen" >> "$LOG_FILE"
    fi
    
    # Wait for changes to take effect
    sleep 2
    
    echo "$(date): Lock screen message clearing completed" >> "$LOG_FILE"
}

# Signal handler for shutdown
cleanup_and_exit() {
    echo "$(date): Shutdown signal received, clearing message..." >> "$LOG_FILE"
    clear_lock_message
    exit 0
}

# Set up signal handlers
trap cleanup_and_exit SIGTERM SIGINT SIGQUIT SIGUSR1 SIGUSR2 SIGHUP EXIT

# Log startup
echo "$(date): Lock screen coordinator started (PID: $$)" >> "$LOG_FILE"

# Set message on startup
set_lock_message

# Record startup time to avoid false shutdown detection during startup
STARTUP_TIME=$(date +%s)

# Main monitoring loop
while true; do
    # Check for shutdown indicators
    if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || \
       [[ -f "/private/var/run/com.apple.reboot.started" ]] || \
       [[ -f "/private/var/run/com.apple.logout.started" ]]; then
        echo "$(date): Shutdown/reboot/logout detected, clearing message..." >> "$LOG_FILE"
        clear_lock_message
        break
    fi
    
    # Check if system processes are stopping (shutdown indicator)
    # Only check this if we've been running for at least 30 seconds to avoid false positives during startup
    CURRENT_TIME=$(date +%s)
    if [[ $((CURRENT_TIME - STARTUP_TIME)) -gt 30 ]]; then
        if ! pgrep -f "WindowServer\|loginwindow" > /dev/null 2>&1; then
            echo "$(date): System processes stopped, clearing message..." >> "$LOG_FILE"
            clear_lock_message
            break
        fi
    fi
    
    sleep 2
done

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
    echo "$(date): Clearing lock screen message..." >> "$LOG_FILE"
    
    # Clear the message
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "$(date): Message cleared from system preferences" >> "$LOG_FILE"
    fi
    
    # Update preboot volume for FileVault compatibility
    if diskutil apfs updatePreboot / 2>/dev/null; then
        echo "$(date): Preboot volume updated for FileVault screen" >> "$LOG_FILE"
    fi
    
    # Wait for changes to take effect
    sleep 2
    
    echo "$(date): Lock screen message clearing completed" >> "$LOG_FILE"
}

# Signal handler for shutdown
cleanup_and_exit() {
    echo "$(date): Shutdown signal received, clearing message..." >> "$LOG_FILE"
    clear_lock_message
    exit 0
}

# Set up signal handlers
trap cleanup_and_exit SIGTERM SIGINT SIGQUIT SIGUSR1 SIGUSR2 SIGHUP EXIT

# Log startup
echo "$(date): Lock screen coordinator started (PID: $$)" >> "$LOG_FILE"

# Set message on startup
set_lock_message

# Record startup time to avoid false shutdown detection during startup
STARTUP_TIME=$(date +%s)

# Main monitoring loop
while true; do
    # Check for shutdown indicators
    if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || \
       [[ -f "/private/var/run/com.apple.reboot.started" ]] || \
       [[ -f "/private/var/run/com.apple.logout.started" ]]; then
        echo "$(date): Shutdown/reboot/logout detected, clearing message..." >> "$LOG_FILE"
        clear_lock_message
        break
    fi
    
    # Check if system processes are stopping (shutdown indicator)
    # Only check this if we've been running for at least 30 seconds to avoid false positives during startup
    CURRENT_TIME=$(date +%s)
    if [[ $((CURRENT_TIME - STARTUP_TIME)) -gt 30 ]]; then
        if ! pgrep -f "WindowServer\|loginwindow" > /dev/null 2>&1; then
            echo "$(date): System processes stopped, clearing message..." >> "$LOG_FILE"
            clear_lock_message
            break
        fi
    fi
    
    sleep 2
done

echo "$(date): Lock screen coordinator stopped" >> "$LOG_FILE"
EOF
    fi

    # Make script executable
    if [[ $EUID -eq 0 ]]; then
        chmod +x "$SCRIPT_DIR/lockscreen_coordinator.sh"
    else
        sudo chmod +x "$SCRIPT_DIR/lockscreen_coordinator.sh"
    fi

    # Create LaunchDaemon
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

    # Load the LaunchDaemon
    if [[ $EUID -eq 0 ]]; then
        launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    else
        sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    fi

    # Set the message immediately and update preboot volume
    if [[ $EUID -eq 0 ]]; then
        defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" 2>/dev/null || true
        diskutil apfs updatePreboot / 2>/dev/null || true
    else
        sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" 2>/dev/null || true
        sudo diskutil apfs updatePreboot / 2>/dev/null || true
    fi

    echo "✅ Installation complete!"
    echo "📋 Configuration:"
    echo "   Message: $LOCK_MESSAGE"
    echo "   Log file: $LOG_FILE"
    echo ""
    echo "🔄 The system will now:"
    echo "   • Set the message immediately (and on system startup)"
    echo "   • Monitor for shutdown/reboot events and clear the message"
    echo "   • Update preboot volume for FileVault compatibility"
    echo "   • Log all actions to $LOG_FILE"
}

# =============================================================================
# UNINSTALL SCRIPT
# =============================================================================

uninstall_lockscreen_manager() {
    echo "Uninstalling Lock Screen Message Manager..."

    # Unload services
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        rm -rf "$SCRIPT_DIR"
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.coordinator.plist
        sudo rm -rf "$SCRIPT_DIR"
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
        echo "✅ LaunchDaemon: Installed"
    else
        echo "❌ LaunchDaemon: Not installed"
    fi
    
    # Check if script directory exists
    if [[ -d "$SCRIPT_DIR" ]]; then
        echo "✅ Script directory: $SCRIPT_DIR"
    else
        echo "❌ Script directory: Missing"
    fi
    
    # Check if LaunchDaemon is loaded
    if [[ $EUID -eq 0 ]]; then
        if launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "✅ Service: Running"
        else
            echo "❌ Service: Not running"
        fi
    else
        if sudo launchctl list | grep -q "com.lockscreen.coordinator"; then
            echo "✅ Service: Running"
        else
            echo "❌ Service: Not running"
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
# RESTART SERVICE
# =============================================================================

restart_service() {
    echo "Restarting lock screen manager service..."
    
    if [[ $EUID -eq 0 ]]; then
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        sleep 1
        launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null
        sleep 1
        sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.coordinator.plist 2>/dev/null || true
    fi
    
    echo "✅ Service restarted"
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
    "restart")
        check_sudo "$1"
        restart_service
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Lock Screen Message Manager"
        echo "=========================="
        echo ""
        echo "Usage: $0 {install|uninstall|set|clear|restart|status}"
        echo ""
        echo "Commands:"
        echo "  install    - Install the lock screen message manager (default)"
        echo "  uninstall  - Remove the lock screen message manager"
        echo "  set        - Set the lock screen message immediately"
        echo "  clear      - Clear the lock screen message immediately"
        echo "  restart    - Restart the lock screen manager service"
        echo "  status     - Show current status and configuration"
        echo ""
        echo "Features:"
        echo "  • Automatically sets message after login"
        echo "  • Monitors for shutdown/reboot events"
        echo "  • Automatically clears message before shutdown/restart"
        echo "  • FileVault compatible with preboot volume updates"
        echo "  • Comprehensive logging and status monitoring"
        echo ""
        echo "Example: $0 (runs install by default)"
        exit 1
        ;;
esac