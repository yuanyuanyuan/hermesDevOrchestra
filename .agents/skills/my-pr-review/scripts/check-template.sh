#!/usr/bin/env bash
# check-template.sh — 校验 my-pr-review 模板填充完整性
#
# Usage: check-template.sh <file> [<file> ...]
#
# 检查项:
#   1. 所有 ${AUTO:...} 字段必须已替换
#   2. 所有 ${MANUAL:...} 字段必须已替换
#   3. 所有 ${TABLE_DATA:...} 字段必须已替换
#   4. 必须含 Reviewed-commit footer（用于下轮 diff-since 定位）
#   5. Mode 标记必须合法（first / delta / re-review-full / merge-blocked）
#
# 退出码:
#   0 — 全部通过
#   1 — 校验失败

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: check-template.sh <file> [<file> ...]" >&2
  exit 1
fi

FAILED=0

check_file() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "❌ $file not found"
    FAILED=1
    return
  fi

  echo "─── Checking $file ───"

  # 1. ${AUTO:...} 字段非空
  local remaining_auto
  remaining_auto=$(grep -oP '\$\{AUTO:[^}]+\}' "$file" | sort -u || true)
  if [[ -n "$remaining_auto" ]]; then
    echo "❌ AUTO 字段未填充:"
    echo "$remaining_auto" | sed 's/^/   /'
    FAILED=1
  fi

  # 2. ${MANUAL:...} 字段已填
  local remaining_manual
  remaining_manual=$(grep -oP '\$\{MANUAL:[^}]+\}' "$file" | sort -u || true)
  if [[ -n "$remaining_manual" ]]; then
    echo "❌ MANUAL 字段未填充:"
    echo "$remaining_manual" | sed 's/^/   /'
    FAILED=1
  fi

  # 3. ${TABLE_DATA:...} 已替换
  local remaining_table
  remaining_table=$(grep -c '${TABLE_DATA' "$file" || true)
  if [[ "$remaining_table" -gt 0 ]]; then
    echo "❌ TABLE_DATA 字段未替换: $remaining_table 处"
    FAILED=1
  fi

  # 4. 必须含 Reviewed-commit footer（delta / merge-blocked 强制；first 弱校验）
  if ! grep -q "Reviewed-commit:" "$file"; then
    echo "❌ 缺少 'Reviewed-commit:' footer（delta/merge-blocked 必需）"
    FAILED=1
  fi

  # 5. Mode 标记合法
  if ! grep -qE "Review Mode:\s*(first|delta|re-review-full|merge-blocked)" "$file"; then
    echo "❌ Review Mode 标记缺失或不合法"
    FAILED=1
  fi

  if [[ "$FAILED" -eq 0 ]]; then
    echo "✅ $file 通过"
  fi
}

for f in "$@"; do
  check_file "$f"
done

exit "$FAILED"
