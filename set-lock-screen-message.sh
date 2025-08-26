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
    create_log_dir
    
    # Clear the lock screen message
    if sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        # Log the action
        echo "$(date): Lock screen message cleared" >> "$LOG_FILE"
        echo "Lock screen message cleared successfully"
    else
        echo "$(date): Lock screen message was already cleared or not set" >> "$LOG_FILE"
        echo "Lock screen message was already cleared or not set"
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
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null || true
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null || true
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null || true
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null || true
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null || true
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null || true
    fi

    # Remove existing LaunchDaemon files
    if [[ $EUID -eq 0 ]]; then
        rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
    else
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
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
    else
        sudo defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
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

    # Create the clear message script (shutdown-based approach)
    if [[ $EUID -eq 0 ]]; then
        tee "$SCRIPT_DIR/clear_message.sh" > /dev/null << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Clear the lock screen message
if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
    echo "$(date): Lock screen message cleared" >> "$LOG_FILE"
else
    echo "$(date): Lock screen message was already cleared or not set" >> "$LOG_FILE"
fi
EOF
    else
        sudo tee "$SCRIPT_DIR/clear_message.sh" > /dev/null << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Clear the lock screen message
if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
    echo "$(date): Lock screen message cleared" >> "$LOG_FILE"
else
    echo "$(date): Lock screen message was already cleared or not set" >> "$LOG_FILE"
fi
EOF
    fi

    # Make script executable
    if [[ $EUID -eq 0 ]]; then
        chmod +x "$SCRIPT_DIR/clear_message.sh"
    else
        sudo chmod +x "$SCRIPT_DIR/clear_message.sh"
    fi

    # Create the set message script
    if [[ $EUID -eq 0 ]]; then
        tee "$SCRIPT_DIR/set_message.sh" > /dev/null << EOF
#!/bin/bash
LOG_FILE="/var/log/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Set the lock screen message
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"
echo "$(date): Lock screen message set" >> "$LOG_FILE"
EOF
    else
        sudo tee "$SCRIPT_DIR/set_message.sh" > /dev/null << EOF
#!/bin/bash
LOG_FILE="/var/log/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Set the lock screen message
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"
echo "$(date): Lock screen message set" >> "$LOG_FILE"
EOF
    fi

    # Make script executable
    if [[ $EUID -eq 0 ]]; then
        chmod +x "$SCRIPT_DIR/set_message.sh"
    else
        sudo chmod +x "$SCRIPT_DIR/set_message.sh"
    fi

    # Create LaunchDaemon for setting message on login
    if [[ $EUID -eq 0 ]]; then
        tee /Library/LaunchDaemons/com.lockscreen.setmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/set_message.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_set.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_set.log</string>
</dict>
</plist>
EOF
    else
        sudo tee /Library/LaunchDaemons/com.lockscreen.setmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/set_message.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_set.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_set.log</string>
</dict>
</plist>
EOF
    fi

            # Create LaunchDaemon for clearing message on shutdown
        if [[ $EUID -eq 0 ]]; then
            tee /Library/LaunchDaemons/com.lockscreen.clearmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.clearmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/clear_message.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/private/var/run/com.apple.shutdown.started</string>
        <string>/private/var/run/com.apple.reboot.started</string>
    </array>
    <key>LaunchEvents</key>
    <dict>
        <key>com.apple.system.shutdown</key>
        <dict>
            <key>Notification</key>
            <string>com.apple.system.shutdown</string>
        </dict>
        <key>com.apple.system.reboot</key>
        <dict>
            <key>Notification</key>
            <string>com.apple.system.reboot</string>
        </dict>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_clear.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_clear.log</string>
</dict>
</plist>
EOF
            else
            sudo tee /Library/LaunchDaemons/com.lockscreen.clearmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.clearmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/clear_message.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/private/var/run/com.apple.shutdown.started</string>
        <string>/private/var/run/com.apple.reboot.started</string>
    </array>
    <key>LaunchEvents</key>
    <dict>
        <key>com.apple.system.shutdown</key>
        <dict>
            <key>Notification</key>
            <string>com.apple.system.shutdown</string>
        </dict>
        <key>com.apple.system.reboot</key>
        <dict>
            <key>Notification</key>
            <string>com.apple.system.reboot</string>
        </dict>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_clear.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_clear.log</string>
</dict>
</plist>
EOF
    fi

    # Create additional shutdown detection using a different approach
    if [[ $EUID -eq 0 ]]; then
        tee /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.shutdownwatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>while true; do if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || [[ -f "/private/var/run/com.apple.reboot.started" ]]; then defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; echo "\$(date): Lock screen message cleared by shutdown watcher" >> /var/log/lockscreen_manager.log; break; fi; sleep 1; done</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_shutdownwatcher.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_shutdownwatcher.log</string>
</dict>
</plist>
EOF
    else
        sudo tee /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.shutdownwatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>while true; do if [[ -f "/private/var/run/com.apple.shutdown.started" ]] || [[ -f "/private/var/run/com.apple.reboot.started" ]]; then defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; echo "\$(date): Lock screen message cleared by shutdown watcher" >> /var/log/lockscreen_manager.log; break; fi; sleep 1; done</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_shutdownwatcher.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_shutdownwatcher.log</string>
</dict>
</plist>
EOF
    fi

    # Set proper permissions
    if [[ $EUID -eq 0 ]]; then
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
    else
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
    fi

    # Load the LaunchDaemons
    if [[ $EUID -eq 0 ]]; then
        if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null; then
            echo "✓ Set message LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load set message LaunchDaemon (may already be loaded)"
        fi

        if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null; then
            echo "✓ Clear message LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load clear message LaunchDaemon (may already be loaded)"
        fi

        if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null; then
            echo "✓ Shutdown watcher LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load shutdown watcher LaunchDaemon (may already be loaded)"
        fi
    else
        if sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null; then
            echo "✓ Set message LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load set message LaunchDaemon (may already be loaded)"
        fi

        if sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null; then
            echo "✓ Clear message LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load clear message LaunchDaemon (may already be loaded)"
        fi

        if sudo launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null; then
            echo "✓ Shutdown watcher LaunchDaemon loaded successfully"
        else
            echo "⚠ Warning: Failed to load shutdown watcher LaunchDaemon (may already be loaded)"
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
    echo "   • Clear the message before shutdown/restart"
    echo "   • Log all actions to $LOG_FILE"

    # Validate installation
    echo ""
    echo "🔍 Validating installation..."
    VALIDATION_ERRORS=0

    # Check if LaunchDaemon files exist
    if [[ ! -f "/Library/LaunchDaemons/com.lockscreen.setmessage.plist" ]]; then
        echo "❌ Error: Set message LaunchDaemon file missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    if [[ ! -f "/Library/LaunchDaemons/com.lockscreen.clearmessage.plist" ]]; then
        echo "❌ Error: Clear message LaunchDaemon file missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    if [[ ! -f "/Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist" ]]; then
        echo "❌ Error: Shutdown watcher LaunchDaemon file missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if script directory exists
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        echo "❌ Error: Script directory missing"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if scripts are executable
    if [[ ! -x "$SCRIPT_DIR/clear_message.sh" ]]; then
        echo "❌ Error: Clear message script not executable"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    if [[ ! -x "$SCRIPT_DIR/set_message.sh" ]]; then
        echo "❌ Error: Set message script not executable"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if LaunchDaemons are loaded
    if [[ $EUID -eq 0 ]]; then
        if ! launchctl list | grep -q "com.lockscreen.setmessage"; then
            echo "❌ Error: Set message LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi

        if ! launchctl list | grep -q "com.lockscreen.clearmessage"; then
            echo "❌ Error: Clear message LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi
    else
        if ! sudo launchctl list | grep -q "com.lockscreen.setmessage"; then
            echo "❌ Error: Set message LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi

        if ! sudo launchctl list | grep -q "com.lockscreen.clearmessage"; then
            echo "❌ Error: Clear message LaunchDaemon not loaded"
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
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist 2>/dev/null
    fi

    # Remove files
    if [[ $EUID -eq 0 ]]; then
        rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
        rm -rf "$SCRIPT_DIR"
    else
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist
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
    if [[ -f "/Library/LaunchDaemons/com.lockscreen.setmessage.plist" ]]; then
        echo "✅ Set message LaunchDaemon: Installed"
    else
        echo "❌ Set message LaunchDaemon: Not installed"
    fi
    
    if [[ -f "/Library/LaunchDaemons/com.lockscreen.clearmessage.plist" ]]; then
        echo "✅ Clear message LaunchDaemon: Installed"
    else
        echo "❌ Clear message LaunchDaemon: Not installed"
    fi
    
    if [[ -f "/Library/LaunchDaemons/com.lockscreen.shutdownwatcher.plist" ]]; then
        echo "✅ Shutdown watcher LaunchDaemon: Installed"
    else
        echo "❌ Shutdown watcher LaunchDaemon: Not installed"
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
    "status")
        show_status
        ;;
    *)
        echo "Lock Screen Message Manager"
        echo "=========================="
        echo ""
        echo "Usage: $0 {install|uninstall|set|clear|status}"
        echo ""
        echo "Commands:"
        echo "  install   - Install the lock screen message manager (default)"
        echo "  uninstall - Remove the lock screen message manager"
        echo "  set       - Set the lock screen message immediately"
        echo "  clear     - Clear the lock screen message immediately"
        echo "  status    - Show current status and configuration"
        echo ""
        echo "✨ Features:"
        echo "  • Automatically sets message after login"
        echo "  • Automatically clears message before shutdown/restart"
        echo "  • Comprehensive logging and status monitoring"
        echo "  • Simple and reliable operation"
        echo ""
        echo "📝 Example: $0 (runs install by default)"
        exit 1
        ;;
esac
