#!/bin/bash

# Load external variables
source /opt/cloudflare-failover/config.env

# Ensure required variables and defaults
TTL_SECONDS=${TTL_SECONDS:-1}
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$DOMAINS_FILE" ]; then
		echo "CF_API_TOKEN, CF_ZONE_ID and DOMAINS_FILE are required."
		exit 1
fi

DOMAINS=($(cat "$DOMAINS_FILE"))

get_record_id() {
    local domain=$1
    local ip=$2

    # Fetch records for the name and filter by content via jq (avoids encoding/URL issues)
    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$domain&per_page=100" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    echo "$RESPONSE" | jq -r '.result[] | select(.content == "'"$ip"'") | .id' | head -n1
}

delete_record() {
    local record_id=$1

    RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$(echo "$RESPONSE" | jq -r '.success')" != "true" ]; then
        echo "  Error removing record (ID: $record_id): $(echo "$RESPONSE" | jq -r '.errors[]?.message // "unknown")')"
    fi
}

create_record() {
    local domain=$1
    local ip=$2

    # Ensure TTL is numeric (Cloudflare expects integer). Default to 1 (auto) if invalid.
    if [[ "$TTL_SECONDS" =~ ^[0-9]+$ ]]; then
        TTL_VAL=$TTL_SECONDS
    else
        TTL_VAL=1
    fi

    RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$domain"'","content":"'"$ip"'","ttl":'"$TTL_VAL"',"proxied":true}')

    if [ "$(echo "$RESPONSE" | jq -r '.success')" == "true" ]; then
        echo "  Record created successfully for $domain -> $ip"
    else
        echo "  Error creating record for $domain -> $ip: $(echo "$RESPONSE" | jq -r '.errors[]?.message // "unknown")')"
    fi
}

monitor_link() {
    local link_ip=$1
    local link_name=$2

    echo -n "$(date '+%Y-%m-%d %H:%M:%S') - Checking $link_name ($link_ip)... "

    if ping -c 2 -W 1 $link_ip > /dev/null 2>&1; then
        STATUS="UP"
        echo "ONLINE"
    else
        STATUS="DOWN"
        echo "OFFLINE"
    fi

    for domain in "${DOMAINS[@]}"; do
        RECORD_ID=$(get_record_id "$domain" "$link_ip")

        if [ "$STATUS" == "DOWN" ]; then
            if [ -n "$RECORD_ID" ]; then
                echo "  Removing A record for $domain..."
                delete_record "$RECORD_ID"
            else
                echo "  Record already removed for $domain."
            fi
        else
            if [ -z "$RECORD_ID" ]; then
                echo "  Creating A record for $domain -> $link_ip"
                create_record "$domain" "$link_ip"
            else
                echo "  Record OK for $domain (ID: $RECORD_ID)"
            fi
        fi
    done
}

echo "----------------------------------------------------------"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Health check started"
echo "----------------------------------------------------------"

monitor_link "$IP_LINK1" "Link 1"
monitor_link "$IP_LINK2" "Link 2"

echo "----------------------------------------------------------"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Finished"
echo "----------------------------------------------------------"
