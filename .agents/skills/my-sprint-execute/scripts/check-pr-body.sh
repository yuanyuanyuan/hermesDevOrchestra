#!/usr/bin/env bash
# check-pr-body.sh — 校验 my-sprint-execute PR body 模板填充完整性
#
# Usage: check-pr-body.sh --file=F --type=T
#   type: feat | fix | docs | infra
#
# 退出码:
#   0 — 全部通过
#   1 — 校验失败

set -euo pipefail

FILE="" TYPE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file=*) FILE="${1#*=}"; shift ;;
    --type=*) TYPE="${1#*=}"; shift ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$FILE" || -z "$TYPE" ]] && { echo "Usage: check-pr-body.sh --file=F --type=T" >&2; exit 1; }
[[ -f "$FILE" ]] || { echo "❌ $FILE not found" >&2; exit 1; }

case "$TYPE" in
  feat|fix|docs|infra) ;;
  *) echo "❌ 未知 type: $TYPE（应为 feat/fix/docs/infra）" >&2; exit 1 ;;
esac

FAILED=0

echo "─── Checking $FILE (type=$TYPE) ───"

# 1. 未替换的占位符
for marker in '${AUTO:' '${MANUAL:' '${VERIFICATION_REPORT_INLINE}' '${COMMITS_TABLE}'; do
  count=$(grep -c "$marker" "$FILE" || true)
  if [[ "$count" -gt 0 ]]; then
    echo "❌ 占位符 '$marker' 未替换 ($count 处)"
    FAILED=1
  fi
done

# 2. type-specific 强制项
case "$TYPE" in
  fix)
    if ! grep -qE "^### Regression Test" "$FILE"; then
      echo "❌ fix 类型 PR body 必须含 '### Regression Test' 章节"
      FAILED=1
    fi
    if ! grep -qE "修复前 FAIL" "$FILE"; then
      echo "❌ fix 类型 PR body 必须含 '修复前 FAIL' 证据"
      FAILED=1
    fi
    ;;
  docs)
    # docs 必填 3 项
    for section in "文档变更" "影响范围" "验收状态"; do
      if ! grep -qE "^### ${section}" "$FILE"; then
        echo "❌ docs 类型 PR body 缺少 '### ${section}' 章节"
        FAILED=1
      fi
    done
    ;;
  infra)
    for section in "兼容性 / 风险评估" "回滚方案"; do
      if ! grep -qE "^### ${section}" "$FILE"; then
        echo "❌ infra 类型 PR body 缺少 '### ${section}' 章节"
        FAILED=1
      fi
    done
    ;;
  feat)
    for section in "需求来源" "实现摘要" "测试覆盖" "验收状态" "Reviewer 重点关注"; do
      if ! grep -qE "^### ${section}" "$FILE"; then
        echo "❌ feat 类型 PR body 缺少 '### ${section}' 章节"
        FAILED=1
      fi
    done
    ;;
esac

# 3. 验收 checkbox 全部勾选
unchecked=$(grep -cE "^- \[ \]" "$FILE" || true)
if [[ "$unchecked" -gt 0 ]]; then
  echo "❌ 验收 checkbox 未全部勾选 ($unchecked 项未打 x)"
  FAILED=1
fi

if [[ "$FAILED" -eq 0 ]]; then
  echo "✅ $FILE 通过 (type=$TYPE)"
  exit 0
fi

exit 1
