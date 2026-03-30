#!/bin/bash
# Secure OpenClaw Setup
#
# Usage:
#   ./scripts/setup.sh                                    # interactive
#   OPENCLAW_IMAGE=openclaw:local ./scripts/setup.sh      # with pre-built base image
#   ./scripts/setup.sh --build-base /path/to/openclaw     # build base image first

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
BUILD_BASE=""
OPENCLAW_SRC=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --build-base)
            BUILD_BASE=1
            OPENCLAW_SRC="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "================================================"
echo "  Secure OpenClaw — Shield Setup"
echo "================================================"
echo ""

# Step 1: Build base image if requested
if [ -n "$BUILD_BASE" ]; then
    if [ ! -f "$OPENCLAW_SRC/Dockerfile" ]; then
        echo -e "${RED}✗${NC} No Dockerfile found at $OPENCLAW_SRC"
        exit 1
    fi
    echo -e "${YELLOW}[1/4]${NC} Building base OpenClaw image..."
    docker build -t openclaw:local -f "$OPENCLAW_SRC/Dockerfile" "$OPENCLAW_SRC"
    echo -e "${GREEN}✓${NC} Base image built: openclaw:local"
else
    echo -e "${YELLOW}[1/4]${NC} Checking for base image..."
    if docker image inspect "${OPENCLAW_IMAGE:-openclaw:local}" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Base image found: ${OPENCLAW_IMAGE:-openclaw:local}"
    else
        echo -e "${RED}✗${NC} Base image '${OPENCLAW_IMAGE:-openclaw:local}' not found."
        echo ""
        echo "  Either build it first:"
        echo "    cd /path/to/openclaw && docker build -t openclaw:local -f Dockerfile ."
        echo ""
        echo "  Or let this script do it:"
        echo "    ./scripts/setup.sh --build-base /path/to/openclaw"
        exit 1
    fi
fi

# Step 2: Generate .env if it doesn't exist
echo ""
echo -e "${YELLOW}[2/4]${NC} Configuring secrets..."

if [ -f "$ENV_FILE" ]; then
    echo -e "${DIM}  .env already exists — skipping generation${NC}"
    echo -e "${GREEN}✓${NC} Using existing .env"
else
    TOKEN=$(openssl rand -hex 32)

    cat > "$ENV_FILE" <<ENVEOF
# Secure OpenClaw — Environment
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Gateway auth token (auto-generated)
OPENCLAW_GATEWAY_TOKEN=$TOKEN

# --- Required ---
ANTHROPIC_API_KEY=

# --- Channels (at least one) ---
TELEGRAM_BOT_TOKEN=
DISCORD_BOT_TOKEN=

# --- Optional ---
GEMINI_API_KEY=
RESEND_API_KEY=
BRAVE_API_KEY=
GH_TOKEN=
GITHUB_TOKEN=

# --- Git identity for agent commits ---
GIT_AUTHOR_NAME=OpenClaw
GIT_AUTHOR_EMAIL=openclaw@users.noreply.github.com
GIT_COMMITTER_NAME=OpenClaw
GIT_COMMITTER_EMAIL=openclaw@users.noreply.github.com

# --- Base image (change if using a custom build) ---
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_MODEL=claude-opus-4-5-20251101
ENVEOF

    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✓${NC} .env created at $ENV_FILE"
    echo -e "${YELLOW}  ⚠ Fill in ANTHROPIC_API_KEY + at least one channel token before starting${NC}"
fi

# Step 3: Build the hardened image
echo ""
echo -e "${YELLOW}[3/4]${NC} Building hardened image..."
cd "$SCRIPT_DIR"
docker compose build
echo -e "${GREEN}✓${NC} Image built: openclaw-secure:local"

# Step 4: Create network
echo ""
echo -e "${YELLOW}[4/4]${NC} Creating isolated Docker network..."
docker network create --internal openclaw-isolated 2>/dev/null || true
echo -e "${GREEN}✓${NC} Network ready"

echo ""
echo "================================================"
echo -e "${GREEN}  Shield Built${NC}"
echo "================================================"
echo ""
echo "Configure:"
echo "  $ENV_FILE"
echo "  config/openclaw.json → add user IDs to allowFrom"
echo ""
echo "Run:"
echo "  cd $SCRIPT_DIR"
echo "  docker compose up -d"
echo ""
echo "Verify:"
echo "  ./scripts/verify-security.sh"
echo ""
echo "Stop:"
echo "  docker compose down"
echo ""
echo "Emergency kill:"
echo "  ./scripts/kill-agent.sh"
echo ""
