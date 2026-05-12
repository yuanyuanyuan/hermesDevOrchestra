#!/usr/bin/env bash
# 前置依赖检查脚本
# 运行此脚本确认你的环境已满足 Hermes Dev Orchestra 的安装要求。

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

ok()   { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
fail() { echo -e "${RED}✘${NC} $1"; ((ERRORS++)); }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# 比较版本号：$1 为当前版本，$2 为最低版本
# 返回 0 表示满足要求
version_ge() {
    local cur="$1"
    local min="$2"
    # 提取纯数字版本（去掉前缀如 v、V）
    cur="$(echo "$cur" | sed -E 's/^[vV]?([0-9]+(\.[0-9]+)*).*/\1/')"
    min="$(echo "$min" | sed -E 's/^[vV]?([0-9]+(\.[0-9]+)*).*/\1/')"
    printf '%s\n%s\n' "$min" "$cur" | sort -V -C 2>/dev/null
}

check_cmd_version() {
    local cmd="$1"
    local min_ver="$2"
    local get_ver="${3:-$1 --version}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        fail "$cmd 未安装（最低要求 >= $min_ver）"
        return 1
    fi

    local raw_ver
    raw_ver="$($get_ver 2>&1 | head -n1 || true)"
    local ver
    ver="$(echo "$raw_ver" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)"

    if [ -z "$ver" ]; then
        warn "$cmd 已安装，但无法解析版本（输出: $raw_ver）"
        return 1
    fi

    if version_ge "$ver" "$min_ver"; then
        ok "$cmd $ver"
        return 0
    else
        fail "$cmd $ver（最低要求 >= $min_ver）"
        return 1
    fi
}

echo "========================================"
echo " Hermes Dev Orchestra — 环境检查"
echo "========================================"
echo ""

# --- 基础工具 ---
info "检查基础工具..."
check_cmd_version "git"   "2.30"  "git --version"
check_cmd_version "node"  "18"    "node --version"
check_cmd_version "tmux"  "3.0"   "tmux -V"
check_cmd_version "python3" "3.10" "python3 --version"

echo ""

# --- 上游 CLI ---
info "检查上游 CLI..."
check_cmd_version "hermes"  "0.11.0"  "hermes --version"
check_cmd_version "claude"  "2.1.110" "claude --version"
check_cmd_version "codex"   "0.122.0" "codex --version"

echo ""

# --- API Key 配置 ---
info "检查 API Key 配置..."
ENV_FILE="${HOME}/.hermes/.env"
if [ -f "$ENV_FILE" ]; then
    ok "~/.hermes/.env 存在"
    # 检查关键变量是否存在（不暴露值）
    local_missing=0
    for key in OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY; do
        if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
            ok "  ${key} 已配置"
        else
            warn "  ${key} 未在 ~/.hermes/.env 中找到"
            local_missing=1
        fi
    done
else
    fail "~/.hermes/.env 不存在"
    info "  创建方式: mkdir -p ~/.hermes && cat > ~/.hermes/.env <<'EOF'"
    info '  OPENROUTER_API_KEY=sk-or-xxx'
    info '  OPENAI_API_KEY=sk-xxx'
    info '  ANTHROPIC_API_KEY=sk-ant-oat01-xxx'
    info '  EOF'
fi

echo ""

# --- CLI 认证状态 ---
info "检查 CLI 认证状态..."
if command -v claude >/dev/null 2>&1; then
    if claude auth status >/dev/null 2>&1; then
        ok "Claude Code CLI 已认证"
    else
        warn "Claude Code CLI 未认证，请运行: claude auth"
    fi
fi

if command -v codex >/dev/null 2>&1; then
    # codex 没有标准 auth status 命令，通过尝试获取版本间接判断
    if codex --version >/dev/null 2>&1; then
        ok "Codex CLI 可调用"
    else
        warn "Codex CLI 可能未认证，请运行: codex login"
    fi
fi

echo ""

# --- Orchestra 安装状态 ---
info "检查 Orchestra 安装状态..."
if command -v orch-init >/dev/null 2>&1; then
    ok "orch-* 命令已在 PATH 中"
else
    warn "orch-* 命令不在 PATH 中"
    info "  请确保 ~/.local/bin 在你的 PATH 中:"
    info '  export PATH="$HOME/.local/bin:$PATH"'
fi

if [ -d "${HOME}/.hermes-orchestra" ]; then
    ok "~/.hermes-orchestra 目录已创建"
else
    warn "~/.hermes-orchestra 目录不存在（尚未运行 setup.sh）"
fi

echo ""
echo "========================================"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}全部通过！可以运行 bash scripts/setup.sh 安装 Orchestra。${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}基本就绪，但存在警告（${WARNINGS} 项）。建议处理后再继续。${NC}"
else
    echo -e "${RED}检查失败：${ERRORS} 个错误，${WARNINGS} 个警告。请先修复错误。${NC}"
fi
echo "========================================"

exit "$ERRORS"
