# Fleet Policy Converter (Go)

This is a Go implementation of the Python scripts for converting macOS Security Compliance Project baselines to Fleet-compatible YAML format.

## Overview

The Go version provides the same functionality as the original Python scripts but with improved performance, better error handling, and a unified CLI interface.

## Features

- **Convert Baselines**: Convert macOS Security Compliance Project baselines to Fleet YAML format
- **Fix Generic Queries**: Identify and mark generic queries that need manual review
- **Fix Specific Queries**: Apply specific query patterns based on policy names and descriptions
- **Comprehensive Query Fixing**: Advanced pattern matching to automatically generate appropriate queries

## Installation

1. Ensure you have Go 1.21 or later installed
2. Clone or download this directory
3. Install dependencies:
   ```bash
   go mod tidy
   ```

## Usage

### Command Line Interface

```bash
# Show help
go run . -help

# Convert baselines to Fleet YAML
go run . -command convert

# Fix generic queries in existing YAML files
go run . -command fix-queries

# Fix specific query patterns
go run . -command fix-specific

# Comprehensive query fixing with pattern matching
go run . -command comprehensive
```

### Building

To build a binary:

```bash
go build -o fleet-converter .
```

Then run:
```bash
./fleet-converter -command convert
```

## Commands

### Convert (`-command convert`)

Converts macOS Security Compliance Project baselines to Fleet-compatible YAML format.

**Requirements:**
- macOS Security Compliance Project repository must be available
- Update the `projectRoot` path in `convert.go` to point to your local copy

**Output:**
- Generates Fleet-compatible YAML files in the `fleet/` directory
- Each baseline becomes a separate YAML file with `-fleet-policies.yml` suffix

### Fix Queries (`-command fix-queries`)

Identifies and marks generic queries that need manual review.

**Features:**
- Finds `SELECT 1;` queries
- Identifies overly generic file path queries
- Marks generic launchd service queries
- Adds TODO comments for manual review

### Fix Specific (`-command fix-specific`)

Applies specific query patterns based on policy names and descriptions.

**Features:**
- Fixes audit-related queries
- Corrects file permission queries
- Updates managed policy queries
- Reduces manual review requirements

### Comprehensive (`-command comprehensive`)

Advanced pattern matching to automatically generate appropriate queries.

**Features:**
- Pattern-based query generation
- Comprehensive mapping of policy types to queries
- Automatic query replacement
- Support for audit, FileVault, firewall, and other policy types

## Configuration

### Project Root Path

Update the `projectRoot` variable in `convert.go` to point to your macOS Security Compliance Project repository:

```go
projectRoot := "/path/to/your/macos_security"
```

### Query Mappings

The comprehensive query fixer uses predefined patterns in `types.go`. You can modify the `CreateQueryMappings()` function to add new patterns or modify existing ones.

## File Structure

```
mscp-to-fleet-yaml/
├── main.go              # Main CLI interface
├── types.go             # Data structures and YAML utilities
├── utils.go             # Utility functions
├── convert.go           # Baseline conversion logic
├── fix_queries.go       # Generic query fixing
├── fix_specific.go      # Specific query fixing
├── comprehensive.go     # Comprehensive query fixing
├── go.mod              # Go module definition
└── README-Go.md        # This file
```

## Error Handling

The Go version includes comprehensive error handling:

- File I/O errors are properly caught and reported
- YAML parsing errors are handled gracefully
- Missing rules are logged as warnings
- Processing continues even if individual files fail

## Performance

The Go version offers several performance improvements over the Python version:

- Faster file processing
- More efficient regex operations
- Better memory management
- Concurrent processing capabilities (can be added)

## Migration from Python

The Go version maintains compatibility with the original Python scripts:

1. **Same Input**: Works with the same YAML files and directory structure
2. **Same Output**: Generates identical Fleet-compatible YAML files
3. **Same Patterns**: Uses the same query patterns and mappings
4. **Enhanced Features**: Additional error handling and performance improvements

## Development

### Adding New Query Patterns

To add new query patterns, modify the `CreateQueryMappings()` function in `types.go`:

```go
{`.*new-pattern.*`,
    "SELECT 1 FROM new_table WHERE condition = 'value';"},
```

### Adding New Commands

To add new commands:

1. Create a new function in the appropriate file
2. Add a case in the switch statement in `main.go`
3. Update the help text

### Testing

Run the tool with different commands to test functionality:

```bash
# Test comprehensive query fixing
go run . -command comprehensive

# Test with specific files
go run . -command fix-queries
```

## Troubleshooting

### Common Issues

1. **Project Root Not Found**: Update the path in `convert.go`
2. **YAML Parse Errors**: Check file format and encoding
3. **Permission Errors**: Ensure write permissions for output directory
4. **Missing Dependencies**: Run `go mod tidy`

### Debug Mode

Add debug logging by modifying the print statements in the code or using a proper logging library.

## License

Same as the original Python scripts.
