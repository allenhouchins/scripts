#!/bin/bash

# =============================================================================
# CLOUDFLARE WARP INSTALLER WITH LAUNCHAGENT
# =============================================================================

# Configuration
WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_PKG_PATH="/tmp/cloudflare-warp.pkg"
LAUNCHAGENT_PLIST="/Library/LaunchAgents/com.cloudflare.warp.installer.plist"
INSTALL_SCRIPT="/usr/local/bin/cloudflare-warp-install.sh"
LOG_FILE="/var/log/cloudflare-warp-installer.log"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run with sudo privileges."
        exit 1
    fi
}

create_directories() {
    log_message "Creating necessary directories..."
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$INSTALL_SCRIPT")"
    mkdir -p "$(dirname "$LAUNCHAGENT_PLIST")"
}

# =============================================================================
# WARP INSTALLATION FUNCTIONS
# =============================================================================

download_warp() {
    log_message "Downloading Cloudflare WARP from $WARP_DOWNLOAD_URL..."
    
    if curl -L -o "$WARP_PKG_PATH" "$WARP_DOWNLOAD_URL"; then
        log_message "Successfully downloaded WARP package to $WARP_PKG_PATH"
        return 0
    else
        log_message "ERROR: Failed to download WARP package"
        return 1
    fi
}

install_warp() {
    log_message "Installing Cloudflare WARP package..."
    
    if installer -pkg "$WARP_PKG_PATH" -target /; then
        log_message "Successfully installed Cloudflare WARP"
        return 0
    else
        log_message "ERROR: Failed to install WARP package"
        return 1
    fi
}

cleanup() {
    log_message "Cleaning up temporary files..."
    rm -f "$WARP_PKG_PATH"
}

# =============================================================================
# LAUNCHAGENT FUNCTIONS
# =============================================================================

create_install_script() {
    log_message "Creating installation script at $INSTALL_SCRIPT..."
    
    cat > "$INSTALL_SCRIPT" << 'EOF'
#!/bin/bash

# Cloudflare WARP Installation Script
# This script is executed by the LaunchAgent

LOG_FILE="/var/log/cloudflare-warp-installer.log"
WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_PKG_PATH="/tmp/cloudflare-warp.pkg"

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Wait for user to be at desktop (check for Finder and Dock processes)
wait_for_desktop() {
    log_message "Waiting for user desktop to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Check for both Finder and Dock processes (indicates full desktop environment)
        if pgrep -f "Finder" > /dev/null && pgrep -f "Dock" > /dev/null; then
            log_message "Desktop environment detected - Finder and Dock are running"
            # Additional check: ensure we can access user's home directory
            if [[ -d "$HOME" && -w "$HOME" ]]; then
                log_message "User home directory accessible - desktop is ready"
                sleep 3  # Give a bit more time for desktop to fully load
                return 0
            fi
        fi
        
        log_message "Desktop not yet ready, attempt $((attempt + 1))/$max_attempts"
        sleep 5
        ((attempt++))
    done
    
    log_message "WARNING: Desktop environment not detected after $max_attempts attempts"
    return 1
}

# Check if WARP is already installed
is_warp_installed() {
    if [[ -d "/Applications/Cloudflare WARP.app" ]] || [[ -f "/usr/local/bin/warp-cli" ]]; then
        return 0
    fi
    return 1
}

# Main installation logic
main() {
    log_message "Starting Cloudflare WARP installation process..."
    
    # Wait for user to be at desktop
    if ! wait_for_desktop; then
        log_message "ERROR: Could not detect user desktop, aborting installation"
        exit 1
    fi
    
    # Check if already installed
    if is_warp_installed; then
        log_message "Cloudflare WARP is already installed, skipping installation"
        exit 0
    fi
    
    # Download WARP
    log_message "Downloading Cloudflare WARP..."
    if ! curl -L -o "$WARP_PKG_PATH" "$WARP_DOWNLOAD_URL"; then
        log_message "ERROR: Failed to download WARP package"
        exit 1
    fi
    
    # Install WARP
    log_message "Installing Cloudflare WARP..."
    if installer -pkg "$WARP_PKG_PATH" -target /; then
        log_message "Successfully installed Cloudflare WARP"
    else
        log_message "ERROR: Failed to install WARP package"
        exit 1
    fi
    
    # Cleanup
    rm -f "$WARP_PKG_PATH"
    log_message "Installation completed successfully"
    
    # Spawn a separate process to unload and remove the LaunchAgent
    log_message "Spawning cleanup process to remove LaunchAgent..."
    nohup bash -c "
        sleep 2
        echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Unloading LaunchAgent...' >> $LOG_FILE
        
        # Try to unload using both methods
        if launchctl bootout gui/\$(id -u) '$LAUNCHAGENT_PLIST' 2>/dev/null; then
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: LaunchAgent unloaded successfully (bootstrap method)' >> $LOG_FILE
        elif launchctl unload '$LAUNCHAGENT_PLIST' 2>/dev/null; then
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: LaunchAgent unloaded successfully (traditional method)' >> $LOG_FILE
        else
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Warning - could not unload LaunchAgent (may not be loaded)' >> $LOG_FILE
        fi
        
        echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Removing LaunchAgent plist...' >> $LOG_FILE
        if rm -f '$LAUNCHAGENT_PLIST'; then
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: LaunchAgent plist removed successfully' >> $LOG_FILE
        else
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Warning - could not remove LaunchAgent plist' >> $LOG_FILE
        fi
        
        # Verify cleanup
        if [[ ! -f '$LAUNCHAGENT_PLIST' ]]; then
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: LaunchAgent cleanup completed successfully' >> $LOG_FILE
        else
            echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Warning - LaunchAgent plist still exists' >> $LOG_FILE
        fi
    " > /dev/null 2>&1 &
}

# Run main function
main "$@"
EOF

    chmod +x "$INSTALL_SCRIPT"
    log_message "Installation script created and made executable"
}

create_launchagent_plist() {
    log_message "Creating LaunchAgent plist at $LAUNCHAGENT_PLIST..."
    
    cat > "$LAUNCHAGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudflare.warp.installer</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_SCRIPT</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <false/>
    
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF

    log_message "LaunchAgent plist created"
}

load_launchagent() {
    log_message "Loading LaunchAgent..."
    
    # Ensure proper permissions on the LaunchAgent file
    chown root:wheel "$LAUNCHAGENT_PLIST"
    chmod 644 "$LAUNCHAGENT_PLIST"
    
    # Try multiple loading methods for better compatibility
    local loaded=false
    
    # Method 1: Bootstrap with user context (modern approach)
    if [[ -n "$SUDO_USER" ]]; then
        log_message "Attempting to load LaunchAgent in user context for user: $SUDO_USER"
        if launchctl bootstrap gui/$(id -u "$SUDO_USER") "$LAUNCHAGENT_PLIST" 2>/dev/null; then
            log_message "LaunchAgent loaded successfully in user context (bootstrap method)"
            loaded=true
        fi
    fi
    
    # Method 2: Traditional load method
    if [[ "$loaded" == false ]]; then
        log_message "Trying traditional load method..."
        if launchctl load "$LAUNCHAGENT_PLIST" 2>/dev/null; then
            log_message "LaunchAgent loaded successfully (traditional method)"
            loaded=true
        fi
    fi
    
    # Method 3: Bootstrap in system context (fallback)
    if [[ "$loaded" == false ]]; then
        log_message "Trying bootstrap in system context..."
        if launchctl bootstrap system "$LAUNCHAGENT_PLIST" 2>/dev/null; then
            log_message "LaunchAgent loaded successfully in system context (bootstrap method)"
            loaded=true
        fi
    fi
    
    if [[ "$loaded" == true ]]; then
        log_message "WARP will be installed automatically when the next user logs in and reaches their desktop"
        return 0
    else
        log_message "ERROR: Failed to load LaunchAgent with all methods"
        log_message "You may need to manually load it or check system permissions"
        return 1
    fi
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

install_now() {
    log_message "Installing Cloudflare WARP immediately..."
    
    if download_warp && install_warp; then
        log_message "WARP installed successfully"
        cleanup
        return 0
    else
        log_message "ERROR: Failed to install WARP"
        cleanup
        return 1
    fi
}

setup_launchagent() {
    log_message "Setting up LaunchAgent for automatic WARP installation..."
    
    create_directories
    create_install_script
    create_launchagent_plist
    
    if load_launchagent; then
        log_message "LaunchAgent setup completed successfully"
        return 0
    else
        log_message "ERROR: Failed to setup LaunchAgent"
        return 1
    fi
}

uninstall_launchagent() {
    log_message "Uninstalling LaunchAgent..."
    
    # Try to unload using both methods
    if launchctl bootout gui/$(id -u) "$LAUNCHAGENT_PLIST" 2>/dev/null; then
        log_message "LaunchAgent unloaded successfully (bootstrap method)"
    elif launchctl unload "$LAUNCHAGENT_PLIST" 2>/dev/null; then
        log_message "LaunchAgent unloaded successfully (traditional method)"
    else
        log_message "Warning: Could not unload LaunchAgent (may not be loaded)"
    fi
    
    # Remove files
    if rm -f "$LAUNCHAGENT_PLIST"; then
        log_message "LaunchAgent plist removed successfully"
    else
        log_message "Warning: Could not remove LaunchAgent plist"
    fi
    
    if rm -f "$INSTALL_SCRIPT"; then
        log_message "Installation script removed successfully"
    else
        log_message "Warning: Could not remove installation script"
    fi
    
    log_message "LaunchAgent uninstalled successfully"
}

show_help() {
    cat << EOF
Cloudflare WARP Installer with LaunchAgent

USAGE:
    $0 [OPTIONS]

OPTIONS:
    install-now      Install WARP immediately (requires user to be logged in)
    setup-agent      Setup LaunchAgent for automatic installation on next login
    uninstall-agent Remove the LaunchAgent (does not uninstall WARP)
    status           Show current status
    debug            Show detailed debugging information
    help             Show this help message

EXAMPLES:
    sudo $0 install-now      # Install WARP right now
    sudo $0 setup-agent      # Setup for automatic installation
    sudo $0 status           # Check current status
    sudo $0 debug            # Show detailed debugging info

DESCRIPTION:
    This script can install Cloudflare WARP either immediately or set up a
    LaunchAgent that will automatically install WARP when a user logs in and
    reaches their desktop.

    The LaunchAgent waits for the Finder and Dock processes to start (indicating
    user is at desktop) before attempting installation.

EOF
}

show_status() {
    echo "=== Cloudflare WARP Installer Status ==="
    echo
    
    # Check if WARP is installed
    if [[ -d "/Applications/Cloudflare WARP.app" ]] || [[ -f "/usr/local/bin/warp-cli" ]]; then
        echo "✅ Cloudflare WARP is installed"
    else
        echo "❌ Cloudflare WARP is not installed"
    fi
    
    # Check LaunchAgent status
    if [[ -f "$LAUNCHAGENT_PLIST" ]]; then
        echo "✅ LaunchAgent is configured"
        
        # Check if LaunchAgent is loaded in system context
        if launchctl list | grep -q "com.cloudflare.warp.installer"; then
            echo "✅ LaunchAgent is loaded in system context"
        else
            echo "⚠️  LaunchAgent is not loaded in system context"
        fi
        
        # Check if LaunchAgent is loaded in user context (if user is logged in)
        if [[ -n "$SUDO_USER" ]]; then
            echo "🔍 Checking user context for user: $SUDO_USER"
            if sudo -u "$SUDO_USER" launchctl list 2>/dev/null | grep -q "com.cloudflare.warp.installer"; then
                echo "✅ LaunchAgent is loaded in user context"
            else
                echo "⚠️  LaunchAgent is not loaded in user context"
            fi
        else
            echo "ℹ️  No user context to check (run as non-root user to check user context)"
        fi
        
        # Check LaunchAgent file permissions
        echo "📁 LaunchAgent file info:"
        ls -la "$LAUNCHAGENT_PLIST" | sed 's/^/    /'
        
    else
        echo "❌ LaunchAgent is not configured"
    fi
    
    # Check log file
    if [[ -f "$LOG_FILE" ]]; then
        echo "📄 Log file: $LOG_FILE"
        echo "📄 Last 5 log entries:"
        tail -5 "$LOG_FILE" | sed 's/^/    /'
    else
        echo "📄 No log file found"
    fi
}

show_debug() {
    echo "=== Cloudflare WARP Installer Debug Information ==="
    echo
    
    # System information
    echo "🖥️  System Information:"
    echo "    macOS Version: $(sw_vers -productVersion)"
    echo "    Architecture: $(uname -m)"
    echo "    Current User: $(whoami)"
    echo "    Sudo User: ${SUDO_USER:-'Not running as sudo'}"
    echo
    
    # LaunchAgent file details
    if [[ -f "$LAUNCHAGENT_PLIST" ]]; then
        echo "📄 LaunchAgent File Details:"
        echo "    Path: $LAUNCHAGENT_PLIST"
        echo "    Permissions: $(ls -la "$LAUNCHAGENT_PLIST" | awk '{print $1, $3, $4}')"
        echo "    Size: $(ls -lh "$LAUNCHAGENT_PLIST" | awk '{print $5}')"
        echo "    Content:"
        cat "$LAUNCHAGENT_PLIST" | sed 's/^/        /'
        echo
    else
        echo "❌ LaunchAgent file not found at $LAUNCHAGENT_PLIST"
        echo
    fi
    
    # Installation script details
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        echo "📜 Installation Script Details:"
        echo "    Path: $INSTALL_SCRIPT"
        echo "    Permissions: $(ls -la "$INSTALL_SCRIPT" | awk '{print $1, $3, $4}')"
        echo "    Size: $(ls -lh "$INSTALL_SCRIPT" | awk '{print $5}')"
        echo
    else
        echo "❌ Installation script not found at $INSTALL_SCRIPT"
        echo
    fi
    
    # LaunchAgent loading status
    echo "🔍 LaunchAgent Loading Status:"
    echo "    System context:"
    if launchctl list | grep -q "com.cloudflare.warp.installer"; then
        echo "        ✅ Loaded in system context"
        launchctl list | grep "com.cloudflare.warp.installer" | sed 's/^/            /'
    else
        echo "        ❌ Not loaded in system context"
    fi
    
    # Check user context if available
    if [[ -n "$SUDO_USER" ]]; then
        echo "    User context ($SUDO_USER):"
        if sudo -u "$SUDO_USER" launchctl list 2>/dev/null | grep -q "com.cloudflare.warp.installer"; then
            echo "        ✅ Loaded in user context"
            sudo -u "$SUDO_USER" launchctl list 2>/dev/null | grep "com.cloudflare.warp.installer" | sed 's/^/            /'
        else
            echo "        ❌ Not loaded in user context"
        fi
    else
        echo "    User context: Cannot check (not running as sudo)"
    fi
    echo
    
    # Directory permissions
    echo "📁 Directory Permissions:"
    echo "    /Library/LaunchAgents: $(ls -ld /Library/LaunchAgents | awk '{print $1, $3, $4}')"
    echo "    /usr/local/bin: $(ls -ld /usr/local/bin | awk '{print $1, $3, $4}')"
    echo "    /var/log: $(ls -ld /var/log | awk '{print $1, $3, $4}')"
    echo
    
    # Log file information
    if [[ -f "$LOG_FILE" ]]; then
        echo "📄 Log File Information:"
        echo "    Path: $LOG_FILE"
        echo "    Size: $(ls -lh "$LOG_FILE" | awk '{print $5}')"
        echo "    Last modified: $(ls -l "$LOG_FILE" | awk '{print $6, $7, $8}')"
        echo "    Last 10 entries:"
        tail -10 "$LOG_FILE" | sed 's/^/        /'
    else
        echo "❌ Log file not found at $LOG_FILE"
    fi
    echo
    
    # Suggested troubleshooting steps
    echo "🔧 Troubleshooting Suggestions:"
    if [[ -f "$LAUNCHAGENT_PLIST" ]] && ! launchctl list | grep -q "com.cloudflare.warp.installer"; then
        echo "    1. Try reloading the LaunchAgent:"
        echo "       sudo launchctl unload '$LAUNCHAGENT_PLIST' 2>/dev/null || true"
        echo "       sudo launchctl load '$LAUNCHAGENT_PLIST'"
        echo
        echo "    2. Check if the LaunchAgent file has correct permissions:"
        echo "       sudo chown root:wheel '$LAUNCHAGENT_PLIST'"
        echo "       sudo chmod 644 '$LAUNCHAGENT_PLIST'"
        echo
        echo "    3. Verify the installation script is executable:"
        echo "       sudo chmod +x '$INSTALL_SCRIPT'"
        echo
    fi
    
    if [[ -n "$SUDO_USER" ]] && ! sudo -u "$SUDO_USER" launchctl list 2>/dev/null | grep -q "com.cloudflare.warp.installer"; then
        echo "    4. The LaunchAgent may need to be loaded in user context:"
        echo "       sudo -u '$SUDO_USER' launchctl load '$LAUNCHAGENT_PLIST'"
        echo
    fi
}

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

main() {
    case "${1:-setup-agent}" in
        "install-now")
            check_sudo
            install_now
            ;;
        "setup-agent")
            check_sudo
            setup_launchagent
            ;;
        "uninstall-agent")
            check_sudo
            uninstall_launchagent
            ;;
        "status")
            show_status
            ;;
        "debug")
            show_debug
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "ERROR: Unknown option '$1'"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
