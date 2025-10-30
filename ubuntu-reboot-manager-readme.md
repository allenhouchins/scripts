# Ubuntu Reboot Manager

Enterprise-ready uptime enforcement for Linux desktops/servers. Automatically installs itself persistently, schedules a daily systemd timer, sends user-facing notifications, and performs a forced reboot once uptime exceeds your policy.

## What it does
- Installs itself to `/usr/local/sbin/ubuntu-reboot-manager.sh` on first run
- Installs and enables `reboot-manager.service` + `reboot-manager.timer` (runs daily at 12:00; persistent timer)
- Logs to `/var/log/reboot-manager.log` and mirrors to STDOUT (MDM-friendly)
- Notifies active graphical users via `notify-send`; falls back to `wall`
- Warns at `WARNING_DAYS` and forces reboot at `FORCED_REBOOT_DAYS` with a 5-minute final warning

## Requirements
- systemd (service + timer)
- `libnotify-bin` (for `notify-send`) on desktop systems

## Deploy (single command)
```bash
sudo /Users/allen/GitHub/scripts/ubuntu-reboot-manager.sh
```
This automatically:
- Copies the script to `/usr/local/sbin/ubuntu-reboot-manager.sh`
- Installs/enables the systemd timer
- Runs the uptime check immediately

## Validate installation
```bash
systemctl status reboot-manager.timer
journalctl -u reboot-manager.service --since -5m
tail -n 50 /var/log/reboot-manager.log
```

## Testing without waiting
Simulate days and skip the actual reboot using env overrides and dry-run.

```bash
# Show warning path (no reboot)
sudo WARNING_DAYS=5 FORCED_REBOOT_DAYS=7 UPTIME_DAYS=6 /usr/local/sbin/ubuntu-reboot-manager.sh --no-systemd --dry-run

# Trigger forced-reboot path safely (dry-run skips shutdown)
sudo WARNING_DAYS=5 FORCED_REBOOT_DAYS=7 UPTIME_DAYS=8 /usr/local/sbin/ubuntu-reboot-manager.sh --no-systemd --dry-run
```

## Options
- `--status`: Print current uptime, thresholds, timer status, and recent logs
- `--remove-systemd`: Disable and remove the systemd units
- `--no-systemd`: Run once without installing or touching systemd
- `--dry-run`: Exercise logic without scheduling a reboot

## Configuration
Variables can be overridden at runtime via environment variables or set in the script:
- `WARNING_DAYS` (default 10)
- `FORCED_REBOOT_DAYS` (default 14)
- `LOG_FILE` (default `/var/log/reboot-manager.log`)

## Notifications
- Primary: `notify-send` via the active user’s systemd user manager (Wayland/X11)
- Fallbacks: session DBUS with DISPLAY/WAYLAND env, then `wall` to all terminals
- Ensure `libnotify-bin` is installed on desktops:
```bash
sudo apt-get update && sudo apt-get install -y libnotify-bin
```

## Troubleshooting
- No GUI popup:
  - Verify a graphical session exists: `loginctl list-sessions`
  - Check the active session: `loginctl show-session <ID> -p Type -p Display -p Active`
  - Confirm notify-send availability: `command -v notify-send`
  - Ensure user systemd is running: `sudo -u '#1000' XDG_RUNTIME_DIR=/run/user/1000 systemctl --user is-system-running`
- Logs:
  - `tail -n 100 /var/log/reboot-manager.log`
  - `journalctl -u reboot-manager.service --since -1h`

## Security
- Requires root to schedule reboots and reach user sessions
- Logs contain uptime policy events only; no PII collected

## Uninstall
```bash
sudo /usr/local/sbin/ubuntu-reboot-manager.sh --remove-systemd
sudo rm -f /usr/local/sbin/ubuntu-reboot-manager.sh
sudo rm -f /var/log/reboot-manager.log
```