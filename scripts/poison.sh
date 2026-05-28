#!/usr/bin/env bash
# poison.sh — Inject negative sentiment into the travel planner to trigger Splunk alerts
#
# Usage:
#   ./scripts/poison.sh              → poison all 5 agents (full demo)
#   ./scripts/poison.sh light        → poison 1 agent (subtle, single span affected)
#   ./scripts/poison.sh [APP_URL]    → target a different host
#
# What it does:
#   Sends a travel request with poison_config that injects negative sentiment
#   into agent outputs. DeepEval scores the sentiment as failed → alert fires
#   in Splunk IM within ~2-3 minutes.

set -euo pipefail

APP_URL="${1:-http://localhost:8080}"
MODE="${2:-full}"

echo "======================================================"
echo " Poison Injection"
echo " Target: ${APP_URL}"
echo " Mode:   ${MODE}"
echo "======================================================"
echo ""

if [[ "$MODE" == "light" ]]; then
  MAX=1
  echo "==> Light poison: 1 agent affected"
else
  MAX=5
  echo "==> Full poison: all 5 agents affected"
fi

echo "==> Sending poisoned request..."
RESPONSE=$(curl -s -X POST "${APP_URL}/travel/plan" \
  -H "Content-Type: application/json" \
  -d "{
    \"origin\": \"New York\",
    \"destination\": \"Paris\",
    \"user_request\": \"Planning a week-long trip. Looking for boutique hotel and unique experiences.\",
    \"travellers\": 2,
    \"poison_config\": {
      \"prob\": 1.0,
      \"types\": [\"negative_sentiment\"],
      \"max\": ${MAX}
    }
  }")

SESSION_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','N/A'))" 2>/dev/null || echo "N/A")

echo ""
echo "  session_id: ${SESSION_ID}"
echo ""
echo "======================================================"
echo " Poison injected! What to do next:"
echo ""
echo "  1. Wait ~2-3 minutes for DeepEval to score the response"
echo "  2. Open Splunk IM → check for triggered alert"
echo "  3. Drill into the trace in Splunk APM (session_id: ${SESSION_ID})"
echo "  4. Look for sentiment score = 0 on agent spans"
echo "======================================================"
