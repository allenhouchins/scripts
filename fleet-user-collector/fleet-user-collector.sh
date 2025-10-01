#!/bin/bash

# =============================================================================
# FLEET USER DATA COLLECTOR
# =============================================================================
# 
# This script collects user information from Fleet API including:
# - User list with creation and update timestamps
# - Active session information
# - User roles and team memberships
#
# Usage: ./fleet-user-collector.sh [options]
#
# =============================================================================

# Configuration
SCRIPT_NAME="Fleet User Data Collector"
VERSION="1.0.0"
DEFAULT_OUTPUT_FORMAT="table"
DEFAULT_VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "DEBUG")
            if [[ "$VERBOSE" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION

DESCRIPTION:
    Collects comprehensive user information from Fleet API including user details,
    creation/update timestamps, and active session information.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -u, --url URL           Fleet server URL (required)
    -t, --token TOKEN       API token (required)
    -f, --format FORMAT     Output format: table, json, csv (default: table)
    -o, --output FILE       Output file (default: stdout)
    --sessions              Include active session information
    --teams                 Include team membership information
    --roles                 Include role information
    --all                   Include all available information

EXAMPLES:
    # Basic user list
    $0 -u https://fleet.example.com -t your-api-token

    # Full user data with sessions
    $0 -u https://fleet.example.com -t your-api-token --all

    # JSON output to file
    $0 -u https://fleet.example.com -t your-api-token -f json -o users.json

    # CSV output with sessions
    $0 -u https://fleet.example.com -t your-api-token -f csv --sessions

REQUIREMENTS:
    - curl (for API requests)
    - jq (for JSON processing)
    - bash 4.0+

AUTHENTICATION:
    Get your API token from Fleet UI: Profile > Get API token
    Or use: curl -X POST "https://your-fleet-server/api/v1/fleet/login" \\
        -H "Content-Type: application/json" \\
        -d '{"email":"your-email","password":"your-password"}'

EOF
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "INFO" "Please install missing dependencies and try again"
        exit 1
    fi
}

validate_url() {
    local url="$1"
    if [[ -z "$url" ]]; then
        log "ERROR" "Fleet URL is required"
        exit 1
    fi
    
    # Remove trailing slash
    url="${url%/}"
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        log "ERROR" "Invalid URL format. Must start with http:// or https://"
        exit 1
    fi
    
    echo "$url"
}

# =============================================================================
# API FUNCTIONS
# =============================================================================

make_api_request() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="$3"
    local url="${FLEET_URL}${endpoint}"
    
    log "DEBUG" "Making $method request to: $url" >&2
    
    local curl_args=(
        -s
        -w "\n%{http_code}"
        -H "Authorization: Bearer $FLEET_TOKEN"
        -H "Content-Type: application/json"
    )
    
    if [[ "$method" == "POST" && -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    local response
    response=$(curl "${curl_args[@]}" -X "$method" "$url" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to connect to Fleet server" >&2
        return 1
    fi
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')
    
    log "DEBUG" "HTTP Status: $http_code" >&2
    
    case "$http_code" in
        200|201)
            echo "$body"
            return 0
            ;;
        401)
            log "ERROR" "Authentication failed. Please check your API token" >&2
            return 1
            ;;
        403)
            log "ERROR" "Access forbidden. Please check your permissions" >&2
            return 1
            ;;
        404)
            log "ERROR" "API endpoint not found: $endpoint" >&2
            return 1
            ;;
        429)
            log "ERROR" "Rate limit exceeded. Please try again later" >&2
            return 1
            ;;
        500)
            log "ERROR" "Internal server error" >&2
            return 1
            ;;
        *)
            log "ERROR" "API request failed with status: $http_code" >&2
            log "DEBUG" "Response: $body" >&2
            return 1
            ;;
    esac
}

get_users() {
    log "INFO" "Fetching user list..." >&2
    
    local response
    response=$(make_api_request "/api/v1/fleet/users")
    
    if [[ $? -eq 0 ]]; then
        echo "$response"
    else
        return 1
    fi
}

get_sessions() {
    log "INFO" "Fetching active sessions..." >&2
    
    local response
    response=$(make_api_request "/api/v1/fleet/sessions")
    
    if [[ $? -eq 0 ]]; then
        echo "$response"
    else
        return 1
    fi
}

get_teams() {
    log "INFO" "Fetching team information..." >&2
    
    local response
    response=$(make_api_request "/api/v1/fleet/teams")
    
    if [[ $? -eq 0 ]]; then
        echo "$response"
    else
        return 1
    fi
}

# =============================================================================
# DATA PROCESSING FUNCTIONS
# =============================================================================

process_user_data() {
    local users_json="$1"
    local sessions_json="$2"
    local teams_json="$3"
    
    log "INFO" "Processing user data..." >&2
    
    # Debug: Check if we have valid JSON
    if ! echo "$users_json" | jq empty 2>/dev/null; then
        log "ERROR" "Invalid JSON in users data" >&2
        return 1
    fi
    
    # Process users and add session/team information
    echo "$users_json" | jq -r '
        [.users[] | {
            id: .id,
            name: .name,
            email: .email,
            enabled: (.api_only | not),  # Users are enabled if not api_only
            created_at: .created_at,
            updated_at: .updated_at,
            global_role: .global_role,
            sso_enabled: .sso_enabled,
            mfa_enabled: .mfa_enabled,
            teams: .teams,
            active_sessions: []
        }]
    '
}

format_table_output() {
    local data="$1"
    
    log "INFO" "Formatting table output..."
    
    echo -e "\n${CYAN}=== FLEET USER INFORMATION ===${NC}\n"
    
    # Header
    printf "%-4s %-20s %-30s %-8s %-20s %-20s %-12s %-6s %-6s %-6s\n" \
        "ID" "Name" "Email" "Enabled" "Created" "Updated" "Role" "SSO" "MFA" "Sessions"
    printf "%-4s %-20s %-30s %-8s %-20s %-20s %-12s %-6s %-6s %-6s\n" \
        "----" "--------------------" "------------------------------" "--------" "--------------------" "--------------------" "------------" "------" "------" "--------"
    
    # Data rows - process each user object
    echo "$data" | jq -r '.[] | 
        "\(.id) \(.name // "N/A") \(.email) \(.enabled) \(.created_at) \(.updated_at) \(.global_role // "N/A") \(.sso_enabled) \(.mfa_enabled) \(.active_sessions | length)"
    ' | while IFS=' ' read -r id name email enabled created updated role sso mfa sessions; do
        # Format dates (try both GNU date and BSD date)
        created_formatted=$(date -d "$created" '+%Y-%m-%d %H:%M' 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$created")
        updated_formatted=$(date -d "$updated" '+%Y-%m-%d %H:%M' 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$updated")
        
        # Truncate long fields
        name_truncated=$(echo "$name" | cut -c1-20)
        email_truncated=$(echo "$email" | cut -c1-30)
        
        printf "%-4s %-20s %-30s %-8s %-20s %-20s %-12s %-6s %-6s %-6s\n" \
            "$id" "$name_truncated" "$email_truncated" "$enabled" "$created_formatted" "$updated_formatted" "$role" "$sso" "$mfa" "$sessions"
    done
    
    echo ""
}

format_json_output() {
    local data="$1"
    
    log "INFO" "Formatting JSON output..."
    echo "$data" | jq '.'
}

format_csv_output() {
    local data="$1"
    
    log "INFO" "Formatting CSV output..."
    
    # CSV header
    echo "id,name,email,enabled,created_at,updated_at,global_role,sso_enabled,mfa_enabled,active_sessions_count,teams"
    
    # CSV data - process each user object
    echo "$data" | jq -r '.[] | 
        [
            .id,
            (.name // "N/A"),
            .email,
            .enabled,
            .created_at,
            .updated_at,
            (.global_role // "N/A"),
            .sso_enabled,
            .mfa_enabled,
            (.active_sessions | length),
            (.teams | map(.name) | join(";"))
        ] | @csv
    '
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Default values
    FLEET_URL=""
    FLEET_TOKEN=""
    OUTPUT_FORMAT="$DEFAULT_OUTPUT_FORMAT"
    OUTPUT_FILE=""
    VERBOSE="$DEFAULT_VERBOSE"
    INCLUDE_SESSIONS=false
    INCLUDE_TEAMS=false
    INCLUDE_ROLES=false
    INCLUDE_ALL=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -u|--url)
                FLEET_URL=$(validate_url "$2")
                shift 2
                ;;
            -t|--token)
                FLEET_TOKEN="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --sessions)
                INCLUDE_SESSIONS=true
                shift
                ;;
            --teams)
                INCLUDE_TEAMS=true
                shift
                ;;
            --roles)
                INCLUDE_ROLES=true
                shift
                ;;
            --all)
                INCLUDE_ALL=true
                shift
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$FLEET_URL" ]]; then
        log "ERROR" "Fleet URL is required. Use -u or --url"
        exit 1
    fi
    
    if [[ -z "$FLEET_TOKEN" ]]; then
        log "ERROR" "API token is required. Use -t or --token"
        exit 1
    fi
    
    # Validate output format
    case "$OUTPUT_FORMAT" in
        table|json|csv)
            ;;
        *)
            log "ERROR" "Invalid output format: $OUTPUT_FORMAT. Use: table, json, or csv"
            exit 1
            ;;
    esac
    
    # Check dependencies
    check_dependencies
    
    log "INFO" "Starting $SCRIPT_NAME v$VERSION"
    log "INFO" "Fleet URL: $FLEET_URL"
    log "INFO" "Output format: $OUTPUT_FORMAT"
    
    # Collect data
    local users_data sessions_data teams_data processed_data
    
    # Get users
    users_data=$(get_users)
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to fetch users"
        exit 1
    fi
    
    # Get sessions if requested
    if [[ "$INCLUDE_SESSIONS" == "true" || "$INCLUDE_ALL" == "true" ]]; then
        sessions_data=$(get_sessions)
        if [[ $? -ne 0 ]]; then
            log "WARN" "Failed to fetch sessions, continuing without session data"
            sessions_data='{"sessions":[]}'
        fi
    else
        sessions_data='{"sessions":[]}'
    fi
    
    # Get teams if requested
    if [[ "$INCLUDE_TEAMS" == "true" || "$INCLUDE_ALL" == "true" ]]; then
        teams_data=$(get_teams)
        if [[ $? -ne 0 ]]; then
            log "WARN" "Failed to fetch teams, continuing without team data"
            teams_data='{"teams":[]}'
        fi
    else
        teams_data='{"teams":[]}'
    fi
    
    # Process data
    processed_data=$(process_user_data "$users_data" "$sessions_data" "$teams_data")
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to process user data"
        exit 1
    fi
    
    # Debug: Check processed data
    if [[ "$VERBOSE" == "true" ]]; then
        log "DEBUG" "Processed data length: ${#processed_data}"
        log "DEBUG" "First 200 chars: ${processed_data:0:200}"
    fi
    
    # Format and output
    case "$OUTPUT_FORMAT" in
        table)
            if [[ -n "$OUTPUT_FILE" ]]; then
                format_table_output "$processed_data" > "$OUTPUT_FILE"
                log "INFO" "Table output saved to: $OUTPUT_FILE"
            else
                format_table_output "$processed_data"
            fi
            ;;
        json)
            if [[ -n "$OUTPUT_FILE" ]]; then
                format_json_output "$processed_data" > "$OUTPUT_FILE"
                log "INFO" "JSON output saved to: $OUTPUT_FILE"
            else
                format_json_output "$processed_data"
            fi
            ;;
        csv)
            if [[ -n "$OUTPUT_FILE" ]]; then
                format_csv_output "$processed_data" > "$OUTPUT_FILE"
                log "INFO" "CSV output saved to: $OUTPUT_FILE"
            else
                format_csv_output "$processed_data"
            fi
            ;;
    esac
    
    log "INFO" "Data collection completed successfully"
}

# Run main function with all arguments
main "$@"
