#!/usr/bin/env bash
# Heavy load test to drive up memory usage on the frontend / api-service.
# Creates one short URL (hackernews.com) then hammers it with parallel requests.
#
# Usage:
#   bash generate-load.sh                                  # 50 workers, default BFF
#   bash generate-load.sh 100                              # 100 workers
#   bash generate-load.sh 200 -v                           # 200 workers, verbose
#   bash generate-load.sh 50 -v http://localhost:9700      # custom BFF URL

set -euo pipefail

CONCURRENCY="${1:-50}"
VERBOSE=false
BFF="http://frontend-development-default.openchoreoapis.localhost:19080"

# Parse optional flags: -v and custom BFF URL
for arg in "${@:2}"; do
  case "$arg" in
    -v) VERBOSE=true ;;
    http://*|https://*) BFF="$arg" ;;
  esac
done

echo "=== Load Test ==="
echo "Target:      $BFF"
echo "Concurrency: $CONCURRENCY workers"
echo ""

# --- Wait for healthy API ---
echo "Waiting for API to be healthy..."
until curl -s "$BFF/api/urls?username=_ping" 2>/dev/null | grep -q '^\['; do
  sleep 2
done
echo "API is healthy."

# --- Create the short URL ---
echo "Creating short URL for hackernews.com..."
CODE=$(curl -s -X POST "$BFF/api/shorten" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://news.ycombinator.com","username":"loadtest"}' | jq -r '.short_code')

if [[ -z "$CODE" || "$CODE" == "null" ]]; then
  echo "ERROR: Failed to create short URL. Response:"
  curl -s -X POST "$BFF/api/shorten" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://news.ycombinator.com","username":"loadtest"}'
  echo ""
  exit 1
fi

echo "hackernews.com -> $CODE"
URL="$BFF/r/$CODE"
echo ""

# --- Stats ---
STARTED=$(date +%s)

report_stats() {
  NOW=$(date +%s)
  ELAPSED=$((NOW - STARTED))
  [[ $ELAPSED -eq 0 ]] && ELAPSED=1
  echo ""
  echo "=== Stopped after ${ELAPSED}s ==="
}
trap 'report_stats; kill 0 2>/dev/null' EXIT INT TERM

# --- Worker function ---
worker() {
  local id=$1
  while true; do
    if $VERBOSE; then
      STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
      echo "[worker-$id] GET /r/$CODE -> $STATUS"
    else
      curl -s -o /dev/null "$URL"
    fi
  done
}

echo "=== Hammering GET /r/$CODE with $CONCURRENCY workers ==="
echo "Stop with: Ctrl+C"
echo ""

# Launch workers in background
for i in $(seq 1 "$CONCURRENCY"); do
  worker "$i" &
done

# Keep alive, report progress every 5s
while true; do
  sleep 5
  NOW=$(date +%s)
  ELAPSED=$((NOW - STARTED))
  echo "[${ELAPSED}s] $CONCURRENCY workers running..."
done
