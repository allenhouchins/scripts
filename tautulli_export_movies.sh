#!/bin/bash

# =============================================================================
# TAUTULLI WATCHED MOVIES EXPORTER
# =============================================================================

# Configuration
API_KEY="10AXi3Q7KS1pahcNfKEcL4nk5qp34huX"
SERVER_URL="http://192.168.1.100:8181"
OUTPUT_FILE="watched_movies_$(date +%Y%m%d_%H%M%S).txt"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

check_dependencies() {
    if ! command -v curl &> /dev/null; then
        echo "❌ Error: curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: jq is required but not installed"
        echo "Install with: brew install jq"
        exit 1
    fi
}

test_connection() {
    echo "🔍 Testing connection to Tautulli server..."
    
    local response=$(curl -s "${SERVER_URL}/api/v2?apikey=${API_KEY}&cmd=status")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Cannot connect to Tautulli server at ${SERVER_URL}"
        exit 1
    fi
    
    local status=$(echo "$response" | jq -r '.response.result')
    
    if [[ "$status" != "success" ]]; then
        echo "❌ Error: API test failed. Response: $response"
        exit 1
    fi
    
    echo "✅ Connection successful"
}

# =============================================================================
# API FUNCTIONS
# =============================================================================

get_user_list() {
    echo "📋 Fetching user list..."
    
    local response=$(curl -s "${SERVER_URL}/api/v2?apikey=${API_KEY}&cmd=get_users")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Failed to fetch user list"
        exit 1
    fi
    
    local status=$(echo "$response" | jq -r '.response.result')
    
    if [[ "$status" != "success" ]]; then
        echo "❌ Error: Failed to get user list. Response: $response"
        exit 1
    fi
    
    # Extract user IDs and names
    echo "$response" | jq -r '.response.data[] | "\(.user_id)|\(.username)"'
}

get_watched_movies() {
    local user_id="$1"
    local username="$2"
    
    echo "🎬 Fetching watched movies for user: $username (ID: $user_id)"
    
    local response=$(curl -s "${SERVER_URL}/api/v2?apikey=${API_KEY}&cmd=get_history&user_id=${user_id}&media_type=movie&length=1000")
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Error: Failed to fetch watched movies for user $username"
        return 1
    fi
    
    local status=$(echo "$response" | jq -r '.response.result')
    
    if [[ "$status" != "success" ]]; then
        echo "❌ Error: Failed to get watched movies for user $username. Response: $response"
        return 1
    fi
    
    # Extract movie data and sort by watched date
    echo "$response" | jq -r '
        .response.data.data[] | 
        select(.watched_status == 1) |
        "\(if .date then (.date | strftime("%Y-%m-%d %H:%M:%S")) else "Unknown" end)|\(.title)|\(.year)"
    ' | sort -t'|' -k1,1
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    echo "🎬 Tautulli Watched Movies Exporter"
    echo "==================================="
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Test connection
    test_connection
    
    echo ""
    echo "📊 Starting export process..."
    echo ""
    
    # Get user list
    local users=$(get_user_list)
    
    if [[ -z "$users" ]]; then
        echo "❌ Error: No users found"
        exit 1
    fi
    
    # Create output file
    echo "📝 Creating output file: $OUTPUT_FILE"
    echo "Tautulli Watched Movies Export - $(date)" > "$OUTPUT_FILE"
    echo "Generated: $(date)" >> "$OUTPUT_FILE"
    echo "Server: $SERVER_URL" >> "$OUTPUT_FILE"
    echo "================================================" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Format: Watched Date|Title|Year" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Process each user
    local total_movies=0
    
    while IFS='|' read -r user_id username; do
        if [[ -n "$user_id" && -n "$username" ]]; then
            echo "Processing user: $username"
            
            # Get watched movies for this user
            local user_movies=$(get_watched_movies "$user_id" "$username")
            
            if [[ -n "$user_movies" ]]; then
                echo "$user_movies" >> "$OUTPUT_FILE"
                local movie_count=$(echo "$user_movies" | wc -l | tr -d ' ')
                total_movies=$((total_movies + movie_count))
                echo "  ✅ Found $movie_count movies"
            else
                echo "  ⚠️  No watched movies found"
            fi
            
            echo ""
        fi
    done <<< "$users"
    
    # Add summary
    echo "" >> "$OUTPUT_FILE"
    echo "================================================" >> "$OUTPUT_FILE"
    echo "Summary:" >> "$OUTPUT_FILE"
    echo "Total movies: $total_movies" >> "$OUTPUT_FILE"
    echo "Export completed: $(date)" >> "$OUTPUT_FILE"
    
    echo ""
    echo "✅ Export completed successfully!"
    echo "📁 Output file: $OUTPUT_FILE"
    echo "📊 Total movies exported: $total_movies"
    echo ""
    echo "📋 Sample of exported data:"
    echo "----------------------------"
    head -10 "$OUTPUT_FILE"
    
    if [[ $total_movies -gt 10 ]]; then
        echo "..."
        echo "(showing first 10 entries, see file for complete list)"
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
