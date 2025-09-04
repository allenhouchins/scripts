# Ubuntu Reboot Manager Setup Instructions

## Installation Steps

### 1. Install Dependencies
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install zenity

# Fedora/RHEL/CentOS
sudo dnf install zenity

# Arch/Manjaro
sudo pacman -S zenity
```

### 2. Create and Install the Script
```bash
# Create the script file
sudo nano /usr/local/bin/reboot-manager.sh

# Copy the script content into the file, then save and exit

# Make the script executable
sudo chmod +x /usr/local/bin/reboot-manager.sh

# Create log directory (if needed)
sudo touch /var/log/reboot-manager.log
sudo chmod 644 /var/log/reboot-manager.log
```

### 3. Set Up Daily Cron Job
```bash
# Edit root's crontab
sudo crontab -e

# Add this line to run the script daily at 9:00 AM
0 9 * * * /usr/local/bin/reboot-manager.sh

# Alternative: Run at 2:00 PM
# 0 14 * * * /usr/local/bin/reboot-manager.sh
```

### 4. Test the Script
```bash
# Test script execution
sudo /usr/local/bin/reboot-manager.sh

# Check the log file
sudo tail -f /var/log/reboot-manager.log

# Test with a fake high uptime (for testing only)
# Temporarily modify /proc/uptime or adjust the thresholds in the script
```

## Configuration Options

You can modify these variables at the top of the script:

- `WARNING_DAYS=10` - Days before showing warning notifications
- `FORCED_REBOOT_DAYS=14` - Days before forcing automatic reboot
- `LOG_FILE="/var/log/reboot-manager.log"` - Location of log file

## How It Works

### Timeline:
- **Days 1-9**: Script runs silently, logs uptime
- **Days 10-13**: Daily warning notifications to all logged-in users
- **Day 14+**: Final 5-minute warning, then forced reboot

### Notifications:
- Uses Zenity for GUI notifications (popup windows)
- Uses `wall` command for terminal notifications
- Sends to all active user sessions

### Safety Features:
- Comprehensive logging to `/var/log/reboot-manager.log`
- Multiple notification methods (GUI + terminal)
- 5-minute final warning before forced reboot
- Log rotation to prevent large files (keeps last 1000 lines)
- Automatic distribution detection for proper zenity installation instructions
- Clean exit after scheduling reboot to prevent race conditions

## Troubleshooting

### Common Issues:

**No notifications appearing:**
- Verify zenity is installed: `which zenity`
- Check if users have DISPLAY environment variable set
- Ensure script is running as root

**Script not running:**
- Check cron service: `sudo systemctl status cron`
- Verify crontab entry: `sudo crontab -l`
- Check script permissions: `ls -la /usr/local/bin/reboot-manager.sh`

**Testing notifications:**
- Log in as a regular user with GUI session
- Run script manually: `sudo /usr/local/bin/reboot-manager.sh`
- Check log file for errors

### Log File Monitoring:
```bash
# Watch log in real-time
sudo tail -f /var/log/reboot-manager.log

# View recent entries
sudo tail -20 /var/log/reboot-manager.log

# Search for specific events
sudo grep "WARNING" /var/log/reboot-manager.log
sudo grep "FORCED REBOOT" /var/log/reboot-manager.log
```

### Distribution-Specific Considerations

**Fedora/RHEL/CentOS Additional Steps:**
```bash
# If SELinux is enforcing, you may need to allow the script to run
# Check SELinux status
getenforce

# If needed, create SELinux policy or set permissive mode for testing
# sudo setenforce 0  # Temporary - for testing only
# For production, create proper SELinux policy

# Fedora uses 'crond' instead of 'cron'
sudo systemctl enable crond
sudo systemctl start crond
```

**Ubuntu/Debian Additional Notes:**
- AppArmor is generally permissive for this use case
- Standard cron service should work out of the box
- Zenity typically pre-installed on desktop versions

**Arch/Manjaro Additional Steps:**
```bash
# Install zenity
sudo pacman -S zenity

# Enable and start cronie (Arch uses cronie instead of cron)
sudo systemctl enable cronie
sudo systemctl start cronie
```

## Security Considerations

- Script must run as root (required for reboot and cross-user notifications)
- Log file contains system uptime information
- **SELinux systems**: May require custom policy for cross-user GUI access
- **Firewall**: No network access required
- **Script integrity**: The script includes automatic distribution detection and proper error handling
- Test thoroughly before deploying to production systems

## Script Features

### Automatic Distribution Detection
The script automatically detects your Linux distribution and provides appropriate zenity installation instructions for:
- Ubuntu/Debian (apt)
- Fedora/RHEL/CentOS (dnf)
- Arch/Manjaro (pacman)
- Unknown distributions (generic message)

### Error Handling
- Graceful handling of missing zenity package
- Proper exit codes for different failure scenarios
- Comprehensive logging of all operations
- Clean shutdown after scheduling reboot

## Customization Examples

### Change notification timing:
```bash
# Show warnings earlier (day 7) and force reboot later (day 21)
WARNING_DAYS=7
FORCED_REBOOT_DAYS=21
```

### Different cron schedules:
```bash
# Run twice daily (9 AM and 6 PM)
0 9,18 * * * /usr/local/bin/reboot-manager.sh

# Run only on weekdays
0 9 * * 1-5 /usr/local/bin/reboot-manager.sh
```

### Email notifications (addition):
Add this function to the script for email alerts:
```bash
send_email_alert() {
    echo "System uptime: $UPTIME_DAYS days" | mail -s "Reboot Alert" admin@company.com
}
```