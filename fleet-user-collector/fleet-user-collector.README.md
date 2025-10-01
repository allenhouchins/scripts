# Fleet User Data Collector

A comprehensive bash script for collecting user information from Fleet API, including user details, creation/update timestamps, and active session information.

## Features

- **User Information**: Collects all users with creation and update timestamps
- **Active Sessions**: Shows active user sessions and their details
- **Team Memberships**: Displays team associations and roles
- **Multiple Output Formats**: Table, JSON, and CSV output options
- **Comprehensive Error Handling**: Robust error handling and logging
- **Flexible Configuration**: Command-line options for customization

## Requirements

- `bash` 4.0+
- `curl` (for API requests)
- `jq` (for JSON processing)
- Fleet server with API access

## Installation

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/scripts/main/fleet-user-collector.sh
   chmod +x fleet-user-collector.sh
   ```

2. Install dependencies:
   ```bash
   # macOS
   brew install jq curl
   
   # Ubuntu/Debian
   sudo apt-get install jq curl
   
   # CentOS/RHEL
   sudo yum install jq curl
   ```

## Usage

### Basic Usage

```bash
# Get basic user list
./fleet-user-collector.sh -u https://your-fleet-server.com -t your-api-token

# Get all user information including sessions and teams
./fleet-user-collector.sh -u https://your-fleet-server.com -t your-api-token --all
```

### Command Line Options

| Option | Description | Required |
|--------|-------------|----------|
| `-u, --url URL` | Fleet server URL | Yes |
| `-t, --token TOKEN` | API token | Yes |
| `-f, --format FORMAT` | Output format (table/json/csv) | No |
| `-o, --output FILE` | Output file (default: stdout) | No |
| `-v, --verbose` | Enable verbose output | No |
| `--sessions` | Include active session information | No |
| `--teams` | Include team membership information | No |
| `--roles` | Include role information | No |
| `--all` | Include all available information | No |
| `-h, --help` | Show help message | No |

### Examples

#### Table Output (Default)
```bash
./fleet-user-collector.sh -u https://fleet.example.com -t your-token
```

#### JSON Output to File
```bash
./fleet-user-collector.sh -u https://fleet.example.com -t your-token -f json -o users.json
```

#### CSV Output with Sessions
```bash
./fleet-user-collector.sh -u https://fleet.example.com -t your-token -f csv --sessions
```

#### Full Data Collection
```bash
./fleet-user-collector.sh -u https://fleet.example.com -t your-token --all -f json -o full-user-data.json
```

## Authentication

### Getting an API Token

1. **From Fleet UI** (Recommended):
   - Log into your Fleet instance
   - Go to Profile > Get API token
   - Copy the token

2. **Via API**:
   ```bash
   curl -X POST "https://your-fleet-server/api/v1/fleet/login" \
     -H "Content-Type: application/json" \
     -d '{"email":"your-email","password":"your-password"}'
   ```

## Output Formats

### Table Format
```
=== FLEET USER INFORMATION ===

ID   Name                 Email                          Enabled   Created              Updated              Role         SSO    MFA    Sessions
---- -------------------- ------------------------------ --------  -------------------- -------------------- ------------ ------ ------ --------
1    John Doe             john.doe@company.com          true      2023-01-15 10:30     2023-12-01 14:22     admin        true   false  2
2    Jane Smith           jane.smith@company.com         true      2023-02-20 09:15     2023-11-28 16:45     observer     false  true   1
```

### JSON Format
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john.doe@company.com",
  "enabled": true,
  "created_at": "2023-01-15T10:30:00Z",
  "updated_at": "2023-12-01T14:22:00Z",
  "global_role": "admin",
  "sso_enabled": true,
  "mfa_enabled": false,
  "active_sessions": [
    {
      "id": "session-123",
      "created_at": "2023-12-01T14:22:00Z",
      "accessed_at": "2023-12-01T15:30:00Z"
    }
  ],
  "teams": [
    {
      "id": 1,
      "name": "Engineering",
      "role": "maintainer"
    }
  ]
}
```

### CSV Format
```csv
id,name,email,enabled,created_at,updated_at,global_role,sso_enabled,mfa_enabled,active_sessions_count,teams
1,John Doe,john.doe@company.com,true,2023-01-15T10:30:00Z,2023-12-01T14:22:00Z,admin,true,false,2,Engineering;DevOps
```

## Error Handling

The script includes comprehensive error handling for:

- **Authentication failures** (401)
- **Permission errors** (403)
- **Rate limiting** (429)
- **Server errors** (500)
- **Network connectivity issues**
- **Invalid API responses**

## Configuration File

You can create a configuration file to avoid typing the same parameters repeatedly:

```bash
# Create config file
cat > fleet-config.conf << EOF
FLEET_URL="https://your-fleet-server.com"
FLEET_TOKEN="your-api-token"
OUTPUT_FORMAT="table"
INCLUDE_SESSIONS=true
EOF

# Use config file
source fleet-config.conf
./fleet-user-collector.sh -u "$FLEET_URL" -t "$FLEET_TOKEN" --sessions
```

## Troubleshooting

### Common Issues

1. **"Authentication failed"**
   - Verify your API token is correct
   - Check if the token has expired
   - Ensure you have proper permissions

2. **"Missing required dependencies"**
   - Install `curl` and `jq`
   - Verify they are in your PATH

3. **"Failed to connect to Fleet server"**
   - Check the Fleet URL is correct
   - Verify network connectivity
   - Check if Fleet server is running

4. **"Rate limit exceeded"**
   - Wait before retrying
   - Consider using fewer concurrent requests

### Debug Mode

Enable verbose output for troubleshooting:

```bash
./fleet-user-collector.sh -u https://fleet.example.com -t your-token -v
```

## Security Considerations

- **API Token Security**: Store API tokens securely and never commit them to version control
- **Network Security**: Use HTTPS for Fleet server connections
- **Output Security**: Be careful when saving output files containing sensitive user information
- **Permissions**: Ensure the script has appropriate file permissions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This script is provided as-is for educational and administrative purposes. Please ensure compliance with your organization's policies and Fleet's terms of service.

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Fleet API documentation: https://fleetdm.com/docs/rest-api/rest-api#users
- Open an issue in the repository
