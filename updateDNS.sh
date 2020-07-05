#!/bin/sh

# GET Recore ID
#curl -x get "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" \
#-h "x-auth-email:YOUR_EMAIL@gmail.com" \
#-h "x-auth-key:YOUR_GLOBAL_API_KEY" \
#-h "content-type: application/json"


NEW_IP=`curl -s http://ipv4.icanhazip.com`
CURRENT_IP=`cat current_ip.txt`

if [ "$NEW_IP" = "$CURRENT_IP" ]
then
        echo "No Change in IP Adddress"
else
curl -X PUT "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records/YOUR_DNS_RECORDS" \
     -H "X-Auth-Email: YOUR_EMAIL@gmail.com" \
     -H "X-Auth-Key: YOUR_GLOBAL_API_KEY" \
     -H "Content-Type: application/json" \
     --data '{"type":"A","name":"YOUR_A_RECORD_NAME","content":"'$NEW_IP'","proxied":false}' > /dev/null
echo $NEW_IP > current_ip.txt
fi
