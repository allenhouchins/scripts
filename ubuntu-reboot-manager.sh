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
        local user_display
        user_display=$(sudo -u "$user" printenv DISPLAY 2>/dev/null)
        
        if [ -n "$user_display" ]; then
            sudo -u "$user" DISPLAY="$user_display" zenity \
                --notification \
                --window-icon="$icon" \
                --text="$message" \
                --timeout="$timeout" 2>/dev/null &
                
            # Also show a dialog for important messages
            if [ "$icon" = "warning" ] || [ "$icon" = "error" ]; then
                sudo -u "$user" DISPLAY="$user_display" zenity \
                    --"$icon" \
                    --title="$title" \
                    --text="$message" \
                    --width=400 \
                    --timeout=30 2>/dev/null &
            fi
            
            log_message "Notification sent to user: $user (DISPLAY: $user_display)"
        else
            log_message "No DISPLAY found for user: $user"
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
}

# Main execution starts here
log_message "Script started"

# Check if running as root (required for notifications and reboot)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    log_message "ERROR: Script not run as root"
    exit 1
fi

# Check if zenity is installed and suggest installation if missing
if ! command -v zenity &> /dev/null; then
    local distro
    distro=$(detect_distro)
    case "$distro" in
        ubuntu|debian)
            echo "Error: Zenity is not installed. Install with: apt-get install zenity"
            ;;
        fedora|rhel|centos)
            echo "Error: Zenity is not installed. Install with: dnf install zenity"
            ;;
        *)
            echo "Error: Zenity is not installed. Please install zenity package for your distribution"
            ;;
    esac
    log_message "ERROR: Zenity not installed on $distro system"
    exit 1
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

exit 0#!/bin/bash

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
        local user_display
        user_display=$(sudo -u "$user" printenv DISPLAY 2>/dev/null)
        
        if [ -n "$user_display" ]; then
            sudo -u "$user" DISPLAY="$user_display" zenity \
                --notification \
                --window-icon="$icon" \
                --text="$message" \
                --timeout="$timeout" 2>/dev/null &
                
            # Also show a dialog for important messages
            if [ "$icon" = "warning" ] || [ "$icon" = "error" ]; then
                sudo -u "$user" DISPLAY="$user_display" zenity \
                    --"$icon" \
                    --title="$title" \
                    --text="$message" \
                    --width=400 \
                    --timeout=30 2>/dev/null &
            fi
            
            log_message "Notification sent to user: $user (DISPLAY: $user_display)"
        else
            log_message "No DISPLAY found for user: $user"
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
}

# Main execution starts here
log_message "Script started"

# Check if running as root (required for notifications and reboot)
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    log_message "ERROR: Script not run as root"
    exit 1
fi

# Check if zenity is installed
if ! command -v zenity &> /dev/null; then
    echo "Error: Zenity is not installed. Install with: apt-get install zenity"
    log_message "ERROR: Zenity not installed"
    exit 1
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