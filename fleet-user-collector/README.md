# Fleet User Collector

A comprehensive bash script for collecting user information from Fleet API.

## Quick Start

```bash
# Basic usage
./fleet-user-collector.sh -u https://your-fleet-server.com -t your-api-token

# Full data collection
./fleet-user-collector.sh -u https://your-fleet-server.com -t your-api-token --all

# Save output to file
./fleet-user-collector.sh -u https://your-fleet-server.com -t your-api-token -o users.txt
```

## Files

- `fleet-user-collector.sh` - Main executable script
- `fleet-user-collector.example.conf` - Example configuration
- `fleet-user-collector.README.md` - Detailed documentation
- `.gitignore` - Prevents output files from being committed

## Requirements

- bash 4.0+
- curl
- jq

## Installation

```bash
# Install dependencies (macOS)
brew install jq curl

# Ubuntu/Debian
sudo apt-get install jq curl

# Make script executable
chmod +x fleet-user-collector.sh
```

## Output Files

The script generates output files that are automatically ignored by git:
- `fleet-users-*.txt` - Table format output
- `fleet-users-*.json` - JSON format output  
- `fleet-users-*.csv` - CSV format output

See `fleet-user-collector.README.md` for complete documentation.
