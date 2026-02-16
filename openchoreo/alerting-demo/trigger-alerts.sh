#!/usr/bin/env bash
# Generates traffic against the BFF to create short URLs and simulate visits.
# Usage: bash trigger-alerts.sh [-v] &

VERBOSE=false
[[ "$1" == "-v" ]] && VERBOSE=true

BFF="http://frontend-development-default.openchoreoapis.localhost:19080"

echo "=== Waiting for API to be healthy ==="
until curl -s "$BFF/api/urls?username=_ping" 2>/dev/null | grep -q '^\['; do
  sleep 2
done
echo "API is healthy."

echo "=== Creating short URLs ==="

CODE1=$(curl -s -X POST "$BFF/api/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://openchoreo.dev","username":"demo"}' | jq -r '.short_code')
echo "openchoreo.dev  -> $CODE1"

CODE2=$(curl -s -X POST "$BFF/api/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://wso2.com","username":"demo"}' | jq -r '.short_code')
echo "wso2.com        -> $CODE2"

CODE3=$(curl -s -X POST "$BFF/api/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://wso2.com/choreo","username":"demo"}' | jq -r '.short_code')
echo "wso2.com/choreo -> $CODE3"

CODES=("$CODE1" "$CODE2" "$CODE3")

echo ""
echo "=== Traffic is flowing ==="
echo "Visiting a random short URL every 2s... (kill with: kill $$)"
echo ""

while true; do
  # Visit a real URL (cached in Redis — always succeeds)
  CODE=${CODES[$((RANDOM % ${#CODES[@]}))]}
  if $VERBOSE; then
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BFF/r/$CODE")
    echo "GET /r/$CODE -> $STATUS"
  else
    curl -s -o /dev/null "$BFF/r/$CODE"
  fi
  sleep 1

  # Visit a random URL (cache miss — hits Postgres, 404 when healthy, 500 when misconfigured)
  RAND=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
  if $VERBOSE; then
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BFF/r/$RAND")
    echo "GET /r/$RAND -> $STATUS"
  else
    curl -s -o /dev/null "$BFF/r/$RAND"
  fi
  sleep 1
done
