#!/bin/bash

#
# Apple Business Manager & Fleet Device Cleanup Script
# Compares ABM device inventory with Fleet devices to identify candidates for deletion
# Devices are eligible for deletion if they exist in ABM and haven't been seen in Fleet for 30+ days
#

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="ABM-Fleet Device Cleanup"
readonly LOG_FILE="/var/log/abm-fleet-cleanup.log"
readonly DRY_RUN="${DRY_RUN:-false}"
readonly VERBOSE="${VERBOSE:-false}"

# API Configuration (set via environment variables or config file)
readonly ABM_BASE_URL="${ABM_BASE_URL:-https://api.apple.com/business/v1}"
readonly ABM_KEY_ID="${ABM_KEY_ID:-}"
readonly ABM_ISSUER_ID="${ABM_ISSUER_ID:-}"
readonly ABM_PRIVATE_KEY_PATH="${ABM_PRIVATE_KEY_PATH:-}"

readonly FLEET_BASE_URL="${FLEET_BASE_URL:-}"
readonly FLEET_API_TOKEN="${FLEET_API_TOKEN:-}"

# Thresholds
readonly FLEET_INACTIVITY_DAYS="${FLEET_INACTIVITY_DAYS:-30}"
readonly FLEET_INACTIVITY_SECONDS=$((FLEET_INACTIVITY_DAYS * 24 * 60 * 60))

# Temporary files
readonly TEMP_DIR="/tmp/abm-fleet-cleanup-$$"
readonly ABM_DEVICES_FILE="$TEMP_DIR/abm_devices.json"
readonly FLEET_DEVICES_FILE="$TEMP_DIR/fleet_devices.json"
readonly CANDIDATES_FILE="$TEMP_DIR/deletion_candidates.json"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp [$level] - $message" | tee -a "$LOG_FILE"
    
    # Also log to system log
    logger -t "abm-fleet-cleanup" "[$level] $message"
}

# Error handling
cleanup() {
    log "INFO" "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    log "INFO" "Cleanup completed"
}

# Set up signal handlers
setup_signal_handlers() {
    trap cleanup EXIT INT TERM
}

# Verify required dependencies
verify_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in curl jq openssl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "ERROR" "Please install missing dependencies and try again"
        exit 1
    fi
    
    log "INFO" "All required dependencies found"
}

# Verify configuration
verify_config() {
    local errors=0
    
    # Check ABM configuration
    if [[ -z "$ABM_KEY_ID" ]]; then
        log "ERROR" "ABM_KEY_ID environment variable not set"
        ((errors++))
    fi
    
    if [[ -z "$ABM_ISSUER_ID" ]]; then
        log "ERROR" "ABM_ISSUER_ID environment variable not set"
        ((errors++))
    fi
    
    if [[ -z "$ABM_PRIVATE_KEY_PATH" ]]; then
        log "ERROR" "ABM_PRIVATE_KEY_PATH environment variable not set"
        ((errors++))
    elif [[ ! -f "$ABM_PRIVATE_KEY_PATH" ]]; then
        log "ERROR" "ABM private key file not found: $ABM_PRIVATE_KEY_PATH"
        ((errors++))
    fi
    
    # Check Fleet configuration
    if [[ -z "$FLEET_BASE_URL" ]]; then
        log "ERROR" "FLEET_BASE_URL environment variable not set"
        ((errors++))
    fi
    
    if [[ -z "$FLEET_API_TOKEN" ]]; then
        log "ERROR" "FLEET_API_TOKEN environment variable not set"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Configuration validation failed with $errors error(s)"
        log "ERROR" "Please set the required environment variables and try again"
        exit 1
    fi
    
    log "INFO" "Configuration validation passed"
}

# Create JWT token for Apple Business Manager API
create_abm_jwt() {
    local now
    now=$(date +%s)
    local exp=$((now + 3600)) # Token expires in 1 hour
    
    # Create JWT header
    local header='{"alg":"ES256","typ":"JWT","kid":"'$ABM_KEY_ID'"}'
    
    # Create JWT payload
    local payload='{"iss":"'$ABM_ISSUER_ID'","iat":'$now',"exp":'$exp',"aud":"appstoreconnect-v1"}'
    
    # Encode header and payload
    local encoded_header
    encoded_header=$(echo -n "$header" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    local encoded_payload
    encoded_payload=$(echo -n "$payload" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # Create signature
    local signature_input="${encoded_header}.${encoded_payload}"
    local signature
    signature=$(echo -n "$signature_input" | openssl dgst -sha256 -sign "$ABM_PRIVATE_KEY_PATH" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
    
    # Return complete JWT
    echo "${signature_input}.${signature}"
}

# Fetch devices from Apple Business Manager
fetch_abm_devices() {
    log "INFO" "Fetching device inventory from Apple Business Manager..."
    
    local jwt_token
    jwt_token=$(create_abm_jwt)
    
    if [[ -z "$jwt_token" ]]; then
        log "ERROR" "Failed to create ABM JWT token"
        return 1
    fi
    
    # Fetch devices from ABM
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $jwt_token" \
        -H "Content-Type: application/json" \
        "$ABM_BASE_URL/devices" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" != "200" ]]; then
        log "ERROR" "ABM API request failed with HTTP $http_code"
        log "ERROR" "Response: $body"
        return 1
    fi
    
    # Save ABM devices to file
    echo "$body" > "$ABM_DEVICES_FILE"
    
    local device_count
    device_count=$(echo "$body" | jq '.data | length')
    log "INFO" "Successfully fetched $device_count devices from Apple Business Manager"
    
    return 0
}

# Fetch devices from Fleet
fetch_fleet_devices() {
    log "INFO" "Fetching device inventory from Fleet..."
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $FLEET_API_TOKEN" \
        -H "Content-Type: application/json" \
        "$FLEET_BASE_URL/api/v1/hosts" 2>/dev/null)
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" != "200" ]]; then
        log "ERROR" "Fleet API request failed with HTTP $http_code"
        log "ERROR" "Response: $body"
        return 1
    fi
    
    # Save Fleet devices to file
    echo "$body" > "$FLEET_DEVICES_FILE"
    
    local device_count
    device_count=$(echo "$body" | jq '.hosts | length')
    log "INFO" "Successfully fetched $device_count devices from Fleet"
    
    return 0
}

# Compare devices and identify deletion candidates
identify_deletion_candidates() {
    log "INFO" "Comparing devices and identifying deletion candidates..."
    
    local candidates=()
    local current_time
    current_time=$(date +%s)
    
    # Read ABM devices
    local abm_devices
    abm_devices=$(jq -c '.data[]' "$ABM_DEVICES_FILE")
    
    # Read Fleet devices
    local fleet_devices
    fleet_devices=$(jq -c '.hosts[]' "$FLEET_DEVICES_FILE")
    
    # Create a map of Fleet devices by serial number for quick lookup
    local fleet_serial_map
    fleet_serial_map=$(echo "$fleet_devices" | jq -r 'select(.hardware_serial != null) | "\(.hardware_serial)|\(.last_fetched_at)|\(.hostname)|\(.id)"')
    
    # Process each ABM device
    while IFS= read -r abm_device; do
        local serial_number
        serial_number=$(echo "$abm_device" | jq -r '.attributes.serialNumber // empty')
        
        if [[ -z "$serial_number" ]]; then
            continue
        fi
        
        # Look for matching device in Fleet
        local fleet_match
        fleet_match=$(echo "$fleet_serial_map" | grep "^$serial_number|" || true)
        
        if [[ -n "$fleet_match" ]]; then
            # Device exists in both ABM and Fleet
            local last_fetched
            last_fetched=$(echo "$fleet_match" | cut -d'|' -f2)
            local hostname
            hostname=$(echo "$fleet_match" | cut -d'|' -f3)
            local fleet_id
            fleet_id=$(echo "$fleet_match" | cut -d'|' -f4)
            
            if [[ "$last_fetched" != "null" && -n "$last_fetched" ]]; then
                # Convert last_fetched to timestamp
                local last_fetched_timestamp
                last_fetched_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$last_fetched" "+%s" 2>/dev/null || echo "0")
                
                if [[ $last_fetched_timestamp -gt 0 ]]; then
                    local days_since_fetch
                    days_since_fetch=$(( (current_time - last_fetched_timestamp) / 86400 ))
                    
                    if [[ $days_since_fetch -ge $FLEET_INACTIVITY_DAYS ]]; then
                        # Device is eligible for deletion
                        local candidate
                        candidate=$(jq -n \
                            --arg serial "$serial_number" \
                            --arg hostname "$hostname" \
                            --arg fleet_id "$fleet_id" \
                            --arg last_fetched "$last_fetched" \
                            --argjson days_inactive "$days_since_fetch" \
                            '{
                                serial_number: $serial,
                                hostname: $hostname,
                                fleet_id: $fleet_id,
                                last_fetched: $last_fetched,
                                days_inactive: $days_inactive
                            }')
                        
                        candidates+=("$candidate")
                        
                        log "INFO" "Found deletion candidate: $hostname ($serial_number) - inactive for $days_since_fetch days"
                    fi
                fi
            else
                log "WARN" "Device $serial_number has no last_fetched timestamp in Fleet"
            fi
        else
            log "DEBUG" "Device $serial_number exists in ABM but not in Fleet"
        fi
    done <<< "$abm_devices"
    
    # Save candidates to file
    printf '%s\n' "${candidates[@]}" | jq -s '.' > "$CANDIDATES_FILE"
    
    local candidate_count
    candidate_count=$(jq '. | length' "$CANDIDATES_FILE")
    log "INFO" "Identified $candidate_count devices eligible for deletion from Fleet"
    
    return 0
}

# Display deletion candidates
display_candidates() {
    log "INFO" "Deletion candidates summary:"
    echo ""
    echo "=========================================="
    echo "DEVICES ELIGIBLE FOR DELETION FROM FLEET"
    echo "=========================================="
    echo ""
    
    if [[ ! -f "$CANDIDATES_FILE" ]] || [[ $(jq '. | length' "$CANDIDATES_FILE") -eq 0 ]]; then
        echo "No devices found eligible for deletion."
        echo ""
        return 0
    fi
    
    # Display candidates in a table format
    printf "%-20s %-30s %-15s %-12s\n" "SERIAL NUMBER" "HOSTNAME" "DAYS INACTIVE" "LAST FETCHED"
    printf "%-20s %-30s %-15s %-12s\n" "-------------------" "------------------------------" "---------------" "------------"
    
    jq -r '.[] | "\(.serial_number) \(.hostname) \(.days_inactive) \(.last_fetched)"' "$CANDIDATES_FILE" | \
    while IFS=' ' read -r serial hostname days last_fetched; do
        printf "%-20s %-30s %-15s %-12s\n" "$serial" "$hostname" "$days" "$last_fetched"
    done
    
    echo ""
    echo "Total devices eligible for deletion: $(jq '. | length' "$CANDIDATES_FILE")"
    echo ""
}

# Delete devices from Fleet (if not in dry-run mode)
delete_fleet_devices() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would delete $(jq '. | length' "$CANDIDATES_FILE") devices from Fleet"
        return 0
    fi
    
    local candidate_count
    candidate_count=$(jq '. | length' "$CANDIDATES_FILE")
    
    if [[ $candidate_count -eq 0 ]]; then
        log "INFO" "No devices to delete"
        return 0
    fi
    
    log "WARN" "Proceeding to delete $candidate_count devices from Fleet..."
    
    local deleted_count=0
    local failed_count=0
    
    # Delete each candidate device
    jq -c '.[]' "$CANDIDATES_FILE" | while read -r candidate; do
        local fleet_id
        fleet_id=$(echo "$candidate" | jq -r '.fleet_id')
        local hostname
        hostname=$(echo "$candidate" | jq -r '.hostname')
        local serial
        serial=$(echo "$candidate" | jq -r '.serial_number')
        
        log "INFO" "Deleting device: $hostname ($serial) from Fleet..."
        
        local response
        response=$(curl -s -w "\n%{http_code}" \
            -X DELETE \
            -H "Authorization: Bearer $FLEET_API_TOKEN" \
            -H "Content-Type: application/json" \
            "$FLEET_BASE_URL/api/v1/hosts/$fleet_id" 2>/dev/null)
        
        local http_code
        http_code=$(echo "$response" | tail -n1)
        
        if [[ "$http_code" == "200" ]]; then
            log "INFO" "Successfully deleted device: $hostname ($serial)"
            ((deleted_count++))
        else
            log "ERROR" "Failed to delete device: $hostname ($serial) - HTTP $http_code"
            ((failed_count++))
        fi
    done
    
    log "INFO" "Deletion completed - Success: $deleted_count, Failed: $failed_count"
}

# Main execution function
main() {
    # Set up signal handlers
    setup_signal_handlers
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    
    log "INFO" "Starting $SCRIPT_NAME"
    log "INFO" "Fleet inactivity threshold: $FLEET_INACTIVITY_DAYS days"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN MODE: No actual deletions will be performed"
    fi
    
    # Verify dependencies and configuration
    verify_dependencies
    verify_config
    
    # Fetch device inventories
    if ! fetch_abm_devices; then
        log "ERROR" "Failed to fetch ABM devices"
        exit 1
    fi
    
    if ! fetch_fleet_devices; then
        log "ERROR" "Failed to fetch Fleet devices"
        exit 1
    fi
    
    # Identify deletion candidates
    if ! identify_deletion_candidates; then
        log "ERROR" "Failed to identify deletion candidates"
        exit 1
    fi
    
    # Display candidates
    display_candidates
    
    # Delete devices (if not in dry-run mode)
    delete_fleet_devices
    
    log "INFO" "$SCRIPT_NAME completed successfully"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Apple Business Manager & Fleet Device Cleanup Script

This script compares device inventories between Apple Business Manager and Fleet
to identify devices that can be safely deleted from Fleet. Devices are eligible
for deletion if they exist in ABM and haven't been seen in Fleet for 30+ days.

OPTIONS:
    --dry-run              Show what would be deleted without actually deleting
    --verbose              Enable verbose logging
    --help                 Show this help message

ENVIRONMENT VARIABLES:
    ABM_KEY_ID             Apple Business Manager Key ID
    ABM_ISSUER_ID          Apple Business Manager Issuer ID  
    ABM_PRIVATE_KEY_PATH   Path to Apple Business Manager private key file
    FLEET_BASE_URL         Fleet server base URL
    FLEET_API_TOKEN        Fleet API authentication token
    FLEET_INACTIVITY_DAYS  Days of inactivity threshold (default: 30)
    DRY_RUN                Set to 'true' for dry-run mode
    VERBOSE                Set to 'true' for verbose logging

EXAMPLES:
    # Dry run to see what would be deleted
    DRY_RUN=true $0
    
    # Set custom inactivity threshold
    FLEET_INACTIVITY_DAYS=60 $0
    
    # Verbose logging
    VERBOSE=true $0

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                readonly DRY_RUN=true
                shift
                ;;
            --verbose)
                readonly VERBOSE=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Execute main function
parse_args "$@"
main "$@"
