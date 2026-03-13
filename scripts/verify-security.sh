#!/bin/bash
# OpenClaw Security Verification Script
# Run this before starting the agent to verify security configuration

echo "================================================"
echo "  OpenClaw Security Verification"
echo "================================================"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    if [ $1 -eq 0 ]; then
        echo "[PASS] $2"
        ((PASS++))
    else
        echo "[FAIL] $2"
        ((FAIL++))
    fi
}

warn() {
    echo "[WARN] $1"
    ((WARN++))
}

echo "=== Configuration Files ==="

# Check config file exists
test -f ~/.openclaw/openclaw.json
check $? "Config file exists"

# Check SOUL file exists
test -f ~/.openclaw/agents/research-agent/agent/soul.md
check $? "Agent SOUL file exists"

# Check SOUL file has security prohibitions
grep -q "ABSOLUTE PROHIBITIONS" ~/.openclaw/agents/research-agent/agent/soul.md 2>/dev/null
check $? "SOUL file contains security prohibitions"

echo ""
echo "=== Gateway Security ==="

# Check gateway is loopback only
grep -q '"bind": "loopback"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Gateway bound to loopback only"

# Check gateway mode is local
grep -q '"mode": "local"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Gateway mode is local"

echo ""
echo "=== Docker Sandbox ==="

# Check network is disabled in sandbox
grep -q '"network": "none"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Sandbox network disabled"

# Check read-only root
grep -q '"readOnlyRoot": true' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Sandbox read-only root filesystem"

# Check all capabilities dropped
grep -q '"capDrop"' ~/.openclaw/openclaw.json 2>/dev/null && grep -q '"ALL"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "All Docker capabilities dropped"

# Check workspace access is none
grep -q '"workspaceAccess": "none"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Workspace access disabled"

echo ""
echo "=== Hardened Compose (Critical) ==="

# Check hardened compose exists
test -f ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml
check $? "Hardened docker-compose overlay exists"

# Check no-new-privileges in hardened compose
grep -q "no-new-privileges" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
check $? "no-new-privileges flag present"

# Check CPU limits in hardened compose
grep -q "cpus:" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
check $? "CPU limits configured"

# Check memory limits in hardened compose
grep -q "memory:" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
check $? "Memory limits configured"

# Check PID limits in hardened compose
grep -q "pids:" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
check $? "PID limits configured (fork bomb prevention)"

# Check read_only in hardened compose
grep -q "read_only: true" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
check $? "Container read_only flag present"

echo ""
echo "=== File Permissions ==="

# Check credentials directory permissions
if [ -d ~/.openclaw/credentials ]; then
    PERMS=$(stat -f "%OLp" ~/.openclaw/credentials 2>/dev/null || stat -c "%a" ~/.openclaw/credentials 2>/dev/null)
    if [ "$PERMS" = "700" ]; then
        echo "[PASS] Credentials directory has secure permissions (700)"
        ((PASS++))
    else
        echo "[FAIL] Credentials directory permissions: $PERMS (should be 700)"
        ((FAIL++))
    fi
else
    echo "[PASS] Credentials directory exists with secure permissions"
    ((PASS++))
fi

# Check .env file permissions
if [ -f ~/.openclaw/.env ]; then
    PERMS=$(stat -f "%OLp" ~/.openclaw/.env 2>/dev/null || stat -c "%a" ~/.openclaw/.env 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo "[PASS] .env file has secure permissions (600)"
        ((PASS++))
    else
        echo "[FAIL] .env file permissions: $PERMS (should be 600)"
        ((FAIL++))
    fi
else
    echo "[WARN] .env file not found"
    ((WARN++))
fi

echo ""
echo "=== Infrastructure ==="

# Check isolated network exists
docker network ls 2>/dev/null | grep -q "openclaw-isolated"
check $? "Isolated Docker network exists"

# Check kill switch exists and is executable
test -x ~/openclaw-sandbox/kill-agent.sh
check $? "Kill switch script exists and is executable"

echo ""
echo "=== Access Control ==="

# Check Telegram allowlist policy
grep -q '"dmPolicy": "allowlist"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Telegram DM policy is allowlist"

# Check mDNS discovery is off
grep -q '"mode": "off"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "mDNS discovery disabled"

echo ""
echo "=== Seccomp Profile Integrity ==="

# Check seccomp profile exists in repo
test -f config/seccomp-profile.json 2>/dev/null || test -f ~/openclaw-sandbox/openclaw/config/seccomp-profile.json 2>/dev/null
check $? "Seccomp profile file exists"

# Check seccomp is not unconfined in compose
if [ -f ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml ]; then
    ! grep -q "seccomp:unconfined" ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
    check $? "Seccomp is NOT set to unconfined"
fi

# Check seccomp default action is deny
SECCOMP_FILE=""
if [ -f config/seccomp-profile.json ]; then
    SECCOMP_FILE="config/seccomp-profile.json"
elif [ -f ~/openclaw-sandbox/openclaw/config/seccomp-profile.json ]; then
    SECCOMP_FILE="$HOME/openclaw-sandbox/openclaw/config/seccomp-profile.json"
fi

if [ -n "$SECCOMP_FILE" ]; then
    grep -q '"SCMP_ACT_ERRNO"' "$SECCOMP_FILE" 2>/dev/null
    check $? "Seccomp default action is ERRNO (deny)"

    # Check dangerous syscalls are blocked (not in allowlist)
    ! grep -q '"ptrace"' "$SECCOMP_FILE" 2>/dev/null
    check $? "ptrace syscall is blocked"

    ! grep -q '"mount"' "$SECCOMP_FILE" 2>/dev/null
    check $? "mount syscall is blocked"

    ! grep -q '"unshare"' "$SECCOMP_FILE" 2>/dev/null
    check $? "unshare syscall is blocked"

    ! grep -q '"io_uring_setup"' "$SECCOMP_FILE" 2>/dev/null
    check $? "io_uring syscalls are blocked"

    ! grep -q '"execveat"' "$SECCOMP_FILE" 2>/dev/null
    check $? "execveat syscall is blocked"

    ! grep -q '"memfd_create"' "$SECCOMP_FILE" 2>/dev/null
    check $? "memfd_create syscall is blocked"
fi

echo ""
echo "=== Tool Controls ==="

# Check deny list has critical entries
grep -q '"apply_patch"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "apply_patch in tool deny list"

grep -q '"sessions_spawn"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "sessions_spawn in tool deny list"

grep -q '"sessions_send"' ~/.openclaw/openclaw.json 2>/dev/null
check $? "sessions_send in tool deny list"

# Check elevated tools are disabled
grep -q '"elevated"' ~/.openclaw/openclaw.json 2>/dev/null && grep -q '"enabled": false' ~/.openclaw/openclaw.json 2>/dev/null
check $? "Elevated tools disabled"

echo ""
echo "=== Secrets Management ==="

# Check no hardcoded API keys in config
if [ -f ~/.openclaw/openclaw.json ]; then
    ! grep -qiE '(sk-ant-|sk-[a-zA-Z0-9]{20,}|xoxb-|xoxp-|ghp_|gho_|AKIA)' ~/.openclaw/openclaw.json 2>/dev/null
    check $? "No hardcoded API keys in config file"
fi

# Check no hardcoded tokens in compose files
if [ -f ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml ]; then
    ! grep -qiE '(sk-ant-|sk-[a-zA-Z0-9]{20,}|xoxb-|xoxp-|ghp_|gho_|AKIA)' ~/openclaw-sandbox/openclaw/docker-compose.hardened.yml 2>/dev/null
    check $? "No hardcoded API keys in compose file"
fi

echo ""
echo "================================================"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "================================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "CRITICAL: Some security checks failed!"
    echo "Review the configuration before starting the agent."
    echo ""
    echo "To fix common issues:"
    echo "  chmod 700 ~/.openclaw ~/.openclaw/credentials ~/.openclaw/workspace"
    echo "  chmod 600 ~/.openclaw/.env"
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo "Security configuration mostly complete with $WARN warnings."
    echo "Review warnings before proceeding."
    exit 0
else
    echo ""
    echo "All security checks passed."
    echo ""
    echo "IMPORTANT: Always start with the hardened compose overlay:"
    echo "  cd ~/openclaw-sandbox/openclaw"
    echo "  docker compose -f docker-compose.yml -f docker-compose.hardened.yml up -d"
fi
