#!/usr/bin/env bash
# generate-sprint-files.sh — Generate sprint plan, checklist, and overview markdown
#
# Usage: generate-sprint-files.sh <ASSIGNED_JSON> <OUTPUT_DIR>
# Input: JSON from split-sprints.sh with sprint assignments
# Output: sprint-overview.md, plan-sprint-{N}.md, checklist-sprint-{N}.md

set -euo pipefail

ASSIGNED="${1:?Usage: generate-sprint-files.sh <ASSIGNED_JSON> <OUTPUT_DIR>}"
OUTPUT_DIR="${2:?Missing OUTPUT_DIR}"

if [[ ! -f "$ASSIGNED" ]]; then
  echo "Error: Input file not found: $ASSIGNED" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Generate sprint-overview.md ---
jq -r '
  .sprints as $sprints |
  .requirements as $reqs |
  "# Sprint 总览\n" +
  "\n## 概览\n" +
  "\n| Sprint | 故事点 | 任务数 | 容量利用率 |" +
  "\n|--------|--------|--------|------------|" +
  "\n" + ([$sprints[] |
    "| \(.sprint) | \(.total_sp) SP | \(.units | length) 项 | \(.total_sp * 100 / 7 | floor)% |"
  ] | join("\n")) +
  "\n" +
  "\n## 需求覆盖\n" +
  "\n| 需求 | 覆盖 Sprint |" +
  "\n|------|-------------|" +
  "\n" + ([$sprints[] | . as $s | .units[] |
    .requirements[]? |
    . as $rid | select([$reqs[] | select(.id == $rid)] | length > 0) |
    "| \($rid) | Sprint \($s.sprint) |"
  ] | unique | join("\n")) +
  "\n" +
  "\n## 依赖关系图\n" +
  "\n```mermaid" +
  "\ngraph TD" +
  "\n" + ([$sprints[] | . as $s | .units[] |
    . as $u | .dependencies[]? |
    "  \(.) --> \($u.uid)"
  ] | unique | join("\n")) +
  "\n```\n"
' "$ASSIGNED" > "$OUTPUT_DIR/sprint-overview.md"

# --- Generate plan-sprint-{N}.md and checklist-sprint-{N}.md for each sprint ---
TOTAL_SPRINTS=$(jq '.total_sprints' "$ASSIGNED")

for N in $(seq 1 "$TOTAL_SPRINTS"); do
  SPRINT_DATA=$(jq --argjson n "$N" '.sprints[] | select(.sprint == $n)' "$ASSIGNED")

  # plan-sprint-{N}.md
  echo "$SPRINT_DATA" | jq -r --argjson n "$N" '
    "# Sprint \($n) Plan\n" +
    "\n**总故事点**: \(.total_sp) SP / 7 SP 容量" +
    "\n**任务数**: \(.units | length) 项" +
    "\n" +
    "\n## 任务清单\n" +
    "\n| # | U-ID | 任务 | SP | 依赖 | 状态 |" +
    "\n|---|------|------|----|------|------|" +
    "\n" + ([.units | to_entries[] |
      "| \(.key + 1) | \(.value.uid) | \(.value.name) | \(.value.sp // 1) | \(.value.dependencies | if length == 0 then "-" else join(", ") end) | ⬜ |"
    ] | join("\n")) +
    "\n" +
    "\n## 详细说明\n" +
    "\n" + ([.units | to_entries[] |
      "### Task \(.key + 1) (\(.value.uid)): \(.value.name)\n" +
      "\n- **目标**: \(.value.goal)" +
      "\n- **验收标准**: \(.value.verification | join("; "))" +
      "\n- **涉及文件**: \(.value.files | join(", "))" +
      "\n"
    ] | join("\n"))
  ' > "$OUTPUT_DIR/plan-sprint-${N}.md"

  # checklist-sprint-{N}.md
  echo "$SPRINT_DATA" | jq -r --argjson n "$N" '
    "# Sprint \($n) 验收清单\n" +
    "\n## 验收条件\n" +
    "\n" + ([.units[] |
      "- [ ] **\(.uid)**: \(.verification | join("; "))"
    ] | join("\n")) +
    "\n- [ ] 全部测试通过（exit 0）" +
    "\n- [ ] 代码符合项目规范" +
    "\n" +
    "\n## 任务完成状态\n" +
    "\n" + ([.units[] |
      "- [ ] \(.uid) — \(.name)"
    ] | join("\n")) +
    "\n" +
    "\n## 验证命令\n" +
    "\n```bash" +
    "\n# TODO: 由 LLM 根据项目结构填充具体验证命令" +
    "\n```" +
    "\n" +
    "\n## 签核\n" +
    "\n- [ ] 开发完成" +
    "\n- [ ] 测试通过" +
    "\n- [ ] Code Review 完成" +
    "\n- [ ] 合并到 main\n"
  ' > "$OUTPUT_DIR/checklist-sprint-${N}.md"
done

echo "Generated files in $OUTPUT_DIR:" >&2
ls -1 "$OUTPUT_DIR"/*.md >&2
