#!/usr/bin/env bash
# orch-doctor.sh — Orchestra 生态健康诊断
# 检查上游 CLI、安装完整性、配置有效性及运行时健康状态。
#
# 用法:
#   orch-doctor                  # 全局诊断
#   orch-doctor --project my-app # 针对项目深度诊断
#   orch-doctor --fix            # 尝试自动修复已知问题
#   orch-doctor --json           # 输出 JSON 格式

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"

# --- 参数 ---
PROJECT_ID=""
FIX_MODE=false
JSON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --project)
            shift
            PROJECT_ID="${1:-}"
            ;;
        --fix) FIX_MODE=true ;;
        --json) JSON_MODE=true ;;
        -h|--help)
            cat <<'EOF'
用法: orch-doctor [选项]

选项:
  --project ID   针对指定项目做深度诊断
  --fix          尝试自动修复已知可安全修复的问题
  --json         以 JSON 格式输出结果
  -h, --help     显示此帮助
EOF
            exit 0
            ;;
    esac
done

# --- 颜色 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "  ${RED}✘${NC} $1"; }
info()  { echo -e "  ${BLUE}ℹ${NC} $1"; }
section(){ echo -e "\n${BOLD}$1${NC}"; }

# --- 结果收集（用于 JSON 模式）---
declare -a CHECK_RESULTS=()

check_result() {
    local category="$1"
    local name="$2"
    local status="$3"   # ok/warn/fail/info
    local detail="${4:-}"
    CHECK_RESULTS+=("$category|$name|$status|$detail")
}

# --- 版本比较 ---
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null
}

parse_version() {
    local raw="$1"
    echo "$raw" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1
}

# --- 维度 A: 上游 CLI 健康 ---
check_upstream_cli() {
    section "[A] 上游 CLI 健康"

    local pin_commit=""
    if [ -f "$PACKAGE_DIR/.planning/upstream/hermes-agent-pin.json" ]; then
        pin_commit="$(python3 -c 'import json; print(json.load(open("'"$PACKAGE_DIR"'/.planning/upstream/hermes-agent-pin.json", encoding="utf-8"))["pin"]["commit"])' 2>/dev/null || true)"
    fi

    # hermes
    if command -v hermes >/dev/null 2>&1; then
        local ver
        ver="$(parse_version "$(hermes --version 2>&1 | head -n1)")"
        if version_ge "$ver" "0.11.0"; then
            ok "hermes $ver"
            check_result "upstream" "hermes" "ok" "$ver"

            # commit pin 检查
            if [ -n "$pin_commit" ]; then
                local runtime_dir="${HOME}/.hermes/hermes-agent"
                if [ -d "$runtime_dir/.git" ]; then
                    local runtime_commit
                    runtime_commit="$(git -C "$runtime_dir" rev-parse HEAD 2>/dev/null || true)"
                    if [ "$runtime_commit" != "$pin_commit" ]; then
                        info "hermes 运行时 commit 与仓库 pin 不一致"
                        info "  仓库锁定: ${pin_commit:0:12}"
                        info "  运行时:   ${runtime_commit:0:12}"
                        info "  建议: cd ~/.hermes/hermes-agent && git checkout $pin_commit"
                        check_result "upstream" "hermes-pin" "info" "mismatch:${runtime_commit:0:12} vs ${pin_commit:0:12}"
                    else
                        check_result "upstream" "hermes-pin" "ok" "match"
                    fi
                else
                    check_result "upstream" "hermes-pin" "warn" "runtime dir not a git repo"
                fi
            fi
        else
            fail "hermes $ver（最低要求 >= 0.11.0）"
            check_result "upstream" "hermes" "fail" "version $ver"
        fi
    else
        fail "hermes 未安装"
        check_result "upstream" "hermes" "fail" "missing"
    fi

    # claude
    if command -v claude >/dev/null 2>&1; then
        local ver
        ver="$(parse_version "$(claude --version 2>&1 | head -n1)")"
        if version_ge "$ver" "2.1.110"; then
            local auth_status="未认证"
            if claude auth status >/dev/null 2>&1; then
                auth_status="已认证"
            fi
            ok "claude $ver ($auth_status)"
            check_result "upstream" "claude" "ok" "$ver ($auth_status)"
        else
            fail "claude $ver（最低要求 >= 2.1.110）"
            check_result "upstream" "claude" "fail" "version $ver"
        fi
    else
        fail "claude 未安装"
        check_result "upstream" "claude" "fail" "missing"
    fi

    # codex
    if command -v codex >/dev/null 2>&1; then
        local ver
        ver="$(parse_version "$(codex --version 2>&1 | head -n1)")"
        if version_ge "$ver" "0.122.0"; then
            ok "codex $ver"
            check_result "upstream" "codex" "ok" "$ver"
        else
            fail "codex $ver（最低要求 >= 0.122.0）"
            check_result "upstream" "codex" "fail" "version $ver"
        fi
    else
        fail "codex 未安装"
        check_result "upstream" "codex" "fail" "missing"
    fi
}

# --- 维度 B: Orchestra 安装完整性 ---
check_install_integrity() {
    section "[B] Orchestra 安装完整性"

    # SOUL.md
    if [ -s "${HOME}/.hermes/SOUL.md" ]; then
        ok "SOUL.md"
        check_result "integrity" "soul" "ok" ""
    else
        fail "SOUL.md 缺失或为空"
        check_result "integrity" "soul" "fail" "missing"
    fi

    # Skills
    local skills_ok=true
    for skill in dev-orchestra claude-supervisor codex-executor escalation-handler; do
        if [ -f "${HOME}/.hermes/skills/$skill/SKILL.md" ]; then
            : # ok
        else
            fail "Skill 缺失: $skill/SKILL.md"
            skills_ok=false
            check_result "integrity" "skill-$skill" "fail" "missing"
        fi
    done
    if $skills_ok; then
        ok "4 skills"
        check_result "integrity" "skills" "ok" "4/4"
    fi

    # orch-* 命令
    local helpers=(orch-init orch-start orch-stop orch-status orch-profile-sync orch-risk-check orch-audit orch-decisions orch-approve orch-reject orch-verify)
    local helpers_ok=true
    local helper_count=0
    for h in "${helpers[@]}"; do
        if [ -x "${HOME}/.local/bin/$h" ]; then
            ((helper_count++))
        else
            fail "Helper 缺失或不可执行: $h"
            helpers_ok=false
            check_result "integrity" "helper-$h" "fail" "missing"
        fi
    done
    if $helpers_ok; then
        ok "${#helpers[@]} orch-* 命令"
        check_result "integrity" "helpers" "ok" "${#helpers[@]}/${#helpers[@]}"
    fi

    # risk-policy.yaml
    if [ -f "${ORCHESTRA_HOME}/risk-policy.yaml" ]; then
        ok "risk-policy.yaml"
        check_result "integrity" "risk-policy" "ok" ""
    else
        fail "risk-policy.yaml 缺失"
        check_result "integrity" "risk-policy" "fail" "missing"
    fi

    # 目录结构
    for dir in bin lib hooks plugins profile-distribution tests; do
        if [ -d "${ORCHESTRA_HOME}/$dir" ]; then
            : # ok
        else
            fail "目录缺失: ${ORCHESTRA_HOME}/$dir"
            check_result "integrity" "dir-$dir" "fail" "missing"
        fi
    done
}

# --- 维度 C: 配置有效性 ---
check_config() {
    section "[C] 配置有效性"

    # .env
    local env_file="${HOME}/.hermes/.env"
    if [ -f "$env_file" ]; then
        ok "~/.hermes/.env 存在"
        check_result "config" "env-file" "ok" ""

        for key in OPENROUTER_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY; do
            if grep -q "^${key}=" "$env_file" 2>/dev/null; then
                local val
                val="$(grep "^${key}=" "$env_file" | cut -d= -f2-)"
                if [ -n "$val" ]; then
                    ok "  $key 已设置"
                    check_result "config" "$key" "ok" "set"
                else
                    warn "  $key 为空"
                    check_result "config" "$key" "warn" "empty"
                fi
            else
                warn "  $key 未找到"
                check_result "config" "$key" "warn" "missing"
            fi
        done
    else
        fail "~/.hermes/.env 不存在"
        check_result "config" "env-file" "fail" "missing"
    fi

    # risk-policy.yaml 语法
    if [ -f "${ORCHESTRA_HOME}/risk-policy.yaml" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('${ORCHESTRA_HOME}/risk-policy.yaml', encoding='utf-8'))" 2>/dev/null; then
            ok "risk-policy.yaml 语法合法"
            check_result "config" "risk-policy-syntax" "ok" ""
        else
            warn "risk-policy.yaml 语法解析失败"
            check_result "config" "risk-policy-syntax" "warn" "parse error"
        fi
    fi

    # settings.json 合法 JSON
    local settings="${ORCHESTRA_HOME}/claude-config-template/.claude/settings.json"
    if [ -f "$settings" ]; then
        if python3 -c "import json; json.load(open('$settings', encoding='utf-8'))" 2>/dev/null; then
            ok "settings.json 合法"
            check_result "config" "settings-json" "ok" ""
        else
            warn "settings.json 不是合法 JSON"
            check_result "config" "settings-json" "warn" "invalid json"
        fi
    else
        warn "settings.json 不存在"
        check_result "config" "settings-json" "warn" "missing"
    fi
}

# --- 维度 D: 运行时健康 ---
check_runtime() {
    section "[D] 运行时健康"

    # tmux
    if command -v tmux >/dev/null 2>&1; then
        local tmux_ver
        tmux_ver="$(parse_version "$(tmux -V)")"
        ok "tmux $tmux_ver"
        check_result "runtime" "tmux" "ok" "$tmux_ver"
    else
        fail "tmux 未安装"
        check_result "runtime" "tmux" "fail" "missing"
    fi

    # /tmp/hermes-orchestra 可写
    local runtime_root="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
    if mkdir -p "$runtime_root" 2>/dev/null && [ -w "$runtime_root" ]; then
        ok "runtime 根目录可写: $runtime_root"
        check_result "runtime" "runtime-writable" "ok" "$runtime_root"
    else
        fail "runtime 根目录不可写: $runtime_root"
        check_result "runtime" "runtime-writable" "fail" "$runtime_root"
    fi

    # 磁盘空间
    local avail_gb
    avail_gb="$(df -BG "$runtime_root" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G' || echo "0")"
    if [ "${avail_gb:-0}" -ge 1 ] 2>/dev/null; then
        ok "磁盘剩余 ${avail_gb}GB"
        check_result "runtime" "disk-space" "ok" "${avail_gb}GB"
    else
        warn "磁盘剩余空间不足: ${avail_gb}GB"
        check_result "runtime" "disk-space" "warn" "${avail_gb}GB"
    fi
}

# --- 维度 E: 项目级健康 ---
check_project() {
    local pid="$1"
    section "[E] 项目: $pid"

    local runtime_root="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
    local state_root="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
    local runtime_dir="$runtime_root/$pid"
    local state_dir="$state_root/$pid"
    local claude_session="hermes-${pid}-claude"
    local codex_session="hermes-${pid}-codex"

    # runtime 目录
    if [ -d "$runtime_dir" ]; then
        ok "runtime 目录存在"
        check_result "project-$pid" "runtime-dir" "ok" ""
    else
        fail "runtime 目录不存在: $runtime_dir"
        check_result "project-$pid" "runtime-dir" "fail" "missing"
    fi

    # tmux 会话
    if command -v tmux >/dev/null 2>&1; then
        if tmux has-session -t "$claude_session" 2>/dev/null; then
            ok "Claude tmux 会话运行中 ($claude_session)"
            check_result "project-$pid" "tmux-claude" "ok" "running"
        else
            warn "Claude tmux 会话未运行 ($claude_session)"
            check_result "project-$pid" "tmux-claude" "warn" "not running"
        fi

        if tmux has-session -t "$codex_session" 2>/dev/null; then
            ok "Codex tmux 会话运行中 ($codex_session)"
            check_result "project-$pid" "tmux-codex" "ok" "running"
        else
            warn "Codex tmux 会话未运行 ($codex_session)"
            check_result "project-$pid" "tmux-codex" "warn" "not running"
        fi
    fi

    # stale task 检测
    local task_file="$runtime_dir/task.md"
    if [ -f "$task_file" ]; then
        local age_min
        age_min="$(( ($(date +%s) - $(stat -c %Y "$task_file" 2>/dev/null || stat -f %m "$task_file")) / 60 ))"
        if [ "$age_min" -gt 30 ] && [ ! -f "$runtime_dir/codex-result.md" ]; then
            warn "检测到 stale task: task.md 创建于 ${age_min} 分钟前，尚无结果"
            check_result "project-$pid" "stale-task" "warn" "${age_min}min"
        else
            ok "task 文件活跃（${age_min} 分钟前）"
            check_result "project-$pid" "stale-task" "ok" "${age_min}min"
        fi
    fi
}

# --- 自动修复 ---
run_fixes() {
    section "自动修复"
    info "尝试修复已知可安全修复的问题..."

    # Fix 1: PATH
    if ! printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
        local shell_rc
        case "$(basename "$SHELL")" in
            bash) shell_rc="$HOME/.bashrc" ;;
            zsh) shell_rc="$HOME/.zshrc" ;;
            fish) shell_rc="$HOME/.config/fish/config.fish" ;;
            *) shell_rc="$HOME/.profile" ;;
        esac
        mkdir -p "$(dirname "$shell_rc")"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        ok "已追加 PATH 到 $shell_rc（请 source 后生效）"
    fi

    # Fix 2: 文件权限
    if [ -f "${HOME}/.hermes/.env" ] && [ "$(stat -c %a "${HOME}/.hermes/.env" 2>/dev/null)" != "600" ]; then
        chmod 600 "${HOME}/.hermes/.env"
        ok "已修正 ~/.hermes/.env 权限为 600"
    fi

    # Fix 3: 运行时目录
    local runtime_root="${RUNTIME_ROOT:-/tmp/hermes-orchestra}"
    mkdir -p "$runtime_root"
    ok "已确保 runtime 根目录存在"
}

# --- JSON 输出 ---
print_json() {
    python3 - "$@" <<'PY'
import json
import sys

results = []
for line in sys.argv[1:]:
    parts = line.split("|", 3)
    if len(parts) >= 3:
        results.append({
            "category": parts[0],
            "name": parts[1],
            "status": parts[2],
            "detail": parts[3] if len(parts) > 3 else ""
        })

summary = {"ok": 0, "warn": 0, "fail": 0, "info": 0}
for r in results:
    summary[r["status"]] = summary.get(r["status"], 0) + 1

print(json.dumps({
    "results": results,
    "summary": summary,
    "healthy": summary["fail"] == 0
}, indent=2, ensure_ascii=False))
PY
}

# --- 主流程 ---
main() {
    if $JSON_MODE; then
        # JSON 模式下不输出颜色，收集结果后统一打印
        : # 保持默认，但 check_result 仍然记录
    fi

    section "========================================"
    section "Hermes Dev Orchestra — 健康诊断"
    section "========================================"

    check_upstream_cli
    check_install_integrity
    check_config
    check_runtime

    if [ -n "$PROJECT_ID" ]; then
        check_project "$PROJECT_ID"
    fi

    # 总结
    local ok_count=0 warn_count=0 fail_count=0
    for r in "${CHECK_RESULTS[@]}"; do
        local status
        status="$(echo "$r" | cut -d'|' -f3)"
        case "$status" in
            ok) ((ok_count++)) ;;
            warn) ((warn_count++)) ;;
            fail) ((fail_count++)) ;;
        esac
    done

    if $JSON_MODE; then
        print_json "${CHECK_RESULTS[@]}"
        exit "$fail_count"
    fi

    section "========================================"
    section "诊断结果"
    section "========================================"
    echo ""
    ok "通过: $ok_count"
    if [ "$warn_count" -gt 0 ]; then
        warn "警告: $warn_count"
    fi
    if [ "$fail_count" -gt 0 ]; then
        fail "错误: $fail_count"
    fi
    echo ""

    if $FIX_MODE && [ "$fail_count" -eq 0 ] && [ "$warn_count" -gt 0 ]; then
        run_fixes
    fi

    if [ "$fail_count" -eq 0 ]; then
        if [ "$warn_count" -eq 0 ]; then
            section "全部健康 ✔"
        else
            section "基本健康，有 $warn_count 个警告 ⚠"
        fi
    else
        section "发现 $fail_count 个错误，建议修复 ✘"
    fi
    echo ""

    exit "$fail_count"
}

main "$@"
