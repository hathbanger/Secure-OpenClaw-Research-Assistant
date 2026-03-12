#!/bin/bash
# Secure OpenClaw Setup Script
# Run this after cloning the config repo

set -e

echo "================================================"
echo "  Secure OpenClaw Setup"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Step 1: Create directories
echo -e "${YELLOW}[1/6]${NC} Creating secure directories..."
mkdir -p ~/.openclaw/agents/research-agent/agent
mkdir -p ~/.openclaw/credentials
mkdir -p ~/.openclaw/workspace
mkdir -p ~/.openclaw/logs
chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/workspace ~/.openclaw/logs
echo -e "${GREEN}✓${NC} Directories created with secure permissions"

# Step 2: Generate token
echo ""
echo -e "${YELLOW}[2/6]${NC} Generating auth token..."
TOKEN=$(openssl rand -hex 32)
echo -e "${GREEN}✓${NC} Token generated"

# Step 3: Copy and configure files
echo ""
echo -e "${YELLOW}[3/6]${NC} Copying configuration files..."

# Copy openclaw.json and replace token placeholder
sed "s/REPLACE_WITH_OUTPUT_OF_openssl_rand_-hex_32/$TOKEN/" \
    "$SCRIPT_DIR/config/openclaw.json" > ~/.openclaw/openclaw.json

# Copy env template and add token + required volume paths
cp "$SCRIPT_DIR/config/env.template" ~/.openclaw/.env
echo "" >> ~/.openclaw/.env
echo "# Auto-generated token (matches openclaw.json)" >> ~/.openclaw/.env
echo "OPENCLAW_GATEWAY_TOKEN=$TOKEN" >> ~/.openclaw/.env
echo "" >> ~/.openclaw/.env
echo "# Docker volume paths (required by docker-compose.yml)" >> ~/.openclaw/.env
echo "OPENCLAW_CONFIG_DIR=$HOME/.openclaw" >> ~/.openclaw/.env
echo "OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace" >> ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# Copy agent SOUL file
cp -r "$SCRIPT_DIR/agents/"* ~/.openclaw/agents/

# Copy hardened docker-compose overlay
if [ -d ~/openclaw-sandbox/openclaw ]; then
    cp "$SCRIPT_DIR/docker-compose.hardened.yml" ~/openclaw-sandbox/openclaw/
    echo -e "${GREEN}✓${NC} Hardened docker-compose overlay installed"
else
    echo -e "${YELLOW}⚠${NC} OpenClaw not found at ~/openclaw-sandbox/openclaw"
    echo "   Copy docker-compose.hardened.yml there manually after cloning OpenClaw"
fi

echo -e "${GREEN}✓${NC} Configuration files installed"

# Step 4: Create Docker network
echo ""
echo -e "${YELLOW}[4/6]${NC} Creating isolated Docker network..."
docker network create --internal openclaw-isolated 2>/dev/null || echo "Network already exists"
echo -e "${GREEN}✓${NC} Docker network ready"

# Step 5: Copy scripts
echo ""
echo -e "${YELLOW}[5/6]${NC} Installing scripts..."
mkdir -p ~/openclaw-sandbox
cp "$SCRIPT_DIR/scripts/kill-agent.sh" ~/openclaw-sandbox/
cp "$SCRIPT_DIR/scripts/verify-security.sh" ~/openclaw-sandbox/
chmod +x ~/openclaw-sandbox/*.sh
echo -e "${GREEN}✓${NC} Scripts installed"

# Step 6: Copy seccomp profile
echo ""
echo -e "${YELLOW}[6/6]${NC} Installing seccomp profile..."
if [ -d ~/openclaw-sandbox/openclaw ]; then
    mkdir -p ~/openclaw-sandbox/openclaw/config
    cp "$SCRIPT_DIR/config/seccomp-profile.json" ~/openclaw-sandbox/openclaw/config/
    echo -e "${GREEN}✓${NC} Seccomp profile installed"
fi

echo ""
echo "================================================"
echo -e "${GREEN}  Setup Complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Clone and build OpenClaw (if not already done):"
echo "   mkdir -p ~/openclaw-sandbox && cd ~/openclaw-sandbox"
echo "   git clone https://github.com/openclaw/openclaw.git"
echo "   cd openclaw && docker build -t openclaw:local -f Dockerfile ."
echo ""
echo "2. Create a Telegram bot:"
echo "   - Message @BotFather on Telegram"
echo "   - Send /newbot and follow prompts"
echo "   - Save the bot token"
echo ""
echo "3. Get your Telegram user ID:"
echo "   - Message @userinfobot on Telegram"
echo ""
echo "4. Add your credentials:"
echo "   - Edit ~/.openclaw/.env → add TELEGRAM_BOT_TOKEN"
echo "   - Edit ~/.openclaw/openclaw.json → add your user ID to allowFrom"
echo ""
echo "5. Start the agent (with hardened compose):"
echo "   cd ~/openclaw-sandbox/openclaw"
echo "   docker compose --env-file ~/.openclaw/.env \\"
echo "     -f docker-compose.yml \\"
echo "     -f $SCRIPT_DIR/docker-compose.hardened.yml \\"
echo "     up -d"
echo ""
echo "6. Add Telegram channel:"
echo "   docker compose --env-file ~/.openclaw/.env \\"
echo "     -f docker-compose.yml \\"
echo "     -f $SCRIPT_DIR/docker-compose.hardened.yml \\"
echo "     run --rm openclaw-cli channels add --channel telegram --token YOUR_TOKEN"
echo ""
echo "7. Verify security:"
echo "   ~/openclaw-sandbox/verify-security.sh"
echo ""
