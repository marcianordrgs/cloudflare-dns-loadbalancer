#!/bin/bash

# Carregar variáveis externas
source /opt/cloudflare-failover/config.env

# Garantir variáveis obrigatórias e defaults
TTL_SECONDS=${TTL_SECONDS:-1}
if [ -z "$CF_API_TOKEN" ] || [ -z "$CF_ZONE_ID" ] || [ -z "$DOMAINS_FILE" ]; then
		echo "Variáveis CF_API_TOKEN, CF_ZONE_ID e DOMAINS_FILE são obrigatórias."
		exit 1
fi

DOMAINS=($(cat "$DOMAINS_FILE"))

get_record_id() {
    local domain=$1
    local ip=$2

    # Buscar registros para o nome e filtrar pelo conteúdo via jq (evita problemas de encoding/URL)
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
        echo "  Erro removendo registro (ID: $record_id): $(echo "$RESPONSE" | jq -r '.errors[]?.message // "unknown")')"
    fi
}

create_record() {
    local domain=$1
    local ip=$2

    # Garantir TTL numérico (Cloudflare espera inteiro). Default para 1 (auto) se inválido.
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
        echo "  Registro criado com sucesso para $domain -> $ip"
    else
        echo "  Erro criando registro para $domain -> $ip: $(echo "$RESPONSE" | jq -r '.errors[]?.message // "unknown")')"
    fi
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
