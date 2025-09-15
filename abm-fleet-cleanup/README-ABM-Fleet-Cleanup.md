# Apple Business Manager & Fleet Device Cleanup Script

This script compares device inventories between Apple Business Manager (ABM) and Fleet MDM to identify devices that can be safely deleted from Fleet. Devices are eligible for deletion if they exist in ABM and haven't been seen in Fleet for 30+ days.

## Features

- **Dual API Integration**: Connects to both Apple Business Manager and Fleet APIs
- **Smart Device Matching**: Matches devices by serial number between systems
- **Configurable Thresholds**: Customizable inactivity period (default: 30 days)
- **Safety Features**: Dry-run mode, comprehensive logging, error handling
- **JWT Authentication**: Secure authentication with Apple Business Manager API
- **Detailed Reporting**: Clear summary of devices eligible for deletion

## Prerequisites

### Required Dependencies
- `curl` - For API requests
- `jq` - For JSON processing
- `openssl` - For JWT token generation

### Apple Business Manager Setup
1. Create an API key in Apple Business Manager
2. Download the private key file (.p8)
3. Note your Key ID and Issuer ID

### Fleet MDM Setup
1. Generate an API token in Fleet
2. Note your Fleet server URL

## Installation

1. **Clone or download the script**:
   ```bash
   # Make the script executable
   chmod +x abm-fleet-device-cleanup.sh
   ```

2. **Install dependencies** (if not already installed):
   ```bash
   # On macOS
   brew install jq
   
   # On Ubuntu/Debian
   sudo apt-get install jq curl openssl
   
   # On CentOS/RHEL
   sudo yum install jq curl openssl
   ```

3. **Set up configuration**:
   ```bash
   # Copy the example config
   cp abm-fleet-config.example abm-fleet-config
   
   # Edit with your values
   nano abm-fleet-config
   
   # Source the configuration
   source abm-fleet-config
   ```

## Configuration

### Environment Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `ABM_KEY_ID` | Apple Business Manager Key ID | Yes | `ABC123DEF4` |
| `ABM_ISSUER_ID` | Apple Business Manager Issuer ID | Yes | `12345678-1234-1234-1234-123456789012` |
| `ABM_PRIVATE_KEY_PATH` | Path to ABM private key file | Yes | `/path/to/AuthKey_ABC123DEF4.p8` |
| `FLEET_BASE_URL` | Fleet server base URL | Yes | `https://fleet.yourcompany.com` |
| `FLEET_API_TOKEN` | Fleet API authentication token | Yes | `your_fleet_token_here` |
| `FLEET_INACTIVITY_DAYS` | Days of inactivity threshold | No | `30` (default) |
| `DRY_RUN` | Enable dry-run mode | No | `true` or `false` |
| `VERBOSE` | Enable verbose logging | No | `true` or `false` |

### Configuration File Example

```bash
# Apple Business Manager API Configuration
export ABM_KEY_ID="ABC123DEF4"
export ABM_ISSUER_ID="12345678-1234-1234-1234-123456789012"
export ABM_PRIVATE_KEY_PATH="/path/to/AuthKey_ABC123DEF4.p8"

# Fleet MDM Configuration
export FLEET_BASE_URL="https://fleet.yourcompany.com"
export FLEET_API_TOKEN="your_fleet_api_token_here"

# Optional Configuration
export FLEET_INACTIVITY_DAYS="30"
export DRY_RUN="false"
export VERBOSE="false"
```

## Usage

### Basic Usage

```bash
# Run with dry-run mode (recommended first)
DRY_RUN=true ./abm-fleet-device-cleanup.sh

# Run with custom inactivity threshold
FLEET_INACTIVITY_DAYS=60 ./abm-fleet-device-cleanup.sh

# Run with verbose logging
VERBOSE=true ./abm-fleet-device-cleanup.sh

# Run in production mode
./abm-fleet-device-cleanup.sh
```

### Command Line Options

```bash
# Show help
./abm-fleet-device-cleanup.sh --help

# Dry run mode
./abm-fleet-device-cleanup.sh --dry-run

# Verbose logging
./abm-fleet-device-cleanup.sh --verbose
```

## How It Works

1. **Authentication**: Creates JWT token for Apple Business Manager API
2. **Data Collection**: Fetches device inventories from both ABM and Fleet
3. **Device Matching**: Matches devices by serial number between systems
4. **Inactivity Check**: Identifies devices that haven't been seen in Fleet for 30+ days
5. **Deletion**: Removes eligible devices from Fleet (if not in dry-run mode)

## Output

The script provides detailed output including:

- **Summary Table**: List of devices eligible for deletion with:
  - Serial number
  - Hostname
  - Days inactive
  - Last fetched timestamp
- **Logging**: Comprehensive logs saved to `/var/log/abm-fleet-cleanup.log`
- **Statistics**: Total count of devices processed and deleted

### Example Output

```
==========================================
DEVICES ELIGIBLE FOR DELETION FROM FLEET
==========================================

SERIAL NUMBER         HOSTNAME                       DAYS INACTIVE   LAST FETCHED
-------------------   ------------------------------  ---------------  ------------
ABC123DEF456          MacBook-Pro-001                45              2024-01-15T10:30:00Z
XYZ789GHI012          MacBook-Pro-002                32              2024-01-28T14:22:00Z

Total devices eligible for deletion: 2
```

## Safety Features

- **Dry-Run Mode**: Test the script without making changes
- **Comprehensive Logging**: All actions are logged for audit trails
- **Error Handling**: Graceful handling of API failures and network issues
- **Validation**: Configuration and dependency validation before execution
- **Signal Handling**: Proper cleanup on script interruption

## Troubleshooting

### Common Issues

1. **Authentication Failures**:
   - Verify ABM credentials are correct
   - Check private key file path and permissions
   - Ensure Key ID and Issuer ID match your ABM account

2. **Fleet API Errors**:
   - Verify Fleet URL and API token
   - Check Fleet server connectivity
   - Ensure API token has necessary permissions

3. **Dependency Issues**:
   - Install missing dependencies (`curl`, `jq`, `openssl`)
   - Verify all commands are in PATH

4. **Permission Issues**:
   - Ensure script has execute permissions
   - Check log file write permissions

### Debug Mode

Enable verbose logging for detailed debugging:

```bash
VERBOSE=true ./abm-fleet-device-cleanup.sh
```

### Log Files

- **Script Log**: `/var/log/abm-fleet-cleanup.log`
- **System Log**: Check with `journalctl -t abm-fleet-cleanup`

## Security Considerations

- **API Tokens**: Store securely and rotate regularly
- **Private Keys**: Protect ABM private key files with appropriate permissions
- **Logs**: Review logs for sensitive information before sharing
- **Network**: Use secure connections (HTTPS) for all API calls

## Automation

### Cron Job Example

```bash
# Run weekly cleanup every Sunday at 2 AM
0 2 * * 0 /path/to/abm-fleet-device-cleanup.sh
```

### Systemd Service Example

```ini
[Unit]
Description=ABM Fleet Device Cleanup
After=network.target

[Service]
Type=oneshot
User=root
EnvironmentFile=/path/to/abm-fleet-config
ExecStart=/path/to/abm-fleet-device-cleanup.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

## API Reference

### Apple Business Manager API
- **Endpoint**: `GET /v1/devices`
- **Authentication**: JWT Bearer token
- **Documentation**: [Apple Business Manager API](https://developer.apple.com/documentation/applebusinessmanagerapi)

### Fleet MDM API
- **Endpoint**: `GET /api/v1/hosts`
- **Authentication**: Bearer token
- **Documentation**: [Fleet REST API](https://fleetdm.com/docs/rest-api)

## License

This script is provided as-is for educational and operational purposes. Please review and test thoroughly before using in production environments.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review log files for error details
3. Verify API credentials and connectivity
4. Test with dry-run mode first
