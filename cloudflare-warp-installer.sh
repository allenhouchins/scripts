#!/bin/bash

# =============================================================================
# CLOUDFLARE WARP INSTALLER WITH LAUNCHAGENT
# =============================================================================

# Configuration
WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_PKG_PATH="/tmp/cloudflare-warp.pkg"
LAUNCHDAEMON_PLIST="/Library/LaunchDaemons/com.cloudflare.warp.installer.plist"
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
    mkdir -p "$(dirname "$LAUNCHDAEMON_PLIST")"
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

# Wait for Dock to be running (indicates user is logged in and at desktop)
wait_for_dock() {
    log_message "Waiting for Dock process to start (user login indicator)..."
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if pgrep -f "Dock" > /dev/null; then
            log_message "Dock process detected - user is logged in"
            sleep 5  # Give a bit more time for desktop to fully load
            return 0
        fi
        
        log_message "Dock not yet running, attempt $((attempt + 1))/$max_attempts"
        sleep 10
        ((attempt++))
    done
    
    log_message "WARNING: Dock process not detected after $max_attempts attempts"
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
    
    # Wait for user to be logged in
    if ! wait_for_dock; then
        log_message "ERROR: Could not detect user login, aborting installation"
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
    
    # Spawn a separate process to unload and remove the LaunchDaemon
    log_message "Spawning cleanup process to remove LaunchDaemon..."
    nohup bash -c "
        sleep 2
        echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Unloading LaunchDaemon...' >> $LOG_FILE
        launchctl unload '$LAUNCHDAEMON_PLIST' 2>/dev/null || true
        echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: Removing LaunchDaemon plist...' >> $LOG_FILE
        rm -f '$LAUNCHDAEMON_PLIST'
        echo '[\$(date \"+%Y-%m-%d %H:%M:%S\")] Cleanup process: LaunchDaemon cleanup completed' >> $LOG_FILE
    " > /dev/null 2>&1 &
}

# Run main function
main "$@"
EOF

    chmod +x "$INSTALL_SCRIPT"
    log_message "Installation script created and made executable"
}

create_launchdaemon_plist() {
    log_message "Creating LaunchDaemon plist at $LAUNCHDAEMON_PLIST..."
    
    cat > "$LAUNCHDAEMON_PLIST" << EOF
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
</dict>
</plist>
EOF

    log_message "LaunchDaemon plist created"
}

load_launchdaemon() {
    log_message "Loading LaunchDaemon..."
    
    if launchctl load "$LAUNCHDAEMON_PLIST"; then
        log_message "LaunchDaemon loaded successfully"
        log_message "WARP will be installed automatically when the next user logs in"
    else
        log_message "ERROR: Failed to load LaunchDaemon"
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

setup_launchdaemon() {
    log_message "Setting up LaunchDaemon for automatic WARP installation..."
    
    create_directories
    create_install_script
    create_launchdaemon_plist
    
    if load_launchdaemon; then
        log_message "LaunchDaemon setup completed successfully"
        return 0
    else
        log_message "ERROR: Failed to setup LaunchDaemon"
        return 1
    fi
}

uninstall_launchdaemon() {
    log_message "Uninstalling LaunchDaemon..."
    
    # Unload the LaunchDaemon
    launchctl unload "$LAUNCHDAEMON_PLIST" 2>/dev/null || true
    
    # Remove files
    rm -f "$LAUNCHDAEMON_PLIST"
    rm -f "$INSTALL_SCRIPT"
    
    log_message "LaunchDaemon uninstalled successfully"
}

show_help() {
    cat << EOF
Cloudflare WARP Installer with LaunchDaemon

USAGE:
    $0 [OPTIONS]

OPTIONS:
    install-now      Install WARP immediately (requires user to be logged in)
    setup-daemon     Setup LaunchDaemon for automatic installation on next login
    uninstall-daemon Remove the LaunchDaemon (does not uninstall WARP)
    status           Show current status
    help             Show this help message

EXAMPLES:
    sudo $0 install-now      # Install WARP right now
    sudo $0 setup-daemon     # Setup for automatic installation
    sudo $0 status           # Check current status

DESCRIPTION:
    This script can install Cloudflare WARP either immediately or set up a
    LaunchDaemon that will automatically install WARP when a user logs in and
    reaches their desktop.

    The LaunchDaemon waits for the Dock process to start (indicating user login)
    before attempting installation.

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
    
    # Check LaunchDaemon status
    if [[ -f "$LAUNCHDAEMON_PLIST" ]]; then
        echo "✅ LaunchDaemon is configured"
        if launchctl list | grep -q "com.cloudflare.warp.installer"; then
            echo "✅ LaunchDaemon is loaded and active"
        else
            echo "⚠️  LaunchDaemon is configured but not loaded"
        fi
    else
        echo "❌ LaunchDaemon is not configured"
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

# =============================================================================
# MAIN SCRIPT LOGIC
# =============================================================================

main() {
    case "${1:-help}" in
        "install-now")
            check_sudo
            install_now
            ;;
        "setup-daemon")
            check_sudo
            setup_launchdaemon
            ;;
        "uninstall-daemon")
            check_sudo
            uninstall_launchdaemon
            ;;
        "status")
            show_status
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
