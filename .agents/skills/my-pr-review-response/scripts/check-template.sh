#!/usr/bin/env bash
# check-template.sh — 校验 my-pr-review-response 模板填充完整性
#
# Usage: check-template.sh <mode> <file> [<file> ...]
#   mode: agree | disagree | verified | skipped | summary
#
# 退出码:
#   0 — 全部通过
#   1 — 校验失败

set -euo pipefail

MODE="${1:?Usage: check-template.sh <mode> <file> [<file> ...]}"
shift

if [[ $# -lt 1 ]]; then
  echo "Usage: check-template.sh <mode> <file> [<file> ...]" >&2
  exit 1
fi

case "$MODE" in
  agree|disagree|verified|skipped|summary) ;;
  *) echo "❌ 未知 mode: $MODE（应为 agree/disagree/verified/skipped/summary）" >&2; exit 1 ;;
esac

FAILED=0

check_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "❌ $file not found"
    FAILED=1
    return
  fi

  echo "─── Checking $file (mode=$MODE) ───"

  # 通用: ${AUTO:...} 必须全部替换
  local remaining_auto
  remaining_auto=$(grep -oP '\$\{AUTO:[^}]+\}' "$file" | sort -u || true)
  if [[ -n "$remaining_auto" ]]; then
    echo "❌ AUTO 字段未填充:"
    echo "$remaining_auto" | sed 's/^/   /'
    FAILED=1
  fi

  # 通用: ${MANUAL:...} 必须全部替换
  local remaining_manual
  remaining_manual=$(grep -oP '\$\{MANUAL:[^}]+\}' "$file" | sort -u || true)
  if [[ -n "$remaining_manual" ]]; then
    echo "❌ MANUAL 字段未填充:"
    echo "$remaining_manual" | sed 's/^/   /'
    FAILED=1
  fi

  # 通用: ${TABLE_DATA:...} 必须全部替换
  local remaining_table
  remaining_table=$(grep -c '${TABLE_DATA' "$file" || true)
  if [[ "$remaining_table" -gt 0 ]]; then
    echo "❌ TABLE_DATA 字段未替换: $remaining_table 处"
    FAILED=1
  fi

  # mode-specific 检查
  case "$MODE" in
    disagree)
      # 反驳门槛 3 项必须非空
      for section in "代码/文档证据" "架构理由"; do
        if ! grep -qE "^\\*\\*${section}\\*\\*[^*\s]+" "$file"; then
          echo "❌ 反驳门槛未满足: 缺少 '${section}' 内容（不能只写标题）"
          FAILED=1
        fi
      done
      # 替代方案可以 N/A，但标题必须存在
      if ! grep -qE "^\\*\\*3\. 替代方案" "$file"; then
        echo "❌ 反驳门槛未满足: 缺少 '3. 替代方案' 章节（即使内容为 N/A）"
        FAILED=1
      fi
      ;;
    summary)
      # PENDING 必须为 0
      if ! grep -qE "PENDING:\s*0" "$file"; then
        echo "❌ PENDING 项未清零，禁止提交汇总"
        FAILED=1
      fi
      # 必须 @ reviewer
      if ! grep -qE "@\\\$\\{AUTO:reviewer_login\\}" "$file"; then
        # 渲染后应为 @<login>
        if ! grep -qE "^@[a-zA-Z0-9_-]+" "$file"; then
          echo "❌ 缺少 @reviewer mention"
          FAILED=1
        fi
      fi
      ;;
    agree)
      # 必须含修复 commit 引用
      if ! grep -qE "修复 commit" "$file"; then
        echo "❌ AGREE 响应必须含 '修复 commit' 引用"
        FAILED=1
      fi
      ;;
  esac

  if [[ "$FAILED" -eq 0 ]]; then
    echo "✅ $file 通过 (mode=$MODE)"
  fi
}

for f in "$@"; do
  check_file "$f"
done

exit "$FAILED"
