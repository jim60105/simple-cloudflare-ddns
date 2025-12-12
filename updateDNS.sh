#!/bin/sh
# Copyright (C) 2020 陳鈞, licensed under AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ==================================================================
#
# Simple Cloudflare DDNS Updater
# This script updates Cloudflare DNS A/AAAA records with your current public IP.
#
# ENVIRONMENT VARIABLES (Required):
#   API_TOKEN       - Cloudflare API Token with Zone:DNS:Edit permission
#   ZONE_ID         - Cloudflare Zone ID
#
# ENVIRONMENT VARIABLES (Optional - at least one record must be configured):
#   A_RECORD_ID     - DNS record ID for IPv4 A record (enables IPv4 updates)
#   A_RECORD_NAME   - Domain name for A record (default: same as record in Cloudflare)
#   AAAA_RECORD_ID  - DNS record ID for IPv6 AAAA record (enables IPv6 updates)
#   AAAA_RECORD_NAME - Domain name for AAAA record (default: same as record in Cloudflare)
#   IPV4_API_URL    - URL to get public IPv4 address (default: https://api.ipify.org)
#   IPV6_API_URL    - URL to get public IPv6 address (default: https://api6.ipify.org)
#   DATA_DIR        - Directory to store IP cache files (default: /data)
#
# HOW TO CREATE API TOKEN:
#   1. Go to https://dash.cloudflare.com/profile/api-tokens
#   2. Click "Create Token"
#   3. Use "Custom token" template
#   4. Set Token name: "DNS Update Script"
#   5. Set Permissions: Zone:DNS:Edit
#   6. Set Zone Resources: Include - All zones (or specific zones)
#   7. Click "Continue to summary" then "Create Token"
#
# HOW TO GET ZONE_ID AND RECORD_ID:
#   Zone ID can be found in your domain's overview page on Cloudflare dashboard.
#   To get dns_record IDs, run:
#   curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records/" \
#        -H "Authorization: Bearer YOUR_API_TOKEN"
#
# ==================================================================

set -e

# ==================================================================
# Utility Functions
# ==================================================================

# Validate IPv4 address format
# Returns 0 if valid IPv4, 1 otherwise
is_valid_ipv4() {
    ip="$1"
    # Check for basic IPv4 pattern: four octets separated by dots
    echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1

    # Validate each octet is between 0-255
    IFS='.' read -r o1 o2 o3 o4 <<EOF
$ip
EOF
    [ "$o1" -ge 0 ] && [ "$o1" -le 255 ] && \
    [ "$o2" -ge 0 ] && [ "$o2" -le 255 ] && \
    [ "$o3" -ge 0 ] && [ "$o3" -le 255 ] && \
    [ "$o4" -ge 0 ] && [ "$o4" -le 255 ] 2>/dev/null
}

# Validate IPv6 address format
# Returns 0 if valid IPv6, 1 otherwise
is_valid_ipv6() {
    ip="$1"
    # Check for IPv6 pattern: contains colons and hex characters
    # Also reject if it looks like an IPv4 address
    echo "$ip" | grep -qE '^[0-9a-fA-F:]+$' || return 1
    echo "$ip" | grep -q ':' || return 1
    # Reject if it matches IPv4 pattern
    echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$' && return 1
    return 0
}

# Fetch public IP address from a given URL
# Arguments: $1 = URL to fetch from
# Returns: IP address via stdout, exit code indicates success/failure
fetch_public_ip() {
    url="$1"
    ip=""
    ip=$(curl -s --max-time 30 --connect-timeout 10 "$url" 2>/dev/null) || {
        echo "Error: Failed to fetch IP from $url (network error or timeout)" >&2
        return 1
    }

    if [ -z "$ip" ]; then
        echo "Error: Empty response from $url" >&2
        return 1
    fi

    echo "$ip"
    return 0
}

# Get cached IP from file, returns empty string if file doesn't exist
# Arguments: $1 = cache file path
get_cached_ip() {
    cache_file="$1"
    if [ -f "$cache_file" ]; then
        cat "$cache_file"
    else
        echo ""
    fi
}

# Update DNS record via Cloudflare API
# Arguments: $1=record_id, $2=record_type, $3=record_name, $4=ip_content
# Returns: 0 on success, 1 on failure
update_cloudflare_dns() {
    record_id="$1"
    record_type="$2"
    record_name="$3"
    ip_content="$4"

    response=$(curl -s --max-time 30 -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${ip_content}\",\"ttl\":1,\"proxied\":false}" 2>/dev/null) || {
        echo "Error: Failed to connect to Cloudflare API" >&2
        return 1
    }

    if echo "$response" | grep -q '"success":true'; then
        return 0
    else
        echo "API Error: $response" >&2
        return 1
    fi
}

# ==================================================================
# Record Update Functions
# ==================================================================

# Update IPv4 A record
# Returns: 0 on success or skip, 1 on error (but continues execution)
update_ipv4_record() {
    echo "=== IPv4 A Record Update ==="

    if [ -z "$A_RECORD_ID" ]; then
        echo "A_RECORD_ID not set, skipping IPv4 update"
        return 0
    fi

    # Fetch current public IPv4
    new_ip=""
    if ! new_ip=$(fetch_public_ip "$IPV4_API_URL"); then
        echo "Warning: Could not fetch IPv4 address, skipping IPv4 update"
        return 0
    fi

    # Validate the fetched IP is actually IPv4
    if ! is_valid_ipv4 "$new_ip"; then
        echo "Warning: Invalid IPv4 address received: '$new_ip', skipping IPv4 update"
        return 0
    fi

    echo "Current IPv4: $new_ip"

    # Check cache
    cache_file="$DATA_DIR/current_ip.txt"
    cached_ip=$(get_cached_ip "$cache_file")

    if [ "$new_ip" = "$cached_ip" ]; then
        echo "No change in IPv4 address"
        return 0
    fi

    echo "IPv4 address changed from '$cached_ip' to '$new_ip', updating DNS..."

    if update_cloudflare_dns "$A_RECORD_ID" "A" "$A_RECORD_NAME" "$new_ip"; then
        echo "Successfully updated IPv4 A record${A_RECORD_NAME:+ for $A_RECORD_NAME}"
        echo "$new_ip" > "$cache_file"
    else
        echo "Failed to update IPv4 A record"
        return 1
    fi

    return 0
}

# Update IPv6 AAAA record
# Returns: 0 on success or skip, 1 on error (but continues execution)
update_ipv6_record() {
    echo "=== IPv6 AAAA Record Update ==="

    if [ -z "$AAAA_RECORD_ID" ]; then
        echo "AAAA_RECORD_ID not set, skipping IPv6 update"
        return 0
    fi

    # Fetch current public IPv6
    new_ip=""
    if ! new_ip=$(fetch_public_ip "$IPV6_API_URL"); then
        echo "Warning: Could not fetch IPv6 address, skipping IPv6 update"
        return 0
    fi

    # Validate the fetched IP is actually IPv6 (not IPv4)
    if ! is_valid_ipv6 "$new_ip"; then
        echo "Warning: Invalid IPv6 address received: '$new_ip' (may be IPv4), skipping IPv6 update"
        return 0
    fi

    echo "Current IPv6: $new_ip"

    # Check cache
    cache_file="$DATA_DIR/current_ipv6.txt"
    cached_ip=$(get_cached_ip "$cache_file")

    if [ "$new_ip" = "$cached_ip" ]; then
        echo "No change in IPv6 address"
        return 0
    fi

    echo "IPv6 address changed from '$cached_ip' to '$new_ip', updating DNS..."

    if update_cloudflare_dns "$AAAA_RECORD_ID" "AAAA" "$AAAA_RECORD_NAME" "$new_ip"; then
        echo "Successfully updated IPv6 AAAA record${AAAA_RECORD_NAME:+ for $AAAA_RECORD_NAME}"
        echo "$new_ip" > "$cache_file"
    else
        echo "Failed to update IPv6 AAAA record"
        return 1
    fi

    return 0
}

# ==================================================================
# Validation Functions
# ==================================================================

validate_required_env() {
    if [ -z "$API_TOKEN" ]; then
        echo "Error: API_TOKEN environment variable is required"
        exit 1
    fi

    if [ -z "$ZONE_ID" ]; then
        echo "Error: ZONE_ID environment variable is required"
        exit 1
    fi

    if [ -z "$A_RECORD_ID" ] && [ -z "$AAAA_RECORD_ID" ]; then
        echo "Error: At least one of A_RECORD_ID or AAAA_RECORD_ID must be set"
        exit 1
    fi
}

# ==================================================================
# Main Execution
# ==================================================================

main() {
    # Validate required environment variables
    validate_required_env

    # Set default values for optional environment variables
    IPV4_API_URL="${IPV4_API_URL:-https://api.ipify.org}"
    IPV6_API_URL="${IPV6_API_URL:-https://api6.ipify.org}"
    DATA_DIR="${DATA_DIR:-/data}"

    # Ensure data directory exists
    mkdir -p "$DATA_DIR"

    # Track if any update failed
    ipv4_result=0
    ipv6_result=0

    # Update records (continue even if one fails)
    update_ipv4_record || ipv4_result=1
    update_ipv6_record || ipv6_result=1

    echo "=== DDNS update completed ==="

    # Return failure if both updates were attempted and failed
    if [ -n "$A_RECORD_ID" ] && [ "$ipv4_result" -ne 0 ] && \
       [ -n "$AAAA_RECORD_ID" ] && [ "$ipv6_result" -ne 0 ]; then
        exit 1
    fi
}

main "$@"
