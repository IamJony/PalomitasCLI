#!/bin/bash
# quick_search.sh - Búsqueda rápida en PeliMeli

source config.sh

if [ $# -eq 0 ]; then
    echo "Uso: $0 <término>"
    exit 1
fi

KEYWORD=$(echo "$*" | sed 's/ /%20/g')
init_session

curl -s "$API_URL/search/?keyword=$KEYWORD&nonce=$NONCE" \
  -b "$COOKIE_FILE" \
  -H "User-Agent: $USER_AGENT" \
  -H "Accept: application/json" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Referer: $BASE_URL" \
  --compressed | jq '.' > buscar.json

