#!/bin/bash
# baseline.sh — Send 3 clean travel requests to build a quality score baseline in Splunk
# Usage: ./scripts/baseline.sh [APP_URL]
#   APP_URL defaults to http://localhost:8080

set -euo pipefail

APP_URL="${1:-http://localhost:8080}"

ORIGINS=("San Francisco" "New York" "London")
DESTINATIONS=("Tokyo" "Rome" "Sydney")
REQUESTS=(
  "7-day trip with cherry blossom viewing and authentic sushi experiences"
  "Long weekend city break, boutique hotel, rooftop dining and art museums"
  "Family holiday, 5 days, beach activities suitable for children aged 8 and 10"
)

echo "======================================================"
echo " Baseline Traffic Generator"
echo " Sending 3 clean requests to ${APP_URL}"
echo "======================================================"
echo ""

for i in 0 1 2; do
  echo "--- Request $((i+1))/3: ${ORIGINS[$i]} → ${DESTINATIONS[$i]} ---"
  RESPONSE=$(curl -s -X POST "${APP_URL}/travel/plan" \
    -H "Content-Type: application/json" \
    -d "{
      \"origin\": \"${ORIGINS[$i]}\",
      \"destination\": \"${DESTINATIONS[$i]}\",
      \"travellers\": 2,
      \"user_request\": \"${REQUESTS[$i]}\"
    }")

  SESSION_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','N/A'))" 2>/dev/null || echo "N/A")
  echo "  session_id: ${SESSION_ID}"
  echo "  (find this trace in Splunk APM)"
  echo ""

  if [ $i -lt 2 ]; then
    sleep 5
  fi
done

echo "======================================================"
echo " Done! Open Splunk APM and look for 3 recent traces."
echo " All scores should be above 0.8 — this is your baseline."
echo "======================================================"
