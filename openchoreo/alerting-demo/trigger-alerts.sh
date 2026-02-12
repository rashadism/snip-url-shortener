#!/usr/bin/env bash
# Generates traffic against the BFF to create short URLs and simulate visits.
# Run before enabling the alert so traces are flowing when Redis dies.
# Usage: bash trigger-alerts.sh &

BFF="http://default.frontend-development.openchoreoapis.localhost:19080"

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
echo "When ready, delete Redis to trigger the failure scenario:"
echo "  kubectl delete component redis"
echo ""

while true; do
  CODE=${CODES[$((RANDOM % ${#CODES[@]}))]}
  curl -s -o /dev/null "$BFF/r/$CODE"
  sleep 2
done
