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

# Validate required environment variables
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

# Set default values for optional environment variables
IPV4_API_URL="${IPV4_API_URL:-https://api.ipify.org}"
IPV6_API_URL="${IPV6_API_URL:-https://api6.ipify.org}"
DATA_DIR="${DATA_DIR:-/data}"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

### IPv4 A Record Update
if [ -n "$A_RECORD_ID" ]; then
    echo "=== IPv4 A Record Update ==="
    NEW_IP=$(curl -s "$IPV4_API_URL")
    echo "Current IPv4: $NEW_IP"

    IP_CACHE_FILE="$DATA_DIR/current_ip.txt"

    # Check if cache file exists, create if not
    if [ ! -f "$IP_CACHE_FILE" ]; then
        echo "Cache file not found, creating new file..."
        echo "" > "$IP_CACHE_FILE"
    fi

    CURRENT_IP=$(cat "$IP_CACHE_FILE")

    if [ "$NEW_IP" = "$CURRENT_IP" ]; then
        echo "No change in IPv4 address"
    else
        echo "IPv4 address changed from '$CURRENT_IP' to '$NEW_IP', updating DNS..."

        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${A_RECORD_ID}" \
            -H "Authorization: Bearer ${API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"${A_RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":1,\"proxied\":false}")

        # Check if the update was successful
        if echo "$RESPONSE" | grep -q '"success":true'; then
            echo "Successfully updated IPv4 A record${A_RECORD_NAME:+ for $A_RECORD_NAME}"
            echo "$NEW_IP" > "$IP_CACHE_FILE"
        else
            echo "Failed to update IPv4 A record: $RESPONSE"
            exit 1
        fi
    fi
else
    echo "A_RECORD_ID not set, skipping IPv4 update"
fi

### IPv6 AAAA Record Update
if [ -n "$AAAA_RECORD_ID" ]; then
    echo "=== IPv6 AAAA Record Update ==="
    NEW_IP_6=$(curl -s "$IPV6_API_URL")
    echo "Current IPv6: $NEW_IP_6"

    IPV6_CACHE_FILE="$DATA_DIR/current_ipv6.txt"

    # Check if cache file exists, create if not
    if [ ! -f "$IPV6_CACHE_FILE" ]; then
        echo "Cache file not found, creating new file..."
        echo "" > "$IPV6_CACHE_FILE"
    fi

    CURRENT_IP_6=$(cat "$IPV6_CACHE_FILE")

    if [ "$NEW_IP_6" = "$CURRENT_IP_6" ]; then
        echo "No change in IPv6 address"
    else
        echo "IPv6 address changed from '$CURRENT_IP_6' to '$NEW_IP_6', updating DNS..."

        RESPONSE_IPV6=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${AAAA_RECORD_ID}" \
            -H "Authorization: Bearer ${API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"AAAA\",\"name\":\"${AAAA_RECORD_NAME}\",\"content\":\"${NEW_IP_6}\",\"ttl\":1,\"proxied\":false}")

        # Check if the update was successful
        if echo "$RESPONSE_IPV6" | grep -q '"success":true'; then
            echo "Successfully updated IPv6 AAAA record${AAAA_RECORD_NAME:+ for $AAAA_RECORD_NAME}"
            echo "$NEW_IP_6" > "$IPV6_CACHE_FILE"
        else
            echo "Failed to update IPv6 AAAA record: $RESPONSE_IPV6"
            exit 1
        fi
    fi
else
    echo "AAAA_RECORD_ID not set, skipping IPv6 update"
fi

echo "=== DDNS update completed ==="
