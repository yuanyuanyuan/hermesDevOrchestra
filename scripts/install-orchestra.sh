#!/usr/bin/env bash
# install-orchestra.sh — 引导式一键安装 Hermes Dev Orchestra
# 从裸机环境检查到 Orchestra 包安装的完整引导流程。
#
# 用法:
#   bash scripts/install-orchestra.sh           # 交互模式
#   bash scripts/install-orchestra.sh -y        # 自动模式
#   bash scripts/install-orchestra.sh --check-only  # 只检查，不安装

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- 参数默认值 ---
AUTO_MODE=false
CHECK_ONLY=false
ENV_FILE="${HOME}/.hermes/.env"

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "${GREEN}✔${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✘${NC} $1"; }
info()  { echo -e "${BLUE}ℹ${NC} $1"; }
section(){ echo -e "\n${BOLD}$1${NC}"; }

# --- 参数解析 ---
for arg in "$@"; do
    case "$arg" in
        -y|--auto) AUTO_MODE=true ;;
        --check-only) CHECK_ONLY=true ;;
        --env-file)
            shift
            ENV_FILE="${1:-}"
            ;;
        -h|--help)
            cat <<'EOF'
用法: bash scripts/install-orchestra.sh [选项]

选项:
  -y, --auto       自动模式：尽可能自动修复已知问题
  --check-only     只检查环境，不执行安装或修改
  --env-file PATH  指定 API Key 配置文件路径（默认 ~/.hermes/.env）
  -h, --help       显示此帮助
EOF
            exit 0
            ;;
    esac
done

# --- 交互确认 ---
ask() {
    local prompt="$1"
    if $AUTO_MODE; then
        echo "[auto] $prompt → 是"
        return 0
    fi
    local answer
    read -rp "$prompt [Y/n] " answer
    case "${answer:-Y}" in
        [Yy]*|[""]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- OS / 包管理器检测 ---
detect_os() {
    case "$(uname -s)" in
        Linux*)
            if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*) echo "macos" ;;
        *) echo "unknown" ;;
    esac
}

detect_pkg_manager() {
    if command -v apt >/dev/null 2>&1; then echo "apt"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v yum >/dev/null 2>&1; then echo "yum"
    elif command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v brew >/dev/null 2>&1; then echo "brew"
    else echo "unknown"
    fi
}

show_install_cmd() {
    local pkg="$1"
    local pm
    pm="$(detect_pkg_manager)"
    case "$pm" in
        apt) echo "sudo apt update && sudo apt install -y $pkg" ;;
        dnf|yum) echo "sudo $pm install -y $pkg" ;;
        pacman) echo "sudo pacman -S --noconfirm $pkg" ;;
        brew) echo "brew install $pkg" ;;
        *) echo "# 请手动安装: $pkg" ;;
    esac
}

# --- 版本比较 ---
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null
}

check_cmd_version() {
    local cmd="$1" min="$2" get_ver="${3:-$1 --version}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "missing"
        return 1
    fi
    local raw_ver ver
    raw_ver="$($get_ver 2>&1 | head -n1)"
    ver="$(echo "$raw_ver" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)"
    if [ -z "$ver" ]; then
        echo "unknown"
        return 1
    fi
    if version_ge "$ver" "$min"; then
        echo "ok:$ver"
        return 0
    else
        echo "old:$ver"
        return 1
    fi
}

# --- Phase 0: 欢迎 ---
phase_welcome() {
    section "========================================"
    section "Hermes Dev Orchestra — 引导式安装"
    section "========================================"
    echo ""
    echo "本脚本将引导你完成从环境检查到 Orchestra 包安装的完整流程。"
    echo ""
    info "预计时间："
    echo "  • 环境已就绪：约 2 分钟"
    echo "  • 需安装外部 CLI：约 15-30 分钟"
    echo ""
    info "请提前准备好以下 API Key："
    echo "  1. OpenRouter API Key (sk-or-...)"
    echo "  2. OpenAI API Key (sk-...)"
    echo "  3. Anthropic OAuth Token (sk-ant-oat01-...)"
    echo ""
    if $CHECK_ONLY; then
        info "当前模式：--check-only（只检查，不安装）"
    elif $AUTO_MODE; then
        info "当前模式：自动模式（-y），将自动修复已知问题"
    else
        info "当前模式：交互模式（默认），每个关键步骤会询问确认"
    fi
    echo ""
    if ! $CHECK_ONLY && ! ask "是否继续？"; then
        echo "已取消。"
        exit 0
    fi
}

# --- Phase 1: 基础依赖 ---
phase_base_deps() {
    section "Phase 1: 基础依赖检查"

    local os_name
    os_name="$(detect_os)"
    info "检测到操作系统: $os_name"

    local deps_ok=true
    local results=()

    for spec in "git:2.30:git --version" "node:18:node --version" "tmux:3.0:tmux -V" "python3:3.10:python3 --version"; do
        IFS=':' read -r cmd min getver <<< "$spec"
        local result
        result="$(check_cmd_version "$cmd" "$min" "$getver")"
        case "$result" in
            ok:*)
                ok "$cmd ${result#ok:}"
                ;;
            old:*)
                fail "$cmd ${result#old:}（最低要求 >= $min）"
                deps_ok=false
                ;;
            missing)
                fail "$cmd 未安装（最低要求 >= $min）"
                deps_ok=false
                ;;
            *)
                warn "$cmd 版本无法解析"
                deps_ok=false
                ;;
        esac
    done

    if ! $deps_ok; then
        echo ""
        info "请安装缺失的基础依赖。推荐命令："
        for spec in "git:2.30:git --version" "node:18:node --version" "tmux:3.0:tmux -V" "python3:3.10:python3 --version"; do
            IFS=':' read -r cmd min _ <<< "$spec"
            if ! command -v "$cmd" >/dev/null 2>&1; then
                echo "  $(show_install_cmd "$cmd")"
            fi
        done
        echo ""
        if ! ask "我已安装好缺失的依赖"; then
            fail "基础依赖不满足，安装中止。"
            exit 1
        fi
        # 重新验证
        for spec in "git:2.30:git --version" "node:18:node --version" "tmux:3.0:tmux -V" "python3:3.10:python3 --version"; do
            IFS=':' read -r cmd min getver <<< "$spec"
            local result
            result="$(check_cmd_version "$cmd" "$min" "$getver")"
            if [[ "$result" != ok:* ]]; then
                fail "$cmd 仍然不可用，请确认安装成功后重试。"
                exit 1
            fi
        done
        ok "基础依赖验证通过"
    fi
}

# --- Phase 2: 上游 CLI ---
phase_upstream_cli() {
    section "Phase 2: 上游 CLI 检查"

    local cli_ok=true
    local pin_commit=""
    if [ -f "$PACKAGE_DIR/.planning/upstream/hermes-agent-pin.json" ]; then
        pin_commit="$(python3 -c 'import json; print(json.load(open("'"$PACKAGE_DIR"'/.planning/upstream/hermes-agent-pin.json", encoding="utf-8"))["pin"]["commit"])' 2>/dev/null || true)"
    fi

    # hermes
    local result
    result="$(check_cmd_version "hermes" "0.11.0" "hermes --version")"
    if [[ "$result" == ok:* ]]; then
        ok "hermes ${result#ok:}"
        if [ -n "$pin_commit" ]; then
            local runtime_dir="${HOME}/.hermes/hermes-agent"
            if [ -d "$runtime_dir/.git" ]; then
                local runtime_commit
                runtime_commit="$(git -C "$runtime_dir" rev-parse HEAD 2>/dev/null || true)"
                if [ "$runtime_commit" != "$pin_commit" ]; then
                    info "hermes 运行时 commit 与仓库 pin 不一致"
                    info "  仓库锁定: ${pin_commit:0:12}"
                    info "  运行时:   ${runtime_commit:0:12}"
                    info "  如需对齐: cd ~/.hermes/hermes-agent && git checkout $pin_commit"
                fi
            fi
        fi
    else
        fail "hermes 未安装或版本过低"
        cli_ok=false
        echo ""
        info "安装 Hermes Agent："
        echo "  git clone https://github.com/NousResearch/hermes-agent.git ~/.hermes/hermes-agent"
        echo "  cd ~/.hermes/hermes-agent"
        if [ -n "$pin_commit" ]; then
            echo "  git checkout $pin_commit"
        fi
        echo "  # 按上游 README 完成安装"
    fi

    # claude
    result="$(check_cmd_version "claude" "2.1.110" "claude --version")"
    if [[ "$result" == ok:* ]]; then
        ok "claude ${result#ok:}"
    else
        fail "claude 未安装或版本过低"
        cli_ok=false
        echo ""
        info "安装 Claude Code CLI："
        echo "  npm install -g @anthropic-ai/claude-code"
    fi

    # codex
    result="$(check_cmd_version "codex" "0.122.0" "codex --version")"
    if [[ "$result" == ok:* ]]; then
        ok "codex ${result#ok:}"
    else
        fail "codex 未安装或版本过低"
        cli_ok=false
        echo ""
        info "安装 Codex CLI："
        echo "  npm install -g @openai/codex"
    fi

    if ! $cli_ok; then
        echo ""
        if ! ask "我已安装好缺失的上游 CLI"; then
            fail "上游 CLI 不满足，安装中止。"
            exit 1
        fi
        # 重新验证
        for cmd_min in "hermes:0.11.0" "claude:2.1.110" "codex:0.122.0"; do
            IFS=':' read -r cmd min <<< "$cmd_min"
            local r
            r="$(check_cmd_version "$cmd" "$min" "$cmd --version")"
            if [[ "$r" != ok:* ]]; then
                fail "$cmd 仍然不可用，请确认安装成功后重试。"
                exit 1
            fi
        done
        ok "上游 CLI 验证通过"
    fi
}

# --- Phase 3: CLI 认证 ---
phase_auth() {
    section "Phase 3: CLI 认证状态"

    local auth_ok=true

    if command -v claude >/dev/null 2>&1; then
        if claude auth status >/dev/null 2>&1; then
            ok "Claude Code CLI 已认证"
        else
            warn "Claude Code CLI 未认证"
            auth_ok=false
            info "请运行: claude auth"
        fi
    fi

    if command -v codex >/dev/null 2>&1; then
        if codex --version >/dev/null 2>&1; then
            ok "Codex CLI 可调用"
        else
            warn "Codex CLI 可能未认证"
            auth_ok=false
            info "请运行: codex login"
        fi
    fi

    if ! $auth_ok; then
        echo ""
        if ! ask "我已完成 CLI 认证"; then
            fail "CLI 认证未完成，安装中止。"
            exit 1
        fi
        ok "CLI 认证确认"
    fi
}

# --- Phase 4: API Key 配置 ---
phase_api_keys() {
    section "Phase 4: API Key 配置"

    local env_dir
    env_dir="$(dirname "$ENV_FILE")"
    mkdir -p "$env_dir"

    local need_input=false
    if [ -f "$ENV_FILE" ]; then
        ok "配置文件存在: $ENV_FILE"
        for key in OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY; do
            if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
                local val
                val="$(grep "^${key}=" "$ENV_FILE" | cut -d= -f2-)"
                if [ -n "$val" ]; then
                    ok "  $key 已设置"
                else
                    warn "  $key 为空"
                    need_input=true
                fi
            else
                warn "  $key 未找到"
                need_input=true
            fi
        done
    else
        warn "配置文件不存在: $ENV_FILE"
        need_input=true
    fi

    if $need_input; then
        if $CHECK_ONLY; then
            warn "[check-only] API Key 不完整，请在交互模式下配置"
            return
        fi

        if $AUTO_MODE; then
            warn "[auto] API Key 不完整，自动模式无法交互输入"
            info "请手动编辑 $ENV_FILE 补充缺失的 Key，然后重运行本脚本"
            return
        fi

        echo ""
        info "请交互输入 API Key（输入内容不会显示在屏幕上）"
        info "注意：只会追加缺失的变量，不会覆盖你现有的多模型配置。"
        echo ""

        # 备份现有配置（无论是否需要输入都备份一次）
        if [ -f "$ENV_FILE" ]; then
            local bak="${ENV_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
            cp "$ENV_FILE" "$bak"
            info "现有配置已备份到: $bak"
        fi

        local or_key oa_key ant_key

        if ! grep -q "^OPENROUTER_API_KEY=" "$ENV_FILE" 2>/dev/null; then
            read -rsp "OPENROUTER_API_KEY [sk-or-...]: " or_key; echo ""
        fi
        if ! grep -q "^OPENAI_API_KEY=" "$ENV_FILE" 2>/dev/null; then
            read -rsp "OPENAI_API_KEY [sk-...]: " oa_key; echo ""
        fi
        if ! grep -q "^ANTHROPIC_API_KEY=" "$ENV_FILE" 2>/dev/null; then
            read -rsp "ANTHROPIC_API_KEY [sk-ant-oat01-...]: " ant_key; echo ""
        fi

        # 只追加缺失的 Key，绝不覆盖已有配置
        {
            echo ""
            echo "# --- Added by install-orchestra.sh $(date +%Y-%m-%d) ---"
            if [ -n "${or_key:-}" ]; then
                echo "OPENROUTER_API_KEY=${or_key}"
            fi
            if [ -n "${oa_key:-}" ]; then
                echo "OPENAI_API_KEY=${oa_key}"
            fi
            if [ -n "${ant_key:-}" ]; then
                echo "ANTHROPIC_API_KEY=${ant_key}"
            fi
        } >> "$ENV_FILE"

        chmod 600 "$ENV_FILE"
        ok "缺失的 Key 已追加到: $ENV_FILE（权限 600）"
        info "Hermes Agent 的多模型/工具配置保持不变。"
    fi
}

# --- Phase 5: 运行 setup.sh ---
phase_setup() {
    section "Phase 5: 安装 Orchestra 包"

    if $CHECK_ONLY; then
        info "[check-only] 跳过 setup.sh"
        return
    fi

    info "正在运行 bash scripts/setup.sh ..."
    if bash "$SCRIPT_DIR/setup.sh"; then
        ok "setup.sh 成功完成"
    else
        local ec=$?
        fail "setup.sh 失败（exit code: $ec）"
        info "请检查上方日志输出，修复问题后重新运行本脚本。"
        exit 1
    fi
}

# --- Phase 6: PATH 检查 ---
phase_path() {
    section "Phase 6: PATH 检查"

    if printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
        ok "~/.local/bin 已在 PATH 中"
        return 0
    fi

    warn "~/.local/bin 不在 PATH 中"

    local shell_name shell_rc
    shell_name="$(basename "$SHELL")"
    case "$shell_name" in
        bash) shell_rc="$HOME/.bashrc" ;;
        zsh) shell_rc="$HOME/.zshrc" ;;
        fish) shell_rc="$HOME/.config/fish/config.fish" ;;
        *) shell_rc="$HOME/.profile" ;;
    esac

    info "检测到你的 shell 是: $SHELL"
    info "建议将以下行添加到 $shell_rc："
    echo ""
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo ""

    if $CHECK_ONLY; then
        warn "[check-only] 请手动添加 PATH"
        return
    fi

    if ask "是否自动追加到 $shell_rc？"; then
        mkdir -p "$(dirname "$shell_rc")"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        ok "已追加到 $shell_rc"
        info "请在新终端窗口运行: source $shell_rc"
    else
        warn "请手动添加上述 export 语句，然后 source $shell_rc"
    fi
}

# --- Phase 7: 最终验证 ---
phase_final() {
    section "Phase 7: 最终验证"

    if command -v orch-verify >/dev/null 2>&1; then
        info "运行 orch-verify ..."
        if orch-verify; then
            ok "orch-verify 通过"
        else
            warn "orch-verify 有失败项，请查看上方输出"
        fi
    else
        warn "orch-verify 不在 PATH 中（可能 setup.sh 未成功或 PATH 未刷新）"
    fi

    if ! $CHECK_ONLY && ! $AUTO_MODE; then
        if ask "是否运行完整测试矩阵 (make test)？这可能需要几分钟"; then
            if make test; then
                ok "make test 通过"
            else
                warn "make test 有失败项"
            fi
        fi
    fi

    section "========================================"
    section "安装总结"
    section "========================================"
    echo ""
    ok "Orchestra 安装流程已完成"
    echo ""
    echo "下一步："
    echo "  1. 阅读 docs/GETTING-STARTED.md 了解如何初始化并启动第一个项目"
    echo "  2. 遇到问题随时运行: orch-doctor"
    echo ""
}

# --- 主流程 ---
main() {
    phase_welcome
    phase_base_deps
    phase_upstream_cli
    phase_auth
    phase_api_keys
    phase_setup
    phase_path
    phase_final
}

main "$@"
