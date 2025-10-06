#!/bin/bash

# Minimal Cloudflare WARP installer bootstrapper
# - Run as root during Setup Assistant
# - Creates a LaunchDaemon that runs as root when first user logs in
# - Daemon downloads WARP pkg to /tmp and installs it as root
# - After success, daemon asynchronously unloads and removes its plist

set -euo pipefail

WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_PKG_PATH="/tmp/cloudflare-warp.pkg"
LAUNCHDAEMON_PLIST="/Library/LaunchDaemons/com.cloudflare.warp.installer.plist"
INSTALL_SCRIPT="/usr/local/bin/cloudflare-warp-install.sh"

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

mkdir -p "$(dirname "$INSTALL_SCRIPT")"
mkdir -p "$(dirname "$LAUNCHDAEMON_PLIST")"

# Create the installer that the LaunchDaemon will run as root
cat > "$INSTALL_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

WARP_DOWNLOAD_URL="https://downloads.cloudflareclient.com/v1/download/macos/ga"
WARP_PKG_PATH="/tmp/cloudflare-warp.pkg"
LAUNCHDAEMON_PLIST="/Library/LaunchDaemons/com.cloudflare.warp.installer.plist"
INSTALL_SCRIPT="/usr/local/bin/cloudflare-warp-install.sh"

# Wait for first user to log in and reach desktop
wait_for_user_desktop() {
    while true; do
        local console_user
        console_user=$(stat -f%Su /dev/console 2>/dev/null || echo "")
        if [[ -n "$console_user" && "$console_user" != "root" && "$console_user" != "loginwindow" ]]; then
            if pgrep -u "$console_user" Dock >/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 5
    done
}

# Wait for user desktop, then download and install
if wait_for_user_desktop; then
    # Download WARP pkg
    curl -L -o "$WARP_PKG_PATH" "$WARP_DOWNLOAD_URL"
    
    # Install WARP
    if installer -pkg "$WARP_PKG_PATH" -target /; then
        rm -f "$WARP_PKG_PATH"
        # Create a detached cleanup script
        cat > /tmp/cloudflare-cleanup.sh << 'CLEANUP_EOF'
#!/bin/bash
sleep 3
launchctl bootout system '/Library/LaunchDaemons/com.cloudflare.warp.installer.plist' 2>/dev/null || launchctl unload '/Library/LaunchDaemons/com.cloudflare.warp.installer.plist' 2>/dev/null || true
rm -f '/Library/LaunchDaemons/com.cloudflare.warp.installer.plist' 2>/dev/null || true
sleep 2
rm -f '/usr/local/bin/cloudflare-warp-install.sh' 2>/dev/null || true
rm -f '/tmp/cloudflare-cleanup.sh' 2>/dev/null || true
CLEANUP_EOF
        chmod +x /tmp/cloudflare-cleanup.sh
        nohup /tmp/cloudflare-cleanup.sh >/dev/null 2>&1 &
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi
EOF

chmod +x "$INSTALL_SCRIPT"
chown root:wheel "$INSTALL_SCRIPT"

# Create LaunchDaemon that runs as root
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
</dict>
</plist>
EOF

chown root:wheel "$LAUNCHDAEMON_PLIST"
chmod 644 "$LAUNCHDAEMON_PLIST"

# Load the LaunchDaemon
launchctl bootstrap system "$LAUNCHDAEMON_PLIST" 2>/dev/null || launchctl load "$LAUNCHDAEMON_PLIST" 2>/dev/null || true

echo "Cloudflare WARP LaunchDaemon installed and loaded. It will run when the first user logs in."