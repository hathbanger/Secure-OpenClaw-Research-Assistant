#!/bin/bash
# Emergency kill switch for Secure OpenClaw
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Stopping Secure OpenClaw containers..."
cd "$SCRIPT_DIR"
docker compose down --remove-orphans

echo "Removing isolated network..."
docker network rm openclaw-isolated 2>/dev/null || true

echo "Agent terminated."
