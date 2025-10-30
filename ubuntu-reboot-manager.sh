#!/bin/bash

# Ubuntu Reboot Management Script
# Purpose: Monitor system uptime and enforce periodic reboots
# Requirements: systemd (service + timer)
# Default: On first run, auto-install to /usr/local/sbin and install/enable systemd timer

# Configuration (env-overridable for testing)
WARNING_DAYS=${WARNING_DAYS:-10}
FORCED_REBOOT_DAYS=${FORCED_REBOOT_DAYS:-14}
LOG_FILE="/var/log/reboot-manager.log"
SCRIPT_NAME="Reboot Manager"


# Function to log messages
log_message() {
	local line
	line="$(date '+%Y-%m-%d %H:%M:%S') - $1"
	echo "$line" >> "$LOG_FILE"
    echo "$line"
}

# Function to get uptime in days
get_uptime_days() {
    # Allow test override via env: UPTIME_DAYS=<int>
    if [ -n "${UPTIME_DAYS:-}" ]; then
        echo "$UPTIME_DAYS"
        return 0
    fi
    local uptime_seconds
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    echo $((uptime_seconds / 86400))
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID" | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Auto-install notify-send (libnotify) when missing
install_notify_send() {
	local distro
	distro=$(detect_distro)

	case "$distro" in
		ubuntu|debian)
			if command -v apt-get >/dev/null 2>&1; then
				apt-get update -qq && apt-get install -y -qq libnotify-bin && return 0
			fi
			;;
		fedora|rhel|centos)
			if command -v dnf >/dev/null 2>&1; then
				dnf install -y -q libnotify && return 0
			elif command -v yum >/dev/null 2>&1; then
				yum install -y -q libnotify && return 0
			fi
			;;
		arch|manjaro)
			if command -v pacman >/dev/null 2>&1; then
				pacman -Sy --noconfirm libnotify && return 0
			fi
			;;
		*)
			return 1
			;;
	esac

	return 1
}

# Function to send notification to all logged-in user sessions
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="$3" # low|normal|critical

    # Require libnotify/notify-send
    if ! command -v notify-send >/dev/null 2>&1; then
        wall "NOTIFICATION: $message"
        log_message "notify-send not found; sent wall notification"
        return 0
    fi

    # Optional: allow admin to force a specific user via TARGET_USER or TARGET_UID
    if [ -n "${TARGET_USER:-}" ] || [ -n "${TARGET_UID:-}" ]; then
        local uid
        if [ -n "${TARGET_UID:-}" ]; then
            uid="$TARGET_UID"
        else
            uid=$(id -u "$TARGET_USER" 2>/dev/null || true)
        fi
        if [ -n "$uid" ]; then
            # Try Wayland then X11
            local env_try1="XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus WAYLAND_DISPLAY=wayland-0"
            local env_try2="XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus DISPLAY=:0"
            if eval sudo -u "#$uid" $env_try1 notify-send --urgency="${urgency:-normal}" "$title" "$message" 2>/dev/null; then
                log_message "GUI notification sent to TARGET_UID=$uid via Wayland"
                return 0
            fi
            if eval sudo -u "#$uid" $env_try2 notify-send --urgency="${urgency:-normal}" "$title" "$message" 2>/dev/null; then
                log_message "GUI notification sent to TARGET_UID=$uid via X11"
                return 0
            fi
            log_message "Failed TARGET_USER/TARGET_UID notification attempts; will try session discovery"
        fi
    fi

    # Enumerate sessions and target only active graphical sessions
    local sent_any=0
    while read -r sid uid; do
        [ -z "$sid" ] && continue
        # Query session properties
        local stype sactive sdisplay
        stype=$(loginctl show-session "$sid" -p Type 2>/dev/null | awk -F= '{print $2}')
        sactive=$(loginctl show-session "$sid" -p Active 2>/dev/null | awk -F= '{print $2}')
        sdisplay=$(loginctl show-session "$sid" -p Display 2>/dev/null | awk -F= '{print $2}')

        # Only X11/Wayland and active sessions
        if [ "$sactive" != "yes" ]; then
            continue
        fi
        if [ "$stype" != "x11" ] && [ "$stype" != "wayland" ]; then
            continue
        fi

        # Preferred: execute via the user's systemd user manager (auto-wires DBUS)
        if sudo -u "#$uid" XDG_RUNTIME_DIR="/run/user/$uid" systemd-run --user --collect \
            --unit "reboot-notify-$(date +%s%N)" notify-send --urgency="${urgency:-normal}" "$title" "$message" 2>/dev/null; then
            sent_any=1
        else
            # Fallback: build environment for the user's session bus and display
            local env_cmd="XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
            if [ "$stype" = "x11" ]; then
                if [ -n "$sdisplay" ]; then
                    env_cmd="$env_cmd DISPLAY=$sdisplay"
                elif [ -e /tmp/.X11-unix/X0 ]; then
                    env_cmd="$env_cmd DISPLAY=:0"
                fi
            else
                if [ -e "/run/user/$uid/wayland-0" ]; then
                    env_cmd="$env_cmd WAYLAND_DISPLAY=wayland-0"
                fi
            fi
            if eval sudo -u "#$uid" $env_cmd notify-send --urgency="${urgency:-normal}" "$title" "$message" 2>/dev/null; then
                sent_any=1
            fi
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1, $2}')

    if [ "$sent_any" = "1" ]; then
        log_message "GUI notifications sent via notify-send to active graphical sessions"
    else
        # Fallback 2: attempt to discover GUI env from common desktop processes
        for candidate in gnome-shell gnome-session-binary plasmashell startplasma-x11 startplasma-wayland xfce4-session cinnamon-session mate-session sway; do
            pid=$(pgrep -u 1000 -n "$candidate" 2>/dev/null || true)
            if [ -n "$pid" ]; then
                uid=$(awk '/Uid:/{print $2}' "/proc/$pid/status" 2>/dev/null)
                if [ -n "$uid" ]; then
                    # Extract env from the GUI process
                    gui_env=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -E '^(DISPLAY=|WAYLAND_DISPLAY=|DBUS_SESSION_BUS_ADDRESS=|XDG_RUNTIME_DIR=)')
                    if [ -n "$gui_env" ]; then
                        if eval sudo -u "#$uid" env $gui_env notify-send --urgency="${urgency:-normal}" "$title" "$message" 2>/dev/null; then
                            sent_any=1
                            log_message "GUI notification sent using environment from process $candidate (pid $pid)"
                            break
                        fi
                    fi
                fi
            fi
        done

        if [ "$sent_any" != "1" ]; then
            wall "NOTIFICATION: $message"
            log_message "Fell back to wall notification (no eligible GUI sessions or notify-send failure)"
        fi
    fi
}

# Function to show countdown notification
show_countdown_notification() {
    local days_left="$1"
    local title="System Reboot Required"
    local message="Your system has been running for $UPTIME_DAYS days.\nA reboot is required in $days_left day(s).\n\nPlease save your work and reboot when convenient."
    
    send_notification "$title" "$message" "normal"
}

# Function to show final warning
show_final_warning() {
    local title="URGENT: Immediate Reboot Required"
    local message="Your system has been running for $UPTIME_DAYS days.\n\nSystem will automatically reboot in 5 minutes!\n\nPlease save all work immediately!"
    
    send_notification "$title" "$message" "critical"
    
    # Show wall message to all terminals
    wall "URGENT: System will reboot in 5 minutes due to uptime policy ($UPTIME_DAYS days). Save your work now!"
}

# Function to perform forced reboot
perform_forced_reboot() {
    log_message "Initiating forced reboot after $UPTIME_DAYS days uptime"
    
    # Final warning with wall message
    wall "FINAL WARNING: System rebooting NOW due to uptime policy!"
    
    # Give users a moment to see the message
    sleep 5
    
    # Schedule immediate reboot (skip when DRY_RUN=1)
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_message "DRY_RUN enabled - skipping shutdown command"
    else
        shutdown -r +1 "Automated reboot: System uptime exceeded $FORCED_REBOOT_DAYS days policy"
    fi
    
    log_message "Reboot scheduled - system will restart in 1 minute"
    
    # Exit immediately after scheduling reboot to prevent further execution
    exit 0
}

## systemd installation helpers

# Ensure the script is installed to a persistent path (not /tmp)
ensure_persistent_install() {
	local current_path
	current_path=$(realpath "$0")
	local target_path="/usr/local/sbin/ubuntu-reboot-manager.sh"

	# If current path is already the target and executable, return it
	if [ "$current_path" = "$target_path" ] && [ -x "$current_path" ]; then
		echo "$target_path"
		return 0
	fi

	# If current path is under /tmp or not persistent, copy to target_path
	if echo "$current_path" | grep -qE '^/tmp/'; then
		log_message "Detected transient script location ($current_path); installing to $target_path"
	else
		log_message "Installing script to persistent location: $target_path"
	fi

	install -m 0755 "$current_path" "$target_path" 2>/dev/null || cp "$current_path" "$target_path"
	chmod 0755 "$target_path" 2>/dev/null
	if command -v chown >/dev/null 2>&1; then
		chown root:root "$target_path" 2>/dev/null || true
	fi

	if [ -x "$target_path" ]; then
		log_message "Persistent install complete at $target_path"
		echo "$target_path"
		return 0
	else
		log_message "ERROR: Failed to install script to $target_path"
		echo "$current_path"
		return 1
	fi
}

install_systemd_units() {
    local target_path
    target_path="$(ensure_persistent_install)"
    local service="/etc/systemd/system/reboot-manager.service"
    local timer="/etc/systemd/system/reboot-manager.timer"

    log_message "Installing systemd units ($service, $timer)"

    cat > "$service" <<'EOF'
[Unit]
Description=Reboot Manager - uptime policy enforcement
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ubuntu-reboot-manager.sh --no-systemd
Nice=10
CapabilityBoundingSet=CAP_SYS_BOOT
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
EOF

    cat > "$timer" <<'EOF'
[Unit]
Description=Run Reboot Manager daily at 12:00

[Timer]
OnCalendar=*-*-* 12:00:00
Persistent=true
Unit=reboot-manager.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload 2>/dev/null
    systemctl enable --now reboot-manager.timer 2>/dev/null && log_message "systemd timer enabled and started" || log_message "ERROR: failed to enable/start systemd timer"
}

remove_systemd_units() {
    local service="/etc/systemd/system/reboot-manager.service"
    local timer="/etc/systemd/system/reboot-manager.timer"
    log_message "Removing systemd units"
    systemctl disable --now reboot-manager.timer 2>/dev/null || true
    rm -f "$timer" "$service"
    systemctl daemon-reload 2>/dev/null
    log_message "Systemd units removed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install-systemd Install systemd service+timer (daily at 12:00)"
    echo "  --remove-systemd  Remove systemd units"
    echo "  --no-systemd      Run without touching systemd"
    echo "  --dry-run         Exercise logic without actually scheduling a reboot"
    echo "  --status          Show current status and uptime"
    echo "  --help            Show this help message"
    echo ""
    echo "Default behavior: Installs to /usr/local/sbin, installs/enables systemd timer,"
    echo "and runs checks while logging to $LOG_FILE and mirroring to STDOUT."
}

# Function to show status
show_status() {
    local uptime_days
    uptime_days=$(get_uptime_days)
    
    echo "=== Reboot Manager Status ==="
    echo "Current uptime: $uptime_days days"
    echo "Warning threshold: $WARNING_DAYS days"
    echo "Forced reboot threshold: $FORCED_REBOOT_DAYS days"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Check systemd timer status
    if systemctl is-enabled reboot-manager.timer >/dev/null 2>&1; then
        echo "systemd timer: INSTALLED"
    else
        echo "systemd timer: NOT INSTALLED"
    fi
    
    # Show recent log entries
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "Recent log entries:"
        tail -n 5 "$LOG_FILE"
    fi
}

# Main execution starts here
log_message "Script started"

# Handle command line arguments
case "${1:-}" in
    --install-systemd)
        if [ "$EUID" -ne 0 ]; then
            echo "Error: This option must be run as root"
            exit 1
        fi
        install_systemd_units
        exit $?
        ;;
    --remove-systemd)
        if [ "$EUID" -ne 0 ]; then
            echo "Error: This option must be run as root"
            exit 1
        fi
        remove_systemd_units
        exit $?
        ;;
    --status)
        show_status
        exit 0
        ;;
    --help)
        show_usage
        exit 0
        ;;
    --no-systemd)
        # Run without touching systemd
        log_message "Running without systemd changes (--no-systemd flag)"
        ;;
    --dry-run)
        DRY_RUN=1
        log_message "Dry-run mode enabled (no actual shutdown)"
        ;;
    "")
        # No arguments - proceed with normal execution
        ;;
    *)
        echo "Error: Unknown option '$1'"
        show_usage
        exit 1
        ;;
esac

# Check if running as root (required for notifications and reboot)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    log_message "ERROR: Script not run as root"
    exit 1
fi

# Auto-install to persistent path and ensure systemd timer is installed/enabled unless --no-systemd was used
if [ "${1:-}" != "--no-systemd" ]; then
    PERSISTENT_PATH="$(ensure_persistent_install)"
    if ! systemctl is-enabled reboot-manager.timer >/dev/null 2>&1; then
        log_message "systemd timer not found - installing automatically"
        install_systemd_units
    else
        log_message "systemd timer already installed - continuing with uptime check"
    fi
fi

# Prefer notify-send; continue without it (fallback to wall)
if ! command -v notify-send >/dev/null 2>&1; then
	log_message "notify-send not found - attempting automatic installation"
	if install_notify_send && command -v notify-send >/dev/null 2>&1; then
		log_message "notify-send installed successfully"
	else
		log_message "WARNING: Failed to install notify-send; GUI notifications may be unavailable (falling back to wall)"
	fi
fi

# Get current uptime in days
UPTIME_DAYS=$(get_uptime_days)
log_message "Current uptime: $UPTIME_DAYS days"

# Take action based on uptime
if [ "$UPTIME_DAYS" -ge "$FORCED_REBOOT_DAYS" ]; then
    # Force reboot at 14+ days
    log_message "FORCED REBOOT: Uptime ($UPTIME_DAYS days) >= forced reboot threshold ($FORCED_REBOOT_DAYS days)"
    show_final_warning
    sleep 300  # 5 minute warning
    perform_forced_reboot
    
elif [ "$UPTIME_DAYS" -ge "$WARNING_DAYS" ]; then
    # Warning notifications from day 10-13
    days_left=$((FORCED_REBOOT_DAYS - UPTIME_DAYS))
    log_message "WARNING: Uptime ($UPTIME_DAYS days) >= warning threshold ($WARNING_DAYS days), $days_left days until forced reboot"
    show_countdown_notification "$days_left"
    
else
    # System uptime is acceptable
    log_message "System uptime acceptable: $UPTIME_DAYS days (warning at $WARNING_DAYS days)"
fi

log_message "Script completed"

# Ensure log doesn't grow too large (keep last 1000 lines)
if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt 1000 ]; then
    tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

exit 0