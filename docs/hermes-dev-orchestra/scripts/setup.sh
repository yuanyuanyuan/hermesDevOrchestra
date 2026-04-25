#!/usr/bin/env bash
# Dev Orchestra Setup Script
# For Ubuntu (no sudo required) — April 2026 edition
# Prerequisites: git, curl, python3.10+, node18+ already installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRA_DIR="$HOME/.hermes-orchestra"
BUS_DIR="/tmp/hermes-orchestra"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERR]${NC} $1"; }

# ==========================
# Phase 0: Health Checks
# ==========================

echo "========================================"
echo " Dev Orchestra — Setup Script v2026.4"
echo "========================================"

log_info "Checking prerequisites..."

# Check git
if ! command -v git &> /dev/null; then
    log_err "git is required but not installed. Please install git first."
    exit 1
fi
log_ok "git: $(git --version | head -1)"

# Check node
if ! command -v node &> /dev/null; then
    log_err "Node.js is required. Install: curl -fsSL https://deb.nodesource.com/setup_22.x | bash -"
    exit 1
fi
NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
if [ "$NODE_MAJOR" -lt 18 ]; then
    log_err "Node.js >= 18 required. Current: $(node -v)"
    exit 1
fi
log_ok "node: $(node -v)"

# Check python
if ! command -v python3 &> /dev/null; then
    log_err "Python 3.10+ is required."
    exit 1
fi
PYTHON_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
if [ "$PYTHON_MINOR" -lt 10 ]; then
    log_err "Python 3.10+ required. Current: $(python3 --version)"
    exit 1
fi
log_ok "python: $(python3 --version)"

# Check tmux
if ! command -v tmux &> /dev/null; then
    log_warn "tmux not found. Installing..."
    # Try to install without sudo (via apt if available, or compile from source)
    if command -v apt-get &> /dev/null; then
        log_err "tmux is required. Please ask your admin to install it, or build from source:"
        echo "  wget https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz"
        echo "  tar xzf tmux-3.5a.tar.gz && cd tmux-3.5a"
        echo "  ./configure --prefix=$HOME/.local && make && make install"
        exit 1
    fi
fi
log_ok "tmux: $(tmux -V)"

# Check Hermes Agent
if ! command -v hermes &> /dev/null; then
    log_warn "Hermes Agent not found. Installing..."
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
    source ~/.bashrc 2>/dev/null || source ~/.zshrc 2>/dev/null || true
fi
HERMES_VERSION=$(hermes --version 2>/dev/null || echo "unknown")
log_ok "hermes: $HERMES_VERSION"

# Check Claude Code CLI
if ! command -v claude &> /dev/null; then
    log_warn "Claude Code CLI not found. Installing..."
    npm install -g @anthropic-ai/claude-code
fi
log_ok "claude: $(claude --version 2>/dev/null || echo 'unknown - run claude auth')"

# Check Codex CLI
if ! command -v codex &> /dev/null; then
    log_warn "Codex CLI not found. Installing..."
    npm install -g @openai/codex
fi
log_ok "codex: $(codex --version 2>/dev/null || echo 'unknown - run codex login')"

# Check API keys
if [ -z "${OPENROUTER_API_KEY:-}" ] && [ -z "$(grep OPENROUTER_API_KEY ~/.hermes/.env 2>/dev/null || true)" ]; then
    log_warn "OPENROUTER_API_KEY not found in environment or ~/.hermes/.env"
    echo "  Please set your API key: hermes config set OPENROUTER_API_KEY sk-or-xxx"
fi

if [ -z "${OPENAI_API_KEY:-}" ] && [ -z "$(grep OPENAI_API_KEY ~/.hermes/.env 2>/dev/null || true)" ]; then
    log_warn "OPENAI_API_KEY not found. Codex CLI requires it."
    echo "  Please add to ~/.hermes/.env: OPENAI_API_KEY=sk-..."
fi

# Check Claude Code auth
if ! claude doctor &>/dev/null; then
    log_warn "Claude Code not authenticated. Run: claude auth"
fi

# ==========================
# Phase 1: Directory Setup
# ==========================

log_info "Creating orchestra directories..."
mkdir -p "$ORCHESTRA_DIR"/{skills,projects,logs,backups}
mkdir -p "$BUS_DIR"
touch "$BUS_DIR/audit.log"
chmod 600 "$BUS_DIR/audit.log"
log_ok "Directories created at $ORCHESTRA_DIR and $BUS_DIR"

# ==========================
# Phase 2: Install Skills
# ==========================

log_info "Installing Dev Orchestra skills..."

# Copy skills to Hermes skills directory
HERMES_SKILLS_DIR="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
mkdir -p "$HERMES_SKILLS_DIR"

for skill in dev-orchestra claude-supervisor codex-executor escalation-handler; do
    SRC="$SCRIPT_DIR/skills/$skill"
    DST="$HERMES_SKILLS_DIR/dev-orchestra/$skill"
    if [ -d "$SRC" ]; then
        mkdir -p "$DST"
        cp -r "$SRC"/* "$DST"/ 2>/dev/null || true
        log_ok "Skill installed: $skill"
    else
        log_warn "Skill source not found: $SRC"
    fi
done

# ==========================
# Phase 3: Hermes SOUL.md
# ==========================

log_info "Configuring Hermes personality..."

if [ -f "$SCRIPT_DIR/hermes/SOUL.md" ]; then
    mkdir -p "$HOME/.hermes"
    cp "$SCRIPT_DIR/hermes/SOUL.md" "$HOME/.hermes/SOUL.md"
    log_ok "SOUL.md installed"
fi

# ==========================
# Phase 4: Claude Code Config
# ==========================

log_info "Setting up Claude Code project config template..."

mkdir -p "$ORCHESTRA_DIR/claude-config-template/.claude"
if [ -f "$SCRIPT_DIR/claude-config/settings.json" ]; then
    cp "$SCRIPT_DIR/claude-config/settings.json" "$ORCHESTRA_DIR/claude-config-template/.claude/settings.json"
    log_ok "Claude Code settings.json template ready"
fi

# ==========================
# Phase 5: Helper Scripts
# ==========================

log_info "Installing helper scripts..."

cat > "$ORCHESTRA_DIR/scripts/init-project.sh" << 'EOF'
#!/usr/bin/env bash
# Initialize a new project for Dev Orchestra
set -euo pipefail

PROJECT_NAME="${1:-}"
PROJECT_DIR="${2:-}"

if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_DIR" ]; then
    echo "Usage: init-project.sh <project-name> <project-directory>"
    exit 1
fi

# Ensure git repo
if [ ! -d "$PROJECT_DIR/.git" ]; then
    echo "Initializing git repository..."
    cd "$PROJECT_DIR"
    git init
    git add . 2>/dev/null || true
    git commit -m "init: orchestra setup" 2>/dev/null || true
fi

# Create bus directory
mkdir -p "/tmp/hermes-orchestra/$PROJECT_NAME"

# Copy Claude config if not exists
if [ ! -f "$PROJECT_DIR/.claude/settings.json" ]; then
    mkdir -p "$PROJECT_DIR/.claude"
    cp "$HOME/.hermes-orchestra/claude-config-template/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json" 2>/dev/null || true
    echo "Claude config copied to $PROJECT_DIR/.claude/settings.json"
fi

# Create initial task placeholder
cat > "/tmp/hermes-orchestra/$PROJECT_NAME/task.md" << EOT
# Task: Initialize
Status: ready
Created: $(date -Iseconds)
Project: $PROJECT_NAME
EOT

echo "Project '$PROJECT_NAME' initialized at $PROJECT_DIR"
echo "Bus directory: /tmp/hermes-orchestra/$PROJECT_NAME"
EOF
chmod +x "$ORCHESTRA_DIR/scripts/init-project.sh"

cat > "$ORCHESTRA_DIR/scripts/start-project.sh" << 'EOF'
#!/usr/bin/env bash
# Start Claude Supervisor + Codex Executor for a project
set -euo pipefail

PROJECT_NAME="${1:-}"
PROJECT_DIR="${2:-}"

if [ -z "$PROJECT_NAME" ] || [ -z "$PROJECT_DIR" ]; then
    echo "Usage: start-project.sh <project-name> <project-directory>"
    exit 1
fi

# Kill existing sessions if any
tmux kill-session -t "hermes-${PROJECT_NAME}-claude" 2>/dev/null || true
tmux kill-session -t "hermes-${PROJECT_NAME}-codex" 2>/dev/null || true

sleep 1

# Start Claude Supervisor
tmux new-session -d -s "hermes-${PROJECT_NAME}-claude" -x 180 -y 40 \
    -c "$PROJECT_DIR" \
    "claude --permission-mode auto --channels"

echo "[OK] Claude Supervisor started: tmux attach -t hermes-${PROJECT_NAME}-claude"

# Start Codex Executor
tmux new-session -d -s "hermes-${PROJECT_NAME}-codex" -x 180 -y 40 \
    -c "$PROJECT_DIR" \
    "codex exec --full-auto --json"

echo "[OK] Codex Executor started: tmux attach -t hermes-${PROJECT_NAME}-codex"

echo ""
echo "To monitor: tmux ls"
echo "To attach Claude: tmux attach -t hermes-${PROJECT_NAME}-claude"
echo "To attach Codex: tmux attach -t hermes-${PROJECT_NAME}-codex"
EOF
chmod +x "$ORCHESTRA_DIR/scripts/start-project.sh"

cat > "$ORCHESTRA_DIR/scripts/stop-project.sh" << 'EOF'
#!/usr/bin/env bash
# Stop all orchestra sessions for a project
set -euo pipefail

PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: stop-project.sh <project-name>"
    exit 1
fi

tmux kill-session -t "hermes-${PROJECT_NAME}-claude" 2>/dev/null || true
tmux kill-session -t "hermes-${PROJECT_NAME}-codex" 2>/dev/null || true

echo "Project '$PROJECT_NAME' sessions stopped."
EOF
chmod +x "$ORCHESTRA_DIR/scripts/stop-project.sh"

cat > "$ORCHESTRA_DIR/scripts/status.sh" << 'EOF'
#!/usr/bin/env bash
# Show status of all orchestra projects
set -euo pipefail

echo "=== Hermes Dev Orchestra Status ==="
echo ""
echo "--- tmux sessions ---"
tmux ls 2>/dev/null | grep "hermes-" || echo "No active orchestra sessions"
echo ""
echo "--- project buses ---"
ls -1 /tmp/hermes-orchestra/ 2>/dev/null | while read proj; do
    echo "[$proj]"
    ls -lt "/tmp/hermes-orchestra/$proj" 2>/dev/null | head -6 | tail -5
    echo ""
done
echo "--- audit log (last 5) ---"
tail -5 /tmp/hermes-orchestra/audit.log 2>/dev/null || echo "No audit entries"
EOF
chmod +x "$ORCHESTRA_DIR/scripts/status.sh"

log_ok "Helper scripts installed"

# ==========================
# Phase 6: PATH & Aliases
# ==========================

log_info "Updating shell configuration..."

# Add to .bashrc if not already present
if ! grep -q "hermes-orchestra" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Hermes Dev Orchestra aliases
alias orch-init="$HOME/.hermes-orchestra/scripts/init-project.sh"
alias orch-start="$HOME/.hermes-orchestra/scripts/start-project.sh"
alias orch-stop="$HOME/.hermes-orchestra/scripts/stop-project.sh"
alias orch-status="$HOME/.hermes-orchestra/scripts/status.sh"
EOF
    log_ok "Aliases added to ~/.bashrc (run 'source ~/.bashrc' to activate)"
fi

# ==========================
# Phase 7: Telegram Gateway (Optional)
# ==========================

log_info "Telegram gateway setup (optional)..."
echo ""
echo "To enable remote decision notifications:"
echo "  1. Message @BotFather on Telegram, create a bot, copy the token"
echo "  2. Message @userinfobot to get your numeric user ID"
echo "  3. Run: hermes config set TELEGRAM_BOT_TOKEN 'your-token'"
echo "  4. Run: hermes config set TELEGRAM_ALLOWED_USERS 'your-user-id'"
echo "  5. Run: hermes gateway install && hermes gateway start"
echo ""

# ==========================
# Done
# ==========================

echo "========================================"
echo " Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Ensure API keys are set: ~/.hermes/.env"
echo "  2. Authenticate Claude Code: claude auth"
echo "  3. Authenticate Codex CLI: codex login"
echo "  4. Initialize your first project:"
echo "     orch-init my-app ~/projects/my-app"
echo "  5. Start the orchestra:"
echo "     orch-start my-app ~/projects/my-app"
echo "  6. Start Hermes and run: /dev-orchestra"
echo ""
echo "Directory structure:"
echo "  ~/.hermes-orchestra/   — scripts and templates"
echo "  /tmp/hermes-orchestra/ — runtime communication bus"
echo "  ~/.hermes/skills/      — Hermes skills"
echo ""
