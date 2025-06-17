#!/bin/sh

### GPLv3
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

### HOW TO
# How to create API Token (Recommended): 
# 1. Go to https://dash.cloudflare.com/profile/api-tokens
# 2. Click "Create Token"
# 3. Use "Custom token" template
# 4. Set Token name: "DNS Update Script"
# 5. Set Permissions: Zone:DNS:Edit
# 6. Set Zone Resources: Include - All zones (or specific zones)
# 7. Click "Continue to summary" then "Create Token"
# 8. Copy the token and replace YOUR_API_TOKEN_HERE below

# How to get dns_records id: https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records
# curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records/" \
#         -H "Authorization: Bearer YOUR_API_TOKEN"

### Parameters
# Use API Token instead of Global API Key (recommended by Cloudflare)
# How to create API Token: https://dash.cloudflare.com/profile/api-tokens
# Required permissions: Zone:DNS:Edit for the zones you want to update
API_TOKEN="YOUR_API_TOKEN_HERE"

# Zone and DNS record configuration
ZONE_ID="YOUR_ZONE_ID_HERE"
A_RECORD_NAME="subdomain.example.com"
A_RECORD_ID="YOUR_A_RECORD_ID_HERE"
AAAA_RECORD_NAME="subdomain.example.com"
AAAA_RECORD_ID="YOUR_AAAA_RECORD_ID_HERE"

### IPv4 A Record
NEW_IP=$(curl -s https://api.ipify.org)
echo "Current IPv4: $NEW_IP"

# Check if current_ip.txt exists, create if not
if [ ! -f "current_ip.txt" ]; then
        echo "current_ip.txt not found, creating new file..."
        echo "" > current_ip.txt
fi

CURRENT_IP=$(cat current_ip.txt)

if [ "$NEW_IP" = "$CURRENT_IP" ]; then
        echo "No change in IPv4 address"
else
        echo "IPv4 address changed from '$CURRENT_IP' to '$NEW_IP', updating DNS..."
        
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${A_RECORD_ID}" \
                -H "Authorization: Bearer ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data '{"type":"A","name":"'$A_RECORD_NAME'","content":"'"$NEW_IP"'","ttl":1,"proxied":false}')
        
        # Check if the update was successful
        if echo "$RESPONSE" | grep -q '"success":true'; then
                echo "Successfully updated IPv4 A record for $A_RECORD_NAME"
                echo "$NEW_IP" > current_ip.txt
        else
                echo "Failed to update IPv4 A record: $RESPONSE"
        fi
fi


### IPv6 AAAA Record
NEW_IP_6=$(curl -s https://api6.ipify.org)
echo "Current IPv6: $NEW_IP_6"

# Check if current_ipv6.txt exists, create if not
if [ ! -f "current_ipv6.txt" ]; then
        echo "current_ipv6.txt not found, creating new file..."
        echo "" > current_ipv6.txt
fi

CURRENT_IP_6=$(cat current_ipv6.txt)

if [ "$NEW_IP_6" = "$CURRENT_IP_6" ]; then
        echo "No change in IPv6 address"
else
        echo "IPv6 address changed from '$CURRENT_IP_6' to '$NEW_IP_6', updating DNS..."
        
        RESPONSE_IPV6=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${AAAA_RECORD_ID}" \
                -H "Authorization: Bearer ${API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data '{"type":"AAAA","name":"'$AAAA_RECORD_NAME'","content":"'"$NEW_IP_6"'","ttl":1,"proxied":false}')
        
        # Check if the update was successful
        if echo "$RESPONSE_IPV6" | grep -q '"success":true'; then
                echo "Successfully updated IPv6 AAAA record for $AAAA_RECORD_NAME"
                echo "$NEW_IP_6" > current_ipv6.txt
        else
                echo "Failed to update IPv6 AAAA record: $RESPONSE_IPV6"
        fi
fi
