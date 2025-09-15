# ABM-Fleet Device Cleanup

This directory contains scripts and configuration files for managing device cleanup between Apple Business Manager (ABM) and Fleet MDM.

## Files

- **`abm-fleet-device-cleanup.sh`** - Main script that compares ABM and Fleet device inventories
- **`abm-fleet-config.example`** - Configuration template with environment variables
- **`README-ABM-Fleet-Cleanup.md`** - Comprehensive documentation and usage guide

## Quick Start

1. **Copy and configure**:
   ```bash
   cp abm-fleet-config.example abm-fleet-config
   nano abm-fleet-config
   ```

2. **Set up environment**:
   ```bash
   source abm-fleet-config
   ```

3. **Run the script**:
   ```bash
   # Dry run first (recommended)
   ./abm-fleet-device-cleanup.sh --dry-run
   
   # Production run
   ./abm-fleet-device-cleanup.sh
   ```

## Purpose

The script identifies devices that can be safely deleted from Fleet by:
- Comparing device inventories between Apple Business Manager and Fleet
- Finding devices that exist in ABM but haven't been seen in Fleet for 30+ days
- Providing a safe, auditable way to clean up inactive devices

## Documentation

See `README-ABM-Fleet-Cleanup.md` for complete documentation, including:
- Detailed setup instructions
- API configuration
- Usage examples
- Troubleshooting guide
- Security considerations
