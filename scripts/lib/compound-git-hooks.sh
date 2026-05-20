#!/bin/bash
# =============================================================================
# Compound Engineering Git Hooks - Shared Library
# =============================================================================
# Reusable functions for ce:compound and ce:compound-refresh git hooks.
# Source this file from individual hook scripts.
# =============================================================================

set -eu

# ---- Configuration ----

# Color codes for terminal output
COMPOUND_RED='\033[0;31m'
COMPOUND_GREEN='\033[0;32m'
COMPOUND_YELLOW='\033[1;33m'
COMPOUND_BLUE='\033[0;34m'
COMPOUND_CYAN='\033[0;36m'
COMPOUND_BOLD='\033[1m'
COMPOUND_RESET='\033[0m'

# Enable/disable auto-run of codex exec (set via env or git config)
COMPOUND_AUTO_RUN="${COMPOUND_AUTO_RUN:-false}"
COMPOUND_QUIET="${COMPOUND_QUIET:-false}"

# Directories
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SOLUTIONS_DIR="${REPO_ROOT}/docs/solutions"

# Patterns that indicate a fix/solution worth documenting
COMPOUND_FIX_PATTERNS='\b(fix|fixed|fixes|bug|bugfix|patch|hotfix|resolve|resolves|resolved|close|closes|closed)\b'
COMPOUND_REFACTOR_PATTERNS='\b(refactor|migrate|upgrade|deprecat|rename|restructur|extract)\b'

# ---- Logging ----

_compound_log() {
    if [ "$COMPOUND_QUIET" = "true" ]; then
        return
    fi
    printf "%b\n" "$1"
}

_compound_header() {
    _compound_log ""
    _compound_log "${COMPOUND_CYAN}╔══════════════════════════════════════════════════════════════════════╗${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  ${COMPOUND_BOLD}💡 Compound Engineering${COMPOUND_RESET}                                        ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}╠══════════════════════════════════════════════════════════════════════╣${COMPOUND_RESET}"
}

_compound_footer() {
    _compound_log "${COMPOUND_CYAN}╚══════════════════════════════════════════════════════════════════════╝${COMPOUND_RESET}"
    _compound_log ""
}

# ---- Detection ----

# Check if a commit message indicates a fix worth documenting
# Usage: _compound_is_fix_commit "commit message"
_compound_is_fix_commit() {
    local msg="$1"
    echo "$msg" | grep -qiE "$COMPOUND_FIX_PATTERNS"
}

# Check if a commit message indicates a refactor/migration that may invalidate docs
# Usage: _compound_is_refactor_commit "commit message"
_compound_is_refactor_commit() {
    local msg="$1"
    echo "$msg" | grep -qiE "$COMPOUND_REFACTOR_PATTERNS"
}

# Check if the current repo has a docs/solutions/ directory
_compound_has_solutions_dir() {
    [ -d "$SOLUTIONS_DIR" ]
}

# Count how many .md files exist in docs/solutions/
_compound_solutions_count() {
    if [ -d "$SOLUTIONS_DIR" ]; then
        find "$SOLUTIONS_DIR" -name "*.md" -not -name "README.md" -not -path "*/_archived/*" 2>/dev/null | wc -l
    else
        echo "0"
    fi
}

# Check if codex CLI is available
_compound_has_codex() {
    command -v codex >/dev/null 2>&1
}

# ---- Reminders ----

# Show a reminder to run ce:compound
# Usage: _compound_remind_compound "commit message"
_compound_remind_compound() {
    local commit_msg="$1"
    local short_msg
    short_msg="$(echo "$commit_msg" | head -1 | cut -c1-50)"

    _compound_header
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  检测到修复/解决方案提交：                                       ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}    ${COMPOUND_YELLOW}${short_msg}${COMPOUND_RESET}  ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  建议记录知识文档：                                                  ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}    ${COMPOUND_BOLD}/ce-compound${COMPOUND_RESET} ${short_msg}                    ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  或全自动模式：                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}    ${COMPOUND_BOLD}/ce-compound mode:headless${COMPOUND_RESET}                          ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_footer
}

# Show a reminder to run ce:compound-refresh
# Usage: _compound_remind_refresh [scope_hint]
_compound_remind_refresh() {
    local scope_hint="${1:-}"
    local scope_line=""

    if [ -n "$scope_hint" ]; then
        scope_line=" ${scope_hint}"
    fi

    _compound_header
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  检测到可能影响文档的变更：                                       ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  建议刷新知识文档：                                                  ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}    ${COMPOUND_BOLD}/ce-compound-refresh${scope_line}${COMPOUND_RESET}  ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  或全自动模式：                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}    ${COMPOUND_BOLD}/ce-compound-refresh mode:autofix${scope_line}${COMPOUND_RESET}  ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_footer
}

# Show a tip when docs/solutions/ doesn't exist yet
_compound_tip_init() {
    _compound_header
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  ${COMPOUND_YELLOW}尚未发现 docs/solutions/ 知识库${COMPOUND_RESET}                           ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}                                                                      ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_log "${COMPOUND_CYAN}║${COMPOUND_RESET}  运行一次 /ce-compound 后将自动创建。                                ${COMPOUND_CYAN}║${COMPOUND_RESET}"
    _compound_footer
}

# ---- Auto-run ----

# Attempt to auto-run ce:compound via codex exec (headless mode)
# Usage: _compound_auto_run_compound "context"
_compound_auto_run_compound() {
    local context="$1"

    if [ "$COMPOUND_AUTO_RUN" != "true" ]; then
        return 1
    fi

    if ! _compound_has_codex; then
        _compound_log "${COMPOUND_YELLOW}[compound] COMPOUND_AUTO_RUN=true but codex CLI not found. Skipping auto-run.${COMPOUND_RESET}"
        return 1
    fi

    _compound_log "${COMPOUND_GREEN}[compound] Auto-running ce:compound in headless mode...${COMPOUND_RESET}"

    # Build the prompt for codex exec
    local prompt
    prompt=$(cat <<EOF
Run the ce:compound skill in headless mode to document this recently solved problem.

Context from git commit: ${context}

Instructions:
- Use mode:headless (no interactive questions)
- Extract the problem and solution from the commit context
- Write the documentation to docs/solutions/
- Follow the ce:compound schema and template
EOF
)

    # Run codex exec. Note: this may take a while and consume API tokens.
    # We run it in the background so the git operation isn't blocked.
    (
        cd "$REPO_ROOT"
        codex exec "$prompt" > "${REPO_ROOT}/.compound-auto-run.log" 2>&1
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            _compound_log "${COMPOUND_GREEN}[compound] Auto-run completed. Log: .compound-auto-run.log${COMPOUND_RESET}"
        else
            _compound_log "${COMPOUND_YELLOW}[compound] Auto-run failed (exit $exit_code). Log: .compound-auto-run.log${COMPOUND_RESET}"
        fi
    ) &

    return 0
}

# Attempt to auto-run ce:compound-refresh via codex exec (autofix mode)
# Usage: _compound_auto_run_refresh [scope_hint]
_compound_auto_run_refresh() {
    local scope_hint="${1:-}"

    if [ "$COMPOUND_AUTO_RUN" != "true" ]; then
        return 1
    fi

    if ! _compound_has_codex; then
        _compound_log "${COMPOUND_YELLOW}[compound] COMPOUND_AUTO_RUN=true but codex CLI not found. Skipping auto-run.${COMPOUND_RESET}"
        return 1
    fi

    _compound_log "${COMPOUND_GREEN}[compound] Auto-running ce:compound-refresh in autofix mode...${COMPOUND_RESET}"

    local prompt
    if [ -n "$scope_hint" ]; then
        prompt="Run ce:compound-refresh mode:autofix ${scope_hint} to refresh stale documentation in docs/solutions/."
    else
        prompt="Run ce:compound-refresh mode:autofix to refresh stale documentation in docs/solutions/."
    fi

    (
        cd "$REPO_ROOT"
        codex exec "$prompt" > "${REPO_ROOT}/.compound-refresh-auto-run.log" 2>&1
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            _compound_log "${COMPOUND_GREEN}[compound] Auto-refresh completed. Log: .compound-refresh-auto-run.log${COMPOUND_RESET}"
        else
            _compound_log "${COMPOUND_YELLOW}[compound] Auto-refresh failed (exit $exit_code). Log: .compound-refresh-auto-run.log${COMPOUND_RESET}"
        fi
    ) &

    return 0
}

# ---- Commit Message Analysis ----

# Extract a concise problem description from commit message
# Usage: _compound_extract_context "commit message"
_compound_extract_context() {
    local msg="$1"
    # Remove common prefixes like "fix:", "bugfix:", "feat:" etc.
    local cleaned
    cleaned=$(echo "$msg" | sed -E 's/^[a-z]+(\([^)]*\))?!?:\s*//i')
    # Take first line, truncate to 100 chars
    echo "$cleaned" | head -1 | cut -c1-100
}

# Check if commit touches files that are referenced in docs/solutions/
# Usage: _compound_touches_solutions_references
_compound_touches_solutions_references() {
    local changed_files
    changed_files="$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)"

    if [ -z "$changed_files" ]; then
        return 1
    fi

    if [ ! -d "$SOLUTIONS_DIR" ]; then
        return 1
    fi

    # For each changed file, check if it's mentioned in any solution doc
    local file
    while IFS= read -r file; do
        # Skip non-code files
        case "$file" in
            *.md|*.txt|*.json|*.yaml|*.yml|*.lock|*.svg|*.png|*.jpg) continue ;;
        esac

        local basename
        basename="$(basename "$file")"
        if grep -r -l "$basename" "$SOLUTIONS_DIR" >/dev/null 2>&1; then
            return 0
        fi
    done <<< "$changed_files"

    return 1
}

# Detect the primary scope/module affected by the commit
# Usage: _compound_detect_scope
_compound_detect_scope() {
    local changed_files
    changed_files="$(git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null || true)"

    if [ -z "$changed_files" ]; then
        echo ""
        return
    fi

    # Try to find the most common top-level directory
    local scope
    scope="$(echo "$changed_files" | grep -oE '^[^/]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')"

    # Only return if it's a meaningful directory (not root-level files)
    if [ -n "$scope" ] && [ "$scope" != "$changed_files" ]; then
        echo "$scope"
    else
        echo ""
    fi
}
