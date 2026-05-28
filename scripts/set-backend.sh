#!/usr/bin/env bash
# set-backend.sh — Switch the LLM backend between NVIDIA NIM and AWS Bedrock
#
# Usage:
#   ./scripts/set-backend.sh nim       → Use NVIDIA NIM (default for Acts 1-3)
#   ./scripts/set-backend.sh bedrock   → Use AWS Bedrock (Bonus exercise)
#
# What it does:
#   - Sets LLM_BACKEND in .env to the selected value
#   - Recreates the travel-planner container so the new value takes effect
#   - Prints the active backend to confirm the switch

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
COMPOSE_FILE="$REPO_DIR/docker/docker-compose.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found at $ENV_FILE"
  exit 1
fi

BACKEND="${1:-}"
if [[ -z "$BACKEND" ]]; then
  echo "Usage: $0 nim|bedrock|azure"
  echo ""
  echo "  nim     → NVIDIA NIM (Acts 1-3)"
  echo "  bedrock → AWS Bedrock (Bonus exercise)"
  exit 1
fi

if [[ "$BACKEND" != "nim" && "$BACKEND" != "bedrock" && "$BACKEND" != "azure" ]]; then
  echo "ERROR: Unknown backend '$BACKEND'. Use 'nim', 'bedrock', or 'azure'."
  exit 1
fi

echo "==> Switching backend to: $BACKEND"

# Write or update LLM_BACKEND in .env
python3 - "$ENV_FILE" "$BACKEND" <<'PYEOF'
import sys, re

env_file = sys.argv[1]
backend  = sys.argv[2]

with open(env_file) as f:
    content = f.read()

# Replace existing LLM_BACKEND line (active or commented)
if re.search(r'^#?\s*LLM_BACKEND=', content, re.MULTILINE):
    content = re.sub(r'^#?\s*LLM_BACKEND=.*', f'LLM_BACKEND={backend}', content, flags=re.MULTILINE)
else:
    # Not present — append it
    content = content.rstrip('\n') + f'\nLLM_BACKEND={backend}\n'

with open(env_file, 'w') as f:
    f.write(content)

print(f"   LLM_BACKEND={backend} written to .env")
PYEOF

# Recreate travel-planner so the new env var takes effect
# (docker compose restart does NOT reload env vars — up -d does)
echo "==> Recreating travel-planner container..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --no-build travel-planner

echo ""
echo "==> Active backend:"
"$REPO_DIR/docker/docker-deploy.sh" backend

echo ""
echo "Done. Verify with: ./docker/docker-deploy.sh test"

