# Secure OpenClaw Research Assistant

Run OpenClaw as a **secure research assistant** with **SecureClaw security hardening**, maximum container isolation, and **persistent memory** for learning your preferences.

## New in v3.0 - SecureClaw Security Upgrade
- **Default-deny seccomp profile** - Blocks dangerous syscalls (ptrace, mount, bpf, etc.)
- **Discord + Telegram support** - Multi-channel communication
- **GitHub push capability** - Agent can push code to repos (optional)
- **Enhanced tool restrictions** - Deny list for dangerous tools, workspace-only filesystem access
- **Git config via environment** - Works with read-only filesystem
- **CRITICAL FIX:** Actually uses seccomp profile (v2.0 had `seccomp:unconfined` which disabled protection!)

## Previous in v2.0
- **Persistent Memory Skill** - Agent remembers your feedback across sessions
- **Secrets moved to env vars** - No tokens stored in JSON config files
- **Read-only filesystem** - Container root is immutable
- **ClawdStrike integration** - Security audit tool included

```bash
# Quick start (after cloning this repo)
./scripts/setup.sh
```

---

## Quick Start

### 1. Clone and Build

```bash
# Clone this config repo
git clone https://github.com/csmoove530/Secure-OpenClaw-Research-Assistant.git
cd Secure-OpenClaw-Research-Assistant

# Clone and build OpenClaw
mkdir -p ~/openclaw-sandbox && cd ~/openclaw-sandbox
git clone https://github.com/openclaw/openclaw.git
cd openclaw && docker build -t openclaw:local -f Dockerfile .
```

### 2. Run Setup Script

```bash
cd ~/Secure-OpenClaw-Research-Assistant
./scripts/setup.sh
```

This script will:
- Create secure directories with proper permissions
- Generate your auth token
- Copy configuration files (including hardened docker-compose)
- Create the isolated Docker network

### 3. Set Up the Alias

Add this to `~/.zshrc` (or `~/.bashrc`) for shorter commands:

```bash
alias openclaw-compose='docker compose --env-file ~/.openclaw/.env -f ~/openclaw-sandbox/openclaw/docker-compose.yml -f ~/Secure-OpenClaw-Research-Assistant/docker-compose.hardened.yml'
```

Then reload: `source ~/.zshrc`

### 4. Add Your Telegram Bot

```bash
# Get your bot token from @BotFather on Telegram
# Get your user ID from @userinfobot on Telegram

cd ~/openclaw-sandbox/openclaw
openclaw-compose run --rm openclaw-cli channels add --channel telegram --token YOUR_BOT_TOKEN
```

Edit `~/.openclaw/openclaw.json` and add your Telegram user ID:
```json
"allowFrom": ["YOUR_TELEGRAM_USER_ID"]
```

### 5. Start with Hardened Compose

```bash
cd ~/openclaw-sandbox/openclaw
openclaw-compose up -d

# Verify security
~/openclaw-sandbox/verify-security.sh

# Run security audit
openclaw-compose exec openclaw-gateway node dist/index.js security audit --deep
```

**Expected output:**
```
OpenClaw security audit
Summary: 0 critical · 3 warn · 1 info
```

### 6. Test It

Message your bot on Telegram. It should respond as a read-only research assistant.

---

## What Success Looks Like

After setup, you should see:

**Security verification:**
```
================================================
  OpenClaw Security Verification
================================================

[PASS] Config file exists
[PASS] Gateway bound to loopback only
[PASS] Docker sandbox network disabled
[PASS] ClawHub registry disabled
...
================================================
  Results: 15 passed, 0 failed
================================================
```

**Security audit:**
```
Summary: 0 critical · 3 warn · 1 info

Attack surface:
  - Groups: open=0, allowlist=1
```

The 3 warnings are expected for maximum isolation mode.

---

## Common Commands

**Important:** Always use the hardened compose overlay via the alias:

```bash
# Add to ~/.zshrc or ~/.bashrc
alias openclaw-compose='docker compose --env-file ~/.openclaw/.env -f ~/openclaw-sandbox/openclaw/docker-compose.yml -f ~/Secure-OpenClaw-Research-Assistant/docker-compose.hardened.yml'
```

| Task | Command |
|------|---------|
| Start agent | `openclaw-compose up -d` |
| Stop agent | `openclaw-compose down` |
| **Emergency kill** | `~/openclaw-sandbox/kill-agent.sh` |
| View logs | `openclaw-compose logs -f openclaw-gateway` |
| Security audit | `openclaw-compose exec openclaw-gateway node dist/index.js security audit --deep` |

---

## Security Model

### Understanding Security Boundaries

This configuration has two types of controls:

| Layer | Type | Bypass Difficulty |
|-------|------|-------------------|
| Container isolation | **HARD BOUNDARY** | Requires container escape exploit |
| Capability dropping | **HARD BOUNDARY** | Kernel-enforced |
| Seccomp filtering | **HARD BOUNDARY** | Kernel-enforced |
| no-new-privileges | **HARD BOUNDARY** | Kernel-enforced |
| Network isolation | **HARD BOUNDARY** | Requires container escape |
| Read-only filesystem | **HARD BOUNDARY** | Kernel-enforced |
| SOUL file directives | **SOFT CONTROL** | Bypassable via prompt injection |
| Telegram allowlist | **MEDIUM** | Requires stealing your Telegram session |

**Critical:** The SOUL file (`soul.md`) provides behavioral guidance but is **NOT a security boundary**. It can be bypassed by prompt injection - the exact attack this setup defends against. Real security comes from the container-level restrictions.

### Defense-in-Depth Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      YOUR MACHINE                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           DOCKER CONTAINER (HARD BOUNDARY)            │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              SECURITY CONTROLS                  │  │  │
│  │  │  • no-new-privileges: true                      │  │  │
│  │  │  • seccomp: restricted syscalls                 │  │  │
│  │  │  • capabilities: ALL dropped                    │  │  │
│  │  │  • read_only: true                              │  │  │
│  │  │  • user: 1000:1000 (non-root)                   │  │  │
│  │  │  • pids_limit: 256                              │  │  │
│  │  │  • memory: 512MB max                            │  │  │
│  │  │  • cpus: 1.0 max                                │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │           OPENCLAW SANDBOX                      │  │  │
│  │  │  • network: none (no egress)                    │  │  │
│  │  │  • workspaceAccess: none                        │  │  │
│  │  │  • scope: session                               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │           AGENT (SOFT CONTROLS)                 │  │  │
│  │  │  • SOUL file behavioral restrictions            │  │  │
│  │  │  • (can be bypassed by prompt injection)        │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  │  Gateway: loopback only + token auth                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Telegram: allowlist (only your user ID)                    │
│  Kill switch: ~/openclaw-sandbox/kill-agent.sh              │
└─────────────────────────────────────────────────────────────┘
```

### Secrets Management

**All secrets are stored in environment variables, NOT in JSON config files.**

| Secret | Location | Notes |
|--------|----------|-------|
| `ANTHROPIC_API_KEY` | `.env` | Required for Claude |
| `TELEGRAM_BOT_TOKEN` | `.env` | From @BotFather |
| `OPENCLAW_GATEWAY_TOKEN` | `.env` | Auth token |
| `RESEND_API_KEY` | `.env` | Optional: email |
| `BRAVE_API_KEY` | `.env` | Optional: web search |

The `openclaw.json` config file contains **no secrets** - safe to share or commit.

```bash
# Verify no secrets in config
grep -E "(token|key|password|secret)" ~/.openclaw/openclaw.json
# Should return nothing sensitive
```

### What the Hardened Compose Adds

The `docker-compose.hardened.yml` overlay adds protections missing from upstream:

| Protection | What It Does |
|------------|--------------|
| `no-new-privileges` | Prevents setuid/setgid privilege escalation |
| `seccomp` profile | Filters dangerous syscalls at kernel level (~185 allowed, all others blocked) |
| `cpu` limits | Prevents DoS via CPU exhaustion (1 core max) |
| `memory` limits | Prevents DoS via memory exhaustion (2GB max) |
| `read_only: true` | Immutable root filesystem |
| `tmpfs` with nosuid/nodev | Writable temp dirs can't create device files |
| `pids_limit` | Prevents fork bombs (256 max) |
| Tool deny list | Blocks dangerous tools: `apply_patch`, `gateway`, `cron`, `sessions_spawn`, `sessions_send` |
| Workspace-only FS | Agent can only access `~/.openclaw/workspace`, not host filesystem |
| Elevated tools disabled | No privilege escalation via tool system |
| Env var secrets | No tokens in config files |

**v3.0 Critical Fix:** Previous versions used `seccomp:unconfined` which **completely disabled** kernel-level syscall filtering. This is now fixed with an actual default-deny seccomp profile.

---

## Agent Capabilities

### What It Can Do
- Read documents you provide
- Summarize and analyze text
- Answer questions
- Draft responses for your review
- **Learn and remember your preferences** (via memory skill)

### Persistent Memory Skill

The agent includes a **remember-feedback** skill that saves your preferences across sessions.

**Trigger phrases:**
- "Remember that..."
- "Going forward..."
- "From now on..."
- "I prefer..."
- "Quick feedback:"

**Example:**
```
You: "Going forward, always use bullet points instead of paragraphs"
Agent: "Got it! I've saved this preference. I'll use bullet points going forward."
```

Preferences are stored in `~/.openclaw/agents/main/agent/soul.md` and persist across restarts.

**Categories:**
- Writing Style Guidelines
- Data & Dashboard Preferences
- Things to Avoid
- General Preferences

### What It Cannot Do

**Enforced by container (HARD):**
- Access host filesystem
- Make network connections
- Spawn unlimited processes
- Consume unlimited resources
- Escalate privileges

**Requested by SOUL file (SOFT - can be bypassed):**
- Financial transactions
- Credential handling
- External communications

---

## Troubleshooting

### Container won't start

**Symptom:** `docker compose up` exits immediately

**Check logs:**
```bash
openclaw-compose logs openclaw-gateway
```

**Common causes:**
- Invalid JSON in `~/.openclaw/openclaw.json` → Validate with `jq . ~/.openclaw/openclaw.json`
- Missing `gateway.mode` → Ensure config has `"mode": "local"`
- Resource limits too tight → Check if 512MB is enough for your use

### Security verification fails

**Symptom:** `verify-security.sh` shows failures

**Fix permissions:**
```bash
chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/workspace
chmod 600 ~/.openclaw/.env
```

### Bot doesn't respond

**Symptom:** Messages to Telegram bot get no response

**Check:**
1. Bot token is correct in `.env`
2. Your user ID is in `allowFrom` array
3. Gateway is running: `openclaw-compose ps`
4. Logs for errors: `openclaw-compose logs -f`

### "Config invalid" errors

**Symptom:** Logs show config validation errors

**Run doctor:**
```bash
openclaw-compose exec openclaw-gateway node dist/index.js doctor --fix
```

### Resource limit errors

**Symptom:** Container OOM killed or CPU throttled

**Adjust limits** in `docker-compose.hardened.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Increase if needed
      memory: 1024M    # Increase if needed
```

---

## File Reference

```
This repo:
├── docker-compose.hardened.yml  # Security overlay (IMPORTANT)
├── config/
│   ├── openclaw.json            # Main config (no secrets!)
│   ├── env.example              # Secrets template (copy to .env)
│   └── seccomp-profile.json     # Syscall filter (optional)
├── skills/
│   └── remember-feedback/
│       └── SKILL.md             # Persistent memory skill
├── agents/
│   └── research-agent/
│       └── agent/
│           └── soul.md          # Agent behavioral guidance + learned preferences
└── scripts/
    ├── setup.sh                 # Automated setup
    ├── kill-agent.sh            # Emergency stop
    └── verify-security.sh       # Security checks

After setup:
~/.openclaw/
├── openclaw.json                # Your config (no hardcoded secrets)
├── .env                         # Your secrets (chmod 600) - NEVER COMMIT
├── skills/
│   └── remember-feedback/       # Memory skill
└── agents/
    └── main/
        └── agent/
            └── soul.md          # Learned preferences persisted here

~/openclaw-sandbox/openclaw/
├── docker-compose.yml           # Upstream compose
├── docker-compose.hardened.yml  # Copied hardening overlay
└── .env                         # Secrets for docker compose
```

---

## Manual Installation

<details>
<summary>Click to expand step-by-step instructions</summary>

If you prefer manual setup over the setup script:

### Create directories
```bash
mkdir -p ~/.openclaw/agents/research-agent/agent
mkdir -p ~/.openclaw/credentials ~/.openclaw/workspace
chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/workspace
```

### Generate token
```bash
TOKEN=$(openssl rand -hex 32)
echo "Your token: $TOKEN"
```

### Copy files
```bash
cp config/openclaw.json ~/.openclaw/
cp config/env.template ~/.openclaw/.env
cp -r agents/* ~/.openclaw/agents/
cp docker-compose.hardened.yml ~/openclaw-sandbox/openclaw/
chmod 600 ~/.openclaw/.env
```

### Edit config
Replace `REPLACE_WITH_OUTPUT_OF_openssl_rand_-hex_32` in both:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/.env`

### Create network
```bash
docker network create --internal openclaw-isolated
```

### Copy scripts
```bash
cp scripts/*.sh ~/openclaw-sandbox/
chmod +x ~/openclaw-sandbox/*.sh
```

### Start with hardening
```bash
cd ~/openclaw-sandbox/openclaw
openclaw-compose up -d
```

</details>

---

## Security Auditing with ClawdStrike

This setup includes integration with [ClawdStrike](https://www.clawdstrike.ai/), a security audit tool from Cantina.

### Install ClawdStrike Skill

```bash
cd ~/.openclaw/skills
git clone https://github.com/cantinaxyz/clawdstrike.git
```

### Run Security Audit

```bash
cd ~/.openclaw/skills/clawdstrike
bash scripts/collect_verified.sh
```

This generates a `verified-bundle.json` with security findings. The skill checks:
- Gateway exposure and authentication
- Discovery/mDNS leaks
- Channel policies
- Filesystem permissions
- Skills supply chain
- Secrets on disk

### Audit Report

After running the collector, ask the agent via Telegram:
```
Run ClawdStrike security audit and show me the report
```

---

## Why This Matters

OpenClaw has known vulnerabilities:
- **CVE-2025-49596**, **CVE-2025-6514**
- 30,000+ exposed instances on Shodan
- Malicious skills via ClawHub
- Prompt injection attacks

This configuration assumes the agent **will be compromised** via prompt injection and ensures that a compromised agent **cannot escape the container** or affect your system.

---

## Contributing

Security improvements welcome. Open an issue first.

## License

MIT (configuration files only)
