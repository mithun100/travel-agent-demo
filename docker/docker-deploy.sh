#!/usr/bin/env bash
# docker-deploy.sh — Manage travel-agent-demo Docker deployment on a VM
#
# Usage:
#   ./docker-deploy.sh              → build images and start all services (default)
#   ./docker-deploy.sh up           → same as above
#   ./docker-deploy.sh down         → stop and remove containers
#   ./docker-deploy.sh restart      → restart all services
#   ./docker-deploy.sh logs         → tail logs from all services
#   ./docker-deploy.sh logs <svc>   → tail logs for a specific service (travel-planner|loadgen|otel-collector)
#   ./docker-deploy.sh ps           → show running containers and their status
#   ./docker-deploy.sh test         → send a test request to the app
#   ./docker-deploy.sh backend      → show which LLM backend will be used
#
# LLM Backend is selected via .env (first matching wins):
#   AWS Bedrock  → set AWS_BEDROCK_MODEL_ID + AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
#   Azure OpenAI → set AZURE_OPENAI_API_KEY + AZURE_OPENAI_ENDPOINT + AZURE_OPENAI_DEPLOYMENT_NAME + AZURE_OPENAI_API_VERSION
#   NVIDIA NIM   → set NGC_API_KEY + NVIDIA_NIM_BASE_URL + NVIDIA_NIM_MODEL

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Check prerequisites ────────────────────────────────────────────────────────
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$REPO_DIR/.env" ]]; then
  echo "ERROR: .env file not found at $REPO_DIR/.env"
  echo "       Create one with your credentials (refer to README.md)."
  exit 1
fi

# ── Auto-derive LAB_USER_ID ───────────────────────────────────────────────────
# Checks in order:
#   1. Explicit value in .env  (LAB_USER_ID=john)
#   2. Persisted ID in .lab-user-id file (generated on first run)
#   3. Generate a new short random ID and persist it for future runs
LAB_USER_ID_FILE="$REPO_DIR/.lab-user-id"
export LAB_USER_ID="$(grep -E '^LAB_USER_ID=.+' "$REPO_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
if [[ -z "$LAB_USER_ID" ]]; then
  if [[ -f "$LAB_USER_ID_FILE" ]]; then
    export LAB_USER_ID="$(cat "$LAB_USER_ID_FILE")"
    echo "==> LAB_USER_ID (from .lab-user-id): $LAB_USER_ID"
  else
    export LAB_USER_ID="user-$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 6)"
    echo "$LAB_USER_ID" > "$LAB_USER_ID_FILE"
    echo "==> LAB_USER_ID (generated, saved to .lab-user-id): $LAB_USER_ID"
  fi
else
  echo "==> LAB_USER_ID (from .env): $LAB_USER_ID"
fi

if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Install Docker: https://docs.docker.com/engine/install/"
  exit 1
fi

if ! docker compose version &>/dev/null 2>&1; then
  echo "ERROR: 'docker compose' (v2) not available. Update Docker to a recent version."
  exit 1
fi

CMD="${1:-up}"

case "$CMD" in

  up)
    echo "==> Building images and starting travel-agent-demo..."
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" up --build -d
    echo ""
    echo "==> Services:"
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" ps
    echo ""
    echo "App: http://localhost:8080"
    echo "Logs:    ./docker-deploy.sh logs"
    echo "Stop:    ./docker-deploy.sh down"
    echo "Test:    ./docker-deploy.sh test"
    ;;

  down)
    echo "==> Stopping travel-agent-demo..."
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" down
    echo "Done."
    ;;

  restart)
    echo "==> Restarting all services..."
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" restart
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" ps
    ;;

  logs)
    SERVICE="${2:-}"
    if [[ -n "$SERVICE" ]]; then
      docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" logs -f "$SERVICE"
    else
      docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" logs -f
    fi
    ;;

  ps)
    docker compose --env-file "$REPO_DIR/.env" -f "$SCRIPT_DIR/docker-compose.yml" ps
    ;;

  test)
    echo "==> Sending test request to http://localhost:8080/travel/plan ..."
    curl -s -X POST http://localhost:8080/travel/plan \
      -H "Content-Type: application/json" \
      -d '{
        "origin": "New York",
        "destination": "Paris",
        "user_request": "Planning a week-long trip. Looking for boutique hotel and unique experiences.",
        "travellers": 2
      }' | python3 -m json.tool
    ;;

  backend)
    source "$REPO_DIR/.env" 2>/dev/null || true
    ACTIVE="${LLM_BACKEND:-nim}"
    case "$ACTIVE" in
      bedrock) echo "Active backend: AWS Bedrock  (model: ${AWS_BEDROCK_MODEL_ID:-amazon.nova-pro-v1:0}, region: ${AWS_DEFAULT_REGION:-us-east-1})" ;;
      azure)   echo "Active backend: Azure OpenAI (deployment: ${AZURE_OPENAI_DEPLOYMENT_NAME:-})" ;;
      nim|*)   echo "Active backend: NVIDIA NIM   (url: ${NVIDIA_NIM_BASE_URL:-}, model: ${NVIDIA_NIM_MODEL:-})" ;;
    esac
    ;;

  *)
    echo "Usage: $0 [up|down|restart|logs [service]|ps|test|backend]"
    exit 1
    ;;

esac
