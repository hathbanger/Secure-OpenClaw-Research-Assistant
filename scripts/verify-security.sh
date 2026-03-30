#!/bin/bash
# Security verification for Secure OpenClaw
# Run after setup to confirm all hardening is in place

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

echo "================================================"
echo "  Secure OpenClaw — Security Verification"
echo "================================================"
echo ""

echo "=== Image ==="

docker image inspect openclaw-secure:local >/dev/null 2>&1
check $? "Hardened image exists (openclaw-secure:local)"

echo ""
echo "=== Configuration ==="

grep -q '"bind": "loopback"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "Gateway bound to loopback only"

grep -q '"mode": "local"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "Gateway mode is local"

grep -q '"apply_patch"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "apply_patch in tool deny list"

grep -q '"sessions_spawn"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "sessions_spawn in tool deny list"

grep -q '"sessions_send"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "sessions_send in tool deny list"

grep -q '"enabled": false' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "Elevated tools disabled"

grep -q '"workspaceOnly": true' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "Filesystem restricted to workspace only"

grep -q '"dmPolicy": "allowlist"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "Channel DM policy is allowlist"

grep -q '"mode": "off"' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
check $? "mDNS discovery disabled"

echo ""
echo "=== Agent SOUL ==="

grep -q "ABSOLUTE PROHIBITIONS" "$SCRIPT_DIR/agents/research-agent/agent/soul.md" 2>/dev/null
check $? "SOUL file contains security prohibitions"

grep -q "NEVER read or disclose" "$SCRIPT_DIR/agents/research-agent/agent/soul.md" 2>/dev/null
check $? "SOUL file blocks credential disclosure"

grep -q "NEVER execute arbitrary shell commands" "$SCRIPT_DIR/agents/research-agent/agent/soul.md" 2>/dev/null
check $? "SOUL file blocks arbitrary shell execution"

echo ""
echo "=== Compose Hardening ==="

COMPOSE="$SCRIPT_DIR/docker-compose.yml"

grep -q "no-new-privileges:true" "$COMPOSE" 2>/dev/null
check $? "no-new-privileges flag present"

grep -q "seccomp=config/seccomp-profile.json" "$COMPOSE" 2>/dev/null
check $? "Seccomp profile referenced"

! grep -q "seccomp:unconfined" "$COMPOSE" 2>/dev/null
check $? "Seccomp is NOT set to unconfined"

grep -q "read_only: true" "$COMPOSE" 2>/dev/null
check $? "Container read_only filesystem"

grep -q 'cap_drop:' "$COMPOSE" 2>/dev/null
check $? "Capabilities dropped"

grep -q 'cpus:' "$COMPOSE" 2>/dev/null
check $? "CPU limits configured"

grep -q 'memory:' "$COMPOSE" 2>/dev/null
check $? "Memory limits configured"

grep -q 'pids:' "$COMPOSE" 2>/dev/null
check $? "PID limits configured"

grep -q 'privileged: false' "$COMPOSE" 2>/dev/null
check $? "Privileged mode disabled"

echo ""
echo "=== Seccomp Profile ==="

SECCOMP="$SCRIPT_DIR/config/seccomp-profile.json"

test -f "$SECCOMP"
check $? "Seccomp profile exists"

grep -q '"SCMP_ACT_ERRNO"' "$SECCOMP" 2>/dev/null
check $? "Default action is ERRNO (deny)"

! grep -q '"ptrace"' "$SECCOMP" 2>/dev/null
check $? "ptrace blocked"

! grep -q '"mount"' "$SECCOMP" 2>/dev/null
check $? "mount blocked"

! grep -q '"unshare"' "$SECCOMP" 2>/dev/null
check $? "unshare blocked"

! grep -q '"io_uring_setup"' "$SECCOMP" 2>/dev/null
check $? "io_uring blocked"

! grep -q '"memfd_create"' "$SECCOMP" 2>/dev/null
check $? "memfd_create blocked"

echo ""
echo "=== Secrets ==="

ENV_FILE="$SCRIPT_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    PERMS=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo "[PASS] .env has secure permissions (600)"
        ((PASS++))
    else
        echo "[FAIL] .env permissions: $PERMS (should be 600)"
        ((FAIL++))
    fi

    ! grep -qiE '(sk-ant-api|sk-[a-zA-Z0-9]{20,}|xoxb-|ghp_|AKIA)' "$SCRIPT_DIR/config/openclaw.json" 2>/dev/null
    check $? "No hardcoded API keys in config"

    ! grep -qiE '(sk-ant-api|sk-[a-zA-Z0-9]{20,}|xoxb-|ghp_|AKIA)' "$COMPOSE" 2>/dev/null
    check $? "No hardcoded API keys in compose"
else
    echo "[WARN] .env not found — run setup.sh first"
    ((WARN++))
fi

echo ""
echo "=== Runtime (if running) ==="

if docker compose -f "$COMPOSE" ps --status running 2>/dev/null | grep -q openclaw-gateway; then
    echo "[INFO] Gateway is running — checking live container..."

    CONTAINER=$(docker compose -f "$COMPOSE" ps -q openclaw-gateway 2>/dev/null)
    if [ -n "$CONTAINER" ]; then
        INSPECT=$(docker inspect "$CONTAINER" 2>/dev/null)

        echo "$INSPECT" | grep -q '"Privileged": false'
        check $? "Container is not privileged (live)"

        echo "$INSPECT" | grep -q '"ReadonlyRootfs": true'
        check $? "Root filesystem is read-only (live)"
    fi
else
    echo "[INFO] Gateway not running — skipping live checks"
fi

echo ""
echo "================================================"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo "================================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "CRITICAL: $FAIL security checks failed. Review before starting."
    exit 1
elif [ $WARN -gt 0 ]; then
    echo ""
    echo "Security checks passed with $WARN warnings."
    exit 0
else
    echo ""
    echo "All security checks passed."
fi
