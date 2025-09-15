#!/bin/bash

# Ubuntu Reboot Management Script
# Purpose: Monitor system uptime and enforce periodic reboots
# Requirements: Zenity for GUI notifications
# Usage: Run as daily cron job

# Configuration
WARNING_DAYS=10
FORCED_REBOOT_DAYS=14
LOG_FILE="/var/log/reboot-manager.log"
SCRIPT_NAME="Reboot Manager"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to get uptime in days
get_uptime_days() {
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

# Function to install zenity automatically
install_zenity() {
    local distro
    distro=$(detect_distro)
    
    log_message "Attempting to install zenity on $distro system"
    
    case "$distro" in
        ubuntu|debian)
            if command -v apt-get &> /dev/null; then
                apt-get update -qq && apt-get install -y zenity
                if [ $? -eq 0 ]; then
                    log_message "Successfully installed zenity via apt-get"
                    return 0
                fi
            fi
            ;;
        fedora|rhel|centos)
            if command -v dnf &> /dev/null; then
                dnf install -y zenity
                if [ $? -eq 0 ]; then
                    log_message "Successfully installed zenity via dnf"
                    return 0
                fi
            elif command -v yum &> /dev/null; then
                yum install -y zenity
                if [ $? -eq 0 ]; then
                    log_message "Successfully installed zenity via yum"
                    return 0
                fi
            fi
            ;;
        arch|manjaro)
            if command -v pacman &> /dev/null; then
                pacman -Sy --noconfirm zenity
                if [ $? -eq 0 ]; then
                    log_message "Successfully installed zenity via pacman"
                    return 0
                fi
            fi
            ;;
        *)
            log_message "ERROR: Unknown distribution '$distro' - cannot auto-install zenity"
            return 1
            ;;
    esac
    
    log_message "ERROR: Failed to install zenity on $distro system"
    return 1
}

# Function to send notification to all logged-in users
send_notification() {
    local title="$1"
    local message="$2"
    local icon="$3"
    local timeout="$4"
    
    # Get all active user sessions
    local users
    users=$(who | awk '{print $1}' | sort -u)
    
    if [ -z "$users" ]; then
        log_message "No users logged in for notification"
        return 1
    fi
    
    # Send notification to each logged-in user
    for user in $users; do
        # Try GUI notification first (simplified approach)
        if sudo -u "$user" zenity --notification --text="$message" --timeout="$timeout" 2>/dev/null; then
            log_message "GUI notification sent to user: $user"
            
            # Also show a dialog for important messages
            if [ "$icon" = "warning" ] || [ "$icon" = "error" ]; then
                sudo -u "$user" zenity --"$icon" --title="$title" --text="$message" --width=400 --timeout=30 2>/dev/null &
            fi
        else
            # Fall back to wall message for users without GUI
            wall "NOTIFICATION: $message"
            log_message "Wall message sent to user: $user (no GUI available)"
        fi
    done
}

# Function to show countdown notification
show_countdown_notification() {
    local days_left="$1"
    local title="System Reboot Required"
    local message="Your system has been running for $UPTIME_DAYS days.\nA reboot is required in $days_left day(s).\n\nPlease save your work and reboot when convenient."
    
    send_notification "$title" "$message" "warning" 0
}

# Function to show final warning
show_final_warning() {
    local title="URGENT: Immediate Reboot Required"
    local message="Your system has been running for $UPTIME_DAYS days.\n\nSystem will automatically reboot in 5 minutes!\n\nPlease save all work immediately!"
    
    send_notification "$title" "$message" "error" 0
    
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
    
    # Schedule immediate reboot
    shutdown -r +1 "Automated reboot: System uptime exceeded $FORCED_REBOOT_DAYS days policy"
    
    log_message "Reboot scheduled - system will restart in 1 minute"
    
    # Exit immediately after scheduling reboot to prevent further execution
    exit 0
}

# Function to install cron job
install_cron_job() {
    local script_path="$1"
    local cron_entry="0 12 * * * $script_path"
    
    log_message "Installing cron job: $cron_entry"
    
    # Check if cron job already exists in root crontab
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        log_message "Cron job already exists for this script"
        return 0
    fi
    
    # Add cron job to root crontab
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    
    if [ $? -eq 0 ]; then
        log_message "Cron job installed successfully"
        return 0
    else
        log_message "ERROR: Failed to install cron job"
        return 1
    fi
}

# Function to remove cron job
remove_cron_job() {
    local script_path="$1"
    
    log_message "Removing cron job for: $script_path"
    
    # Remove cron job from root crontab
    crontab -l 2>/dev/null | grep -v "$script_path" | crontab -
    
    if [ $? -eq 0 ]; then
        log_message "Cron job removed successfully"
        return 0
    else
        log_message "ERROR: Failed to remove cron job"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install-cron    Install daily cron job (runs at 12 noon)"
    echo "  --remove-cron     Remove cron job"
    echo "  --no-cron         Run without installing cron job"
    echo "  --status          Show current status and uptime"
    echo "  --help            Show this help message"
    echo ""
    echo "Default behavior: Runs uptime check, notifications, and auto-installs cron job if missing."
    echo "Use --no-cron to run without cron installation."
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
    
    # Check if cron job exists in root crontab
    if crontab -l 2>/dev/null | grep -q "$(realpath "$0")"; then
        echo "Cron job: INSTALLED"
    else
        echo "Cron job: NOT INSTALLED"
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
    --install-cron)
        if [ "$EUID" -ne 0 ]; then
            echo "Error: This option must be run as root"
            exit 1
        fi
        install_cron_job "$(realpath "$0")"
        exit $?
        ;;
    --remove-cron)
        if [ "$EUID" -ne 0 ]; then
            echo "Error: This option must be run as root"
            exit 1
        fi
        remove_cron_job "$(realpath "$0")"
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
    --no-cron)
        # Run without installing cron job
        log_message "Running without cron installation (--no-cron flag)"
        ;;
    "")
        # No arguments - run normal uptime check and install cron if needed
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

# Auto-install cron job if not already installed (unless --no-cron flag is used)
if [ "${1:-}" != "--no-cron" ]; then
    if ! crontab -l 2>/dev/null | grep -q "$(realpath "$0")"; then
        log_message "Cron job not found - installing automatically"
        if install_cron_job "$(realpath "$0")"; then
            log_message "Cron job installed successfully - script will run daily at 12 noon"
        else
            log_message "WARNING: Failed to install cron job - script will not run automatically"
        fi
    else
        log_message "Cron job already installed - continuing with uptime check"
    fi
fi

# Check if zenity is installed and auto-install if missing
if ! command -v zenity &> /dev/null; then
    log_message "Zenity not found - attempting automatic installation"
    
    if install_zenity; then
        log_message "Zenity successfully installed - continuing script execution"
    else
        local distro
        distro=$(detect_distro)
        echo "Error: Failed to automatically install zenity on $distro system"
        echo "Please install zenity manually:"
        case "$distro" in
            ubuntu|debian)
                echo "  apt-get install zenity"
                ;;
            fedora|rhel|centos)
                echo "  dnf install zenity"
                ;;
            arch|manjaro)
                echo "  pacman -S zenity"
                ;;
            *)
                echo "  Install zenity package for your distribution"
                ;;
        esac
        log_message "ERROR: Failed to install zenity - script cannot continue"
        exit 1
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