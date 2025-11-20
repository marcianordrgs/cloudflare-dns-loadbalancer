#!/bin/bash

# Carregar variáveis externas
source /opt/cloudflare-failover/config.env

DOMAINS=($(cat "$DOMAINS_FILE"))

get_record_id() {
    local domain=$1
    local ip=$2

    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$domain&content=$ip" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[] | .id'
}

delete_record() {
    local record_id=$1

    curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" > /dev/null
}

create_record() {
    local domain=$1
    local ip=$2

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$domain"'","content":"'"$ip"'","ttl":'"$TTL_SECONDS"',"proxied":true}' > /dev/null
}

monitor_link() {
    local link_ip=$1
    local link_name=$2

    echo -n "$(date '+%Y-%m-%d %H:%M:%S') - Verificando $link_name ($link_ip)... "

    if ping -c 2 -W 1 $link_ip > /dev/null 2>&1; then
        STATUS="UP"
        echo "ONLINE"
    else
        STATUS="DOWN"
        echo "CAIU"
    fi

    for domain in "${DOMAINS[@]}"; do
        RECORD_ID=$(get_record_id "$domain" "$link_ip")

        if [ "$STATUS" == "DOWN" ]; then
            if [ -n "$RECORD_ID" ]; then
                echo "  Removendo registro A de $domain..."
                delete_record "$RECORD_ID"
            else
                echo "  Registro já removido para $domain."
            fi
        else
            if [ -z "$RECORD_ID" ]; then
                echo "  Criando registro A para $domain -> $link_ip"
                create_record "$domain" "$link_ip"
            else
                echo "  Registro OK para $domain (ID: $RECORD_ID)"
            fi
        fi
    done
}

echo "----------------------------------------------------------"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Verificação iniciada"
echo "----------------------------------------------------------"

monitor_link "$IP_LINK1" "Link 1"
monitor_link "$IP_LINK2" "Link 2"

echo "----------------------------------------------------------"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Finalizado"
echo "----------------------------------------------------------"
