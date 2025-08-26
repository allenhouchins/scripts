#!/bin/bash

# =============================================================================
# LOCK SCREEN MESSAGE MANAGER
# =============================================================================

# Configuration
LOCK_MESSAGE="🔴 Empathy 🟠 Ownership 🟢 Results
🔵 Objectivity 🟣 Openness"
SCRIPT_DIR="/usr/local/bin/lockscreen_manager"
LOG_FILE="$HOME/Library/Logs/lockscreen_manager.log"

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
        launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null || true
    else
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null || true
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null || true
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null || true
    fi

    # Remove existing LaunchDaemon files
    if [[ $EUID -eq 0 ]]; then
        rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        rm -f /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
    else
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
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

    # Detect if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "Running as root"
        
        # Get the currently logged in user
        LOGGED_IN_USER=$(stat -f%Su /dev/console 2>/dev/null || echo "")
        
        # Check if we're in Setup Assistant (no user created yet)
        if [[ -z "$LOGGED_IN_USER" ]] || [[ "$LOGGED_IN_USER" == "root" ]]; then
            echo "Setup Assistant detected - installing for first user creation"
            SETUP_ASSISTANT_MODE=true
            LOG_FILE="/var/log/lockscreen_manager.log"
        else
            echo "Detected logged in user: $LOGGED_IN_USER"
            SETUP_ASSISTANT_MODE=false
            USER_HOME=$(eval echo "~$LOGGED_IN_USER")
            LOG_FILE="$USER_HOME/Library/Logs/lockscreen_manager.log"
        fi
        
        # Create directories
        mkdir -p "$SCRIPT_DIR"
        mkdir -p "$(dirname "$LOG_FILE")"
        
        if [[ "$SETUP_ASSISTANT_MODE" == "false" ]]; then
            # Set ownership for user directories
            chown -R "$LOGGED_IN_USER" "$(dirname "$LOG_FILE")"
        fi
    else
        # Running as regular user
        echo "Running as regular user"
        USER_HOME="$HOME"
        LOG_FILE="$HOME/Library/Logs/lockscreen_manager.log"
        LOGGED_IN_USER=$(whoami)
        SETUP_ASSISTANT_MODE=false
        
        # Create directories
        sudo mkdir -p "$SCRIPT_DIR"
        mkdir -p "$(dirname "$LOG_FILE")"
    fi

    # Create the clear message script with proper user context
    if [[ $EUID -eq 0 ]]; then
        # Running as root, use tee directly
        if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
            # Setup Assistant mode - use system log
            tee "$SCRIPT_DIR/clear_message.sh" > /dev/null << EOF
#!/bin/bash
LOG_FILE="/var/log/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "\$(dirname "\$LOG_FILE")"

# Check if this was triggered by a startup or shutdown event
if [[ -f /private/var/run/com.apple.shutdown.started ]]; then
    TRIGGER="shutdown event"
    SHOULD_CLEAR=true
elif [[ -f /private/var/run/com.apple.reboot.started ]]; then
    TRIGGER="reboot event"
    SHOULD_CLEAR=true
elif [[ -n "\$LAUNCH_EVENT" ]]; then
    TRIGGER="system event (\$LAUNCH_EVENT)"
    SHOULD_CLEAR=true
elif [[ "\$1" == "startup" ]]; then
    TRIGGER="startup event"
    # Only clear at startup if no user is logged in (FileVault unlock scenario)
    if [[ -n "\$(stat -f%Su /dev/console 2>/dev/null | grep -v root)" ]]; then
        SHOULD_CLEAR=false
        echo "\$(date): Startup event detected with logged in user - skipping clear" >> "\$LOG_FILE"
    else
        SHOULD_CLEAR=true
    fi
else
    TRIGGER="manual clear"
    SHOULD_CLEAR=true
fi

# Clear the lock screen message only if needed
if [[ "\$SHOULD_CLEAR" == "true" ]]; then
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "\$(date): Lock screen message cleared (\$TRIGGER)" >> "\$LOG_FILE"
    else
        echo "\$(date): Lock screen message was already cleared (\$TRIGGER)" >> "\$LOG_FILE"
    fi
fi
EOF
        else
            # Normal mode - use user log
            tee "$SCRIPT_DIR/clear_message.sh" > /dev/null << EOF
#!/bin/bash
LOG_FILE="$USER_HOME/Library/Logs/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "\$(dirname "\$LOG_FILE")"

# Check if this was triggered by a startup or shutdown event
if [[ -f /private/var/run/com.apple.shutdown.started ]]; then
    TRIGGER="shutdown event"
    SHOULD_CLEAR=true
elif [[ -f /private/var/run/com.apple.reboot.started ]]; then
    TRIGGER="reboot event"
    SHOULD_CLEAR=true
elif [[ -n "\$LAUNCH_EVENT" ]]; then
    TRIGGER="system event (\$LAUNCH_EVENT)"
    SHOULD_CLEAR=true
elif [[ "\$1" == "startup" ]]; then
    TRIGGER="startup event"
    # Only clear at startup if no user is logged in (FileVault unlock scenario)
    if [[ -n "\$(stat -f%Su /dev/console 2>/dev/null | grep -v root)" ]]; then
        SHOULD_CLEAR=false
        echo "\$(date): Startup event detected with logged in user - skipping clear" >> "\$LOG_FILE"
    else
        SHOULD_CLEAR=true
    fi
else
    TRIGGER="manual clear"
    SHOULD_CLEAR=true
fi

# Clear the lock screen message only if needed
if [[ "\$SHOULD_CLEAR" == "true" ]]; then
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "\$(date): Lock screen message cleared (\$TRIGGER)" >> "\$LOG_FILE"
    else
        echo "\$(date): Lock screen message was already cleared (\$TRIGGER)" >> "\$LOG_FILE"
    fi
fi
EOF
        fi

        # Make script executable
        chmod +x "$SCRIPT_DIR/clear_message.sh"

        # Create a script that sets the message and logs it
        if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
            # Setup Assistant mode - use system log
            tee "$SCRIPT_DIR/set_message_silent.sh" > /dev/null << EOF
#!/bin/bash
# Set the lock screen message silently
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"
echo "\$(date): Lock screen message set via LaunchDaemon" >> "/var/log/lockscreen_manager.log"
EOF
        else
            # Normal mode - use user log
            tee "$SCRIPT_DIR/set_message_silent.sh" > /dev/null << EOF
#!/bin/bash
# Set the lock screen message silently
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"
echo "\$(date): Lock screen message set via LaunchDaemon" >> "$USER_HOME/Library/Logs/lockscreen_manager.log"
EOF
        fi
        chmod +x "$SCRIPT_DIR/set_message_silent.sh"

        # Create LaunchDaemon for setting message with delay to ensure user session is ready
        tee /Library/LaunchDaemons/com.lockscreen.setmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>sleep 10 && defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" && echo "\$(date): Lock screen message set via LaunchDaemon" >> "$USER_HOME/Library/Logs/lockscreen_manager.log"</string>
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
        # Running as regular user, use sudo
        # Create the clear message script with proper user context
        sudo tee "$SCRIPT_DIR/clear_message.sh" > /dev/null << EOF
#!/bin/bash
LOG_FILE="$USER_HOME/Library/Logs/lockscreen_manager.log"

# Ensure log directory exists
mkdir -p "\$(dirname "\$LOG_FILE")"

# Check if this was triggered by a startup or shutdown event
if [[ -f /private/var/run/com.apple.shutdown.started ]]; then
    TRIGGER="shutdown event"
    SHOULD_CLEAR=true
elif [[ -f /private/var/run/com.apple.reboot.started ]]; then
    TRIGGER="reboot event"
    SHOULD_CLEAR=true
elif [[ -n "\$LAUNCH_EVENT" ]]; then
    TRIGGER="system event (\$LAUNCH_EVENT)"
    SHOULD_CLEAR=true
elif [[ "\$1" == "startup" ]]; then
    TRIGGER="startup event"
    # Only clear at startup if no user is logged in (FileVault unlock scenario)
    if [[ -n "\$(stat -f%Su /dev/console 2>/dev/null | grep -v root)" ]]; then
        SHOULD_CLEAR=false
        echo "\$(date): Startup event detected with logged in user - skipping clear" >> "\$LOG_FILE"
    else
        SHOULD_CLEAR=true
    fi
else
    TRIGGER="manual clear"
    SHOULD_CLEAR=true
fi

# Clear the lock screen message only if needed
if [[ "\$SHOULD_CLEAR" == "true" ]]; then
    if defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null; then
        echo "\$(date): Lock screen message cleared (\$TRIGGER)" >> "\$LOG_FILE"
    else
        echo "\$(date): Lock screen message was already cleared (\$TRIGGER)" >> "\$LOG_FILE"
    fi
fi
EOF

        # Make script executable
        sudo chmod +x "$SCRIPT_DIR/clear_message.sh"

        # Create a script that sets the message and logs it
        sudo tee "$SCRIPT_DIR/set_message_silent.sh" > /dev/null << EOF
#!/bin/bash
# Set the lock screen message silently
defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"
echo "\$(date): Lock screen message set via LaunchDaemon" >> "$USER_HOME/Library/Logs/lockscreen_manager.log"
EOF
        sudo chmod +x "$SCRIPT_DIR/set_message_silent.sh"

        # Create LaunchDaemon for setting message with delay to ensure user session is ready
        sudo tee /Library/LaunchDaemons/com.lockscreen.setmessage.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>sleep 10 && defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE" && echo "\$(date): Lock screen message set via LaunchDaemon" >> "$USER_HOME/Library/Logs/lockscreen_manager.log"</string>
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

    # Create special LaunchDaemon for Setup Assistant mode (triggers when first user is created)
    if [[ $EUID -eq 0 ]] && [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
        # Create a script that sets up the LaunchAgent when first user is created
        tee "$SCRIPT_DIR/setup_assistant_handler.sh" > /dev/null << EOF
#!/bin/bash
# This script runs when the first user is created during Setup Assistant
# It only creates the LaunchAgent - the message will be set on first login

# Create a LaunchAgent for the newly created user
FIRST_USER=\$(stat -f%Su /dev/console 2>/dev/null || echo "")
if [[ -n "\$FIRST_USER" ]] && [[ "\$FIRST_USER" != "root" ]]; then
    USER_HOME=\$(eval echo "~\$FIRST_USER")
    LAUNCH_AGENTS_DIR="\$USER_HOME/Library/LaunchAgents"
    
    # Create LaunchAgent directory
    mkdir -p "\$LAUNCH_AGENTS_DIR"
    chown -R "\$FIRST_USER" "\$LAUNCH_AGENTS_DIR"
    
    # Create LaunchAgent for the new user that will set message after successful login
    tee "\$LAUNCH_AGENTS_DIR/com.lockscreen.setmessage.plist" > /dev/null << 'LAUNCHAGENT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setmessage</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/defaults</string>
        <string>write</string>
        <string>/Library/Preferences/com.apple.loginwindow</string>
        <string>LoginwindowText</string>
        <string>$LOCK_MESSAGE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_set.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_set.log</string>
    <key>LimitLoadToSessionType</key>
    <array>
        <string>Aqua</string>
    </array>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
LAUNCHAGENT_EOF
    
    # Set proper permissions
    chown "\$FIRST_USER" "\$LAUNCH_AGENTS_DIR/com.lockscreen.setmessage.plist"
    chmod 644 "\$LAUNCH_AGENTS_DIR/com.lockscreen.setmessage.plist"
    
    # Load the LaunchAgent for the new user
    sudo -u "\$FIRST_USER" launchctl load "\$LAUNCH_AGENTS_DIR/com.lockscreen.setmessage.plist" 2>/dev/null
    
    echo "\$(date): LaunchAgent created and loaded for user \$FIRST_USER (message will be set on first login)" >> "/var/log/lockscreen_manager.log"
fi
EOF
        chmod +x "$SCRIPT_DIR/setup_assistant_handler.sh"

        # Create LaunchDaemon that watches for user creation
        tee /Library/LaunchDaemons/com.lockscreen.setupassistant.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lockscreen.setupassistant</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/setup_assistant_handler.sh</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/Users</string>
    </array>
    <key>StandardOutPath</key>
    <string>/tmp/lockscreen_setup.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/lockscreen_setup.log</string>
</dict>
</plist>
EOF
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
    fi

    # Create LaunchDaemon for shutdown detection and startup clearing
    if [[ $EUID -eq 0 ]]; then
        # Running as root, use tee directly
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
        <string>startup</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
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
        # Running as regular user, use sudo
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
        <string>startup</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
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

    # Set proper permissions
    if [[ $EUID -eq 0 ]]; then
        # Running as root
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        chown root:wheel /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        chmod 644 /Library/LaunchDaemons/com.lockscreen.setmessage.plist
    else
        # Running as regular user
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo chown root:wheel /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo chmod 644 /Library/LaunchDaemons/com.lockscreen.setmessage.plist
    fi

    # Load the LaunchDaemons
    if [[ $EUID -eq 0 ]]; then
        # Running as root
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

        # Load Setup Assistant LaunchDaemon if in Setup Assistant mode
        if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
            if launchctl bootstrap system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null; then
                echo "✓ Setup Assistant LaunchDaemon loaded successfully"
            else
                echo "⚠ Warning: Failed to load Setup Assistant LaunchDaemon (may already be loaded)"
            fi
        fi
    else
        # Running as regular user
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
    fi

    # Set the message immediately after installation (except in Setup Assistant mode)
    if [[ $EUID -eq 0 ]]; then
        if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
            echo "✓ Setup Assistant mode: Message will be set on first user login"
        else
            if defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText "$LOCK_MESSAGE"; then
                echo "✓ Lock screen message set immediately"
            else
                echo "⚠ Warning: Failed to set message immediately"
            fi
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
    if [[ $EUID -eq 0 ]]; then
        if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
            echo "   Mode: Setup Assistant (waiting for first user)"
        else
            echo "   User: $LOGGED_IN_USER"
        fi
    fi
    echo ""
    echo "🔄 The system will now:"
    if [[ "$SETUP_ASSISTANT_MODE" == "true" ]]; then
        echo "   • Create a LaunchAgent when the first user is created"
        echo "   • Set the message when the user logs in for the first time"
        echo "   • Clear the message before shutdown/restart"
    else
        echo "   • Set the message once per login session"
        echo "   • Clear the message before shutdown/restart"
    fi


    # Validate installation for MDM deployment
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

    if [[ ! -x "$SCRIPT_DIR/set_message_silent.sh" ]]; then
        echo "❌ Error: Set message script not executable"
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
    fi

    # Check if LaunchDaemons are loaded (different contexts for root vs user)
    if [[ $EUID -eq 0 ]]; then
        # Running as root - check system context
        if ! launchctl list | grep -q "com.lockscreen.setmessage"; then
            echo "❌ Error: Set message LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi

        if ! launchctl list | grep -q "com.lockscreen.clearmessage"; then
            echo "❌ Error: Clear message LaunchDaemon not loaded"
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi
    else
        # Running as regular user - check system context with sudo
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

    # Detect if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "Running as root"
        
        # Get the currently logged in user
        LOGGED_IN_USER=$(stat -f%Su /dev/console 2>/dev/null || echo "")
        
        if [[ -n "$LOGGED_IN_USER" ]] && [[ "$LOGGED_IN_USER" != "root" ]]; then
            USER_HOME=$(eval echo "~$LOGGED_IN_USER")
            
            # Unload services
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null

            # Remove files
            rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
            rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
            rm -f /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
            rm -rf "$SCRIPT_DIR"
        else
            # No user logged in, just remove system files
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null
            launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null
            rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
            rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
            rm -f /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
            rm -rf "$SCRIPT_DIR"
        fi
    else
        # Running as regular user
        echo "Running as regular user"
        
        # Unload services
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setmessage.plist 2>/dev/null
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.clearmessage.plist 2>/dev/null
        sudo launchctl bootout system /Library/LaunchDaemons/com.lockscreen.setupassistant.plist 2>/dev/null

        # Remove files
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.clearmessage.plist
        sudo rm -f /Library/LaunchDaemons/com.lockscreen.setupassistant.plist
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
    
    # Detect if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "Running as root"
        
        # Get the currently logged in user
        LOGGED_IN_USER=$(stat -f%Su /dev/console 2>/dev/null || echo "")
        
        if [[ -n "$LOGGED_IN_USER" ]] && [[ "$LOGGED_IN_USER" != "root" ]]; then
            USER_HOME=$(eval echo "~$LOGGED_IN_USER")
            LOG_FILE="$USER_HOME/Library/Logs/lockscreen_manager.log"
            
            echo "Detected logged in user: $LOGGED_IN_USER"
            
            # Check if files exist
            if [[ -f "/Library/LaunchDaemons/com.lockscreen.setmessage.plist" ]]; then
                echo "✅ Set message LaunchDaemon: Installed"
            else
                echo "❌ Set message LaunchDaemon: Not installed"
            fi
        else
            echo "❌ No user currently logged in"
        fi
    else
        # Running as regular user
        echo "Running as regular user"
        
        # Check if files exist
        if [[ -f "/Library/LaunchDaemons/com.lockscreen.setmessage.plist" ]]; then
            echo "✅ Set message LaunchDaemon: Installed"
        else
            echo "❌ Set message LaunchDaemon: Not installed"
        fi
    fi
    
    if [[ -f "/Library/LaunchDaemons/com.lockscreen.clearmessage.plist" ]]; then
        echo "✅ LaunchDaemon: Installed"
    else
        echo "❌ LaunchDaemon: Not installed"
    fi
    
    # Check current lock screen message
    if [[ $EUID -eq 0 ]]; then
        CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    else
        CURRENT_MESSAGE=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null)
    fi
    
    if [[ -n "$CURRENT_MESSAGE" ]]; then
        echo "🔒 Current message: $CURRENT_MESSAGE"
    else
        echo "🔓 No lock screen message currently set"
    fi
    
    # Check log file
    if [[ $EUID -eq 0 ]] && [[ -n "$LOGGED_IN_USER" ]] && [[ "$LOGGED_IN_USER" != "root" ]]; then
        LOG_FILE="$USER_HOME/Library/Logs/lockscreen_manager.log"
    fi
    
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
        echo "  • Automatically sets message after login (emojis work perfectly)"
        echo "  • Automatically clears message before shutdown/restart"
        echo "  • Avoids FileVault emoji display issues"
        echo "  • Comprehensive logging and status monitoring"
        echo ""
        echo "📝 Example: $0 (runs install by default)"
        exit 1
        ;;
esac
