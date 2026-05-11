#!/usr/bin/env bash
# Hermes Dev Orchestra package installer
# Installs orchestra-specific assets on top of an existing upstream Hermes Agent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HERMES_HOME/skills}"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"
ORCHESTRA_BIN_DIR="$ORCHESTRA_HOME/bin"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
RUNTIME_ROOT="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
AUDIT_ROOT="${AUDIT_ROOT:-$HOME/.local/share/hermes-orchestra}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hermes-orchestra}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERR]${NC} $1"; }

warn_missing_command() {
    local command_name="$1"
    local message="$2"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_warn "$message"
        return 1
    fi

    return 0
}

install_helper_link() {
    local helper="$1"
    chmod +x "$ORCHESTRA_BIN_DIR/$helper"
    ln -sf "$ORCHESTRA_BIN_DIR/$helper" "$LOCAL_BIN_DIR/$helper"
    log_ok "Helper installed: $LOCAL_BIN_DIR/$helper"
}

echo "========================================"
echo " Hermes Dev Orchestra — Package Setup"
echo "========================================"

log_info "Checking upstream tool boundary..."
if ! command -v hermes >/dev/null 2>&1; then
    log_err "Hermes Agent not found. Complete Phase 9 upstream Hermes Agent installation first."
    exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
    log_err "tmux is required. Install it through your OS package manager or build it under \$HOME/.local."
    exit 1
fi

HERMES_VERSION="$(hermes --version 2>/dev/null || true)"
if [ -z "$HERMES_VERSION" ]; then
    log_err "Hermes Agent command exists, but 'hermes --version' failed. Complete Phase 9 upstream Hermes Agent installation first."
    exit 1
fi
log_ok "hermes: $HERMES_VERSION"
log_ok "tmux: $(tmux -V)"

warn_missing_command "claude" "Claude Code CLI not found. Install/authenticate it separately before using orch-start." || true
if command -v claude >/dev/null 2>&1; then
    log_ok "claude: $(claude --version 2>/dev/null || echo 'installed')"
fi

warn_missing_command "codex" "Codex CLI not found. Install/authenticate it separately before using orch-start." || true
if command -v codex >/dev/null 2>&1; then
    log_ok "codex: $(codex --version 2>/dev/null || echo 'installed')"
fi

log_info "Creating orchestra directories..."
mkdir -p "$HERMES_HOME" "$HERMES_SKILLS_DIR" "$ORCHESTRA_HOME" "$ORCHESTRA_BIN_DIR" \
    "$ORCHESTRA_HOME/backups" "$ORCHESTRA_HOME/lib" "$ORCHESTRA_HOME/tests" "$ORCHESTRA_HOME/profile-distribution" "$ORCHESTRA_HOME/plugins" "$ORCHESTRA_HOME/claude-config-template/.claude" \
    "$LOCAL_BIN_DIR" "$RUNTIME_ROOT" "$STATE_ROOT" "$AUDIT_ROOT" "$CACHE_ROOT"
log_ok "Directory roots ready"

log_info "Installing Dev Orchestra SOUL..."
SOUL_SRC="$PACKAGE_DIR/hermes/SOUL.md"
SOUL_DST="$HERMES_HOME/SOUL.md"

if [ ! -f "$SOUL_SRC" ]; then
    log_err "SOUL source missing: $SOUL_SRC"
    exit 1
fi

if [ -f "$SOUL_DST" ] && ! cmp -s "$SOUL_SRC" "$SOUL_DST"; then
    if [ ! -f "$HERMES_HOME/SOUL.md.bak" ]; then
        cp "$SOUL_DST" "$HERMES_HOME/SOUL.md.bak"
        log_ok "Existing SOUL backed up: $HERMES_HOME/SOUL.md.bak"
    else
        log_warn "Existing SOUL backup preserved: $HERMES_HOME/SOUL.md.bak"
    fi
fi

cp "$SOUL_SRC" "$SOUL_DST"
log_ok "SOUL.md installed: $SOUL_DST"

log_info "Installing Dev Orchestra skills..."
for skill in dev-orchestra claude-supervisor codex-executor escalation-handler; do
    SRC="$PACKAGE_DIR/skills/$skill"
    DST="$HERMES_SKILLS_DIR/$skill"

    if [ ! -f "$SRC/SKILL.md" ]; then
        log_err "Skill source missing: $SRC/SKILL.md"
        exit 1
    fi

    rm -rf "$DST"
    mkdir -p "$DST"
    cp -R "$SRC"/. "$DST"/

    if [ ! -f "$DST/SKILL.md" ]; then
        log_err "Skill install verification failed: $DST/SKILL.md"
        exit 1
    fi

    log_ok "Skill installed: $HERMES_SKILLS_DIR/$skill/SKILL.md"
done

log_info "Installing Claude Code hooks template..."
SETTINGS_SRC="$PACKAGE_DIR/claude-config/settings.json"
SETTINGS_DST="$ORCHESTRA_HOME/claude-config-template/.claude/settings.json"

if [ ! -f "$SETTINGS_SRC" ]; then
    log_err "Claude settings template missing: $SETTINGS_SRC"
    exit 1
fi

cp "$SETTINGS_SRC" "$SETTINGS_DST"
log_ok "Claude settings template installed: $SETTINGS_DST"

log_info "Installing orch-* helper commands..."

HELPER_SRC_DIR="$PACKAGE_DIR/scripts/bin"
HELPER_LIB_SRC_DIR="$PACKAGE_DIR/scripts/lib"
TEST_SRC_DIR="$PACKAGE_DIR/scripts/tests"
POLICY_SRC="$PACKAGE_DIR/config/risk-policy.yaml"
PROFILE_DIST_SRC="$PACKAGE_DIR/hermes/profile-distribution"
HOOKS_SRC_DIR="$PACKAGE_DIR/hermes/hooks"
PLUGINS_SRC_DIR="$PACKAGE_DIR/hermes/plugins"

if [ ! -f "$HELPER_LIB_SRC_DIR/orch-common.sh" ]; then
    log_err "Helper library missing: $HELPER_LIB_SRC_DIR/orch-common.sh"
    exit 1
fi

if [ ! -f "$POLICY_SRC" ]; then
    log_err "Risk policy missing: $POLICY_SRC"
    exit 1
fi

cp "$HELPER_LIB_SRC_DIR/orch-common.sh" "$ORCHESTRA_HOME/lib/orch-common.sh"
chmod +x "$ORCHESTRA_HOME/lib/orch-common.sh"
log_ok "Helper library installed: $ORCHESTRA_HOME/lib/orch-common.sh"

if [ ! -d "$PROFILE_DIST_SRC/profiles" ]; then
    log_err "Profile distribution missing: $PROFILE_DIST_SRC/profiles"
    exit 1
fi

rm -rf "$ORCHESTRA_HOME/profile-distribution"
mkdir -p "$ORCHESTRA_HOME/profile-distribution"
cp -R "$PROFILE_DIST_SRC"/. "$ORCHESTRA_HOME/profile-distribution"/
log_ok "Profile distribution installed: $ORCHESTRA_HOME/profile-distribution"

if [ ! -f "$ORCHESTRA_HOME/risk-policy.yaml" ]; then
    cp "$POLICY_SRC" "$ORCHESTRA_HOME/risk-policy.yaml"
    log_ok "Canonical risk policy installed: $ORCHESTRA_HOME/risk-policy.yaml"
else
    log_warn "Existing risk policy preserved: $ORCHESTRA_HOME/risk-policy.yaml"
fi

if [ -d "$HOOKS_SRC_DIR" ]; then
    rm -rf "$ORCHESTRA_HOME/hooks"
    mkdir -p "$ORCHESTRA_HOME/hooks"
    cp -R "$HOOKS_SRC_DIR"/. "$ORCHESTRA_HOME/hooks"/
    find "$ORCHESTRA_HOME/hooks" -type f -name "*.sh" -exec chmod +x {} \;
    log_ok "Hermes hook assets installed: $ORCHESTRA_HOME/hooks"
fi

if [ -d "$PLUGINS_SRC_DIR" ]; then
    rm -rf "$ORCHESTRA_HOME/plugins"
    mkdir -p "$ORCHESTRA_HOME/plugins"
    cp -R "$PLUGINS_SRC_DIR"/. "$ORCHESTRA_HOME/plugins"/
    log_ok "Hermes plugin assets installed: $ORCHESTRA_HOME/plugins"
fi

for helper in orch-init orch-start orch-stop orch-status orch-bus-loop orch-profile-sync orch-risk-check orch-audit orch-decisions orch-approve orch-reject orch-verify; do
    if [ ! -f "$HELPER_SRC_DIR/$helper" ]; then
        log_err "Helper source missing: $HELPER_SRC_DIR/$helper"
        exit 1
    fi

    cp "$HELPER_SRC_DIR/$helper" "$ORCHESTRA_BIN_DIR/$helper"
done

for helper in orch-init orch-start orch-stop orch-status orch-profile-sync orch-risk-check orch-audit orch-decisions orch-approve orch-reject orch-verify; do
    install_helper_link "$helper"
done

chmod +x "$ORCHESTRA_BIN_DIR/orch-bus-loop"
log_ok "Internal watcher installed: $ORCHESTRA_BIN_DIR/orch-bus-loop"

if [ -d "$TEST_SRC_DIR" ]; then
    rm -rf "$ORCHESTRA_HOME/tests"
    mkdir -p "$ORCHESTRA_HOME/tests"
    cp -R "$TEST_SRC_DIR"/. "$ORCHESTRA_HOME/tests"/
    find "$ORCHESTRA_HOME/tests" -type f -name "test-*.sh" -exec chmod +x {} \;
    [ -f "$ORCHESTRA_HOME/tests/run-all.sh" ] && chmod +x "$ORCHESTRA_HOME/tests/run-all.sh"
    log_ok "Smoke tests installed: $ORCHESTRA_HOME/tests"
fi

if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
    log_warn "$LOCAL_BIN_DIR is not on PATH. Add it to your shell profile to use orch-* commands from a new shell."
fi

echo "========================================"
echo " Setup Complete!"
echo "========================================"
echo ""
echo "Installed:"
echo "  SOUL:       $SOUL_DST"
echo "  Skills:     $HERMES_SKILLS_DIR/{dev-orchestra,claude-supervisor,codex-executor,escalation-handler}"
echo "  Template:   $SETTINGS_DST"
echo "  Helpers:    $LOCAL_BIN_DIR/orch-*"
echo "  RiskPolicy: $ORCHESTRA_HOME/risk-policy.yaml"
echo "  Hooks:      $ORCHESTRA_HOME/hooks"
echo "  Plugins:    $ORCHESTRA_HOME/plugins"
echo "  Profiles:   $ORCHESTRA_HOME/profile-distribution"
echo "  Tests:      $ORCHESTRA_HOME/tests"
echo "  Runtime:    $RUNTIME_ROOT"
echo "  State:      $STATE_ROOT"
echo "  Audit:      $AUDIT_ROOT"
echo "  Cache:      $CACHE_ROOT"
echo ""
echo "Next steps:"
echo "  1. Ensure Claude Code and Codex CLI are installed and authenticated."
echo "  2. Run: orch-init my-app ~/projects/my-app"
echo "  3. Run: orch-start my-app ~/projects/my-app"
echo "  4. Start upstream Hermes with: hermes chat"
echo "  5. Configure Hermes to call hooks/pre_tool_call-risk-gate.sh if you want runtime pre_tool_call enforcement."
