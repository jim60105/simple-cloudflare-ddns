#!/bin/sh

### HOW TO
# How to get zone id: https://api.cloudflare.com/#zone-list-zones
# curl -X GET "https://api.cloudflare.com/client/v4/zones" \
#         -H "X-Auth-Email: EMAIL" \
#         -H "X-Auth-Key: GLOBAL_API_KEY"

# How to get dns_records id: https://api.cloudflare.com/#dns-records-for-a-zone-list-dns-records
# curl -X GET "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records/" \
#         -H "X-Auth-Email: EMAIL" \
#         -H "X-Auth-Key: GLOBAL_API_KEY"

### Parameters
EMAIL="a@gmail.com"
ZONE_ID="123123123asdfasdfasdf"
GLOBAL_API_KEY="123123123asdfasdfasdf"
A_RECORD_NAME="xx.example.com"
A_RECORD_ID="123123123asdfasdfasdf"
AAAA_RECORD_NAME="xx.example.com"
AAAA_RECORD_ID="123123123asdfasdfasdf"

### IPv4 A Record
NEW_IP=$(curl -s https://api.ipify.org)
echo $NEW_IP
CURRENT_IP=$(cat current_ip.txt)

if [ "$NEW_IP" = "$CURRENT_IP" ]; then
        echo "No Change in IP Adddress"
else
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${A_RECORD_ID}" \
                -H "X-Auth-Email: ${EMAIL}" \
                -H "X-Auth-Key: ${GLOBAL_API_KEY}" \
                -H "Content-Type: application/json" \
                --data '{"type":"A","name":"'$A_RECORD_NAME'","content":"'$NEW_IP'","proxied":false}' >/dev/null
        echo $NEW_IP >current_ip.txt
fi


### IPv6 AAAA Record
NEW_IP_6=$(curl -s https://api6.ipify.org)
echo $NEW_IP_6
CURRENT_IP_6=$(cat current_ipv6.txt)

if [ "$NEW_IP_6" = "$CURRENT_IP_6" ]; then
        echo "No Change in IPv6 Adddress"
else
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${AAAA_RECORD_ID}" \
                -H "X-Auth-Email: ${EMAIL}" \
                -H "X-Auth-Key: ${GLOBAL_API_KEY}" \
                -H "Content-Type: application/json" \
                --data '{"type":"AAAA","name":"'$AAAA_RECORD_NAME'","content":"'$NEW_IP_6'","proxied":false}' >/dev/null
        echo $NEW_IP_6 >current_ipv6.txt
fi
