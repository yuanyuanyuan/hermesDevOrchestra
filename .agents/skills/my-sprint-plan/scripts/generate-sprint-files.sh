#!/usr/bin/env bash
# generate-sprint-files.sh — Generate enhanced sprint plan, checklist, and overview markdown
#
# Usage: generate-sprint-files.sh <ASSIGNED_JSON> <OUTPUT_DIR>
# Input: JSON from split-sprints.sh with sprint assignments
# Output: sprint-overview.md, plan-sprint-{N}.md, checklist-sprint-{N}.md
#
# Enhancement v2: Rich plan with approach/test matrix/contract, structured checklist with 4-level verification

set -euo pipefail

ASSIGNED="${1:?Usage: generate-sprint-files.sh <ASSIGNED_JSON> <OUTPUT_DIR>}"
OUTPUT_DIR="${2:?Missing OUTPUT_DIR}"

if [[ ! -f "$ASSIGNED" ]]; then
  echo "Error: Input file not found: $ASSIGNED" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Build cross-sprint contract map from unit dependencies ---
# A unit that is a dependency of another unit in a later sprint is a contract output
CONTRACT_MAP=$(jq '
  .sprints as $sprints |
  # Build uid -> sprint mapping
  reduce $sprints[] as $s (
    {};
    reduce $s.units[] as $u (.; . + {($u.uid): $s.sprint})
  ) as $uid_to_sprint |
  # Build contract list: for each dependency, find consumer sprint
  [
    $sprints[] | . as $s | .units[] | select(.dependencies | length > 0) |
    .dependencies[] | select(. != "None" and . != "none") |
    {
      producer_uid: .,
      producer_sprint: $uid_to_sprint[.],
      consumer_sprint: ($s.sprint)
    }
  ] | group_by(.producer_uid) | map({
    uid: .[0].producer_uid,
    producer_sprint: .[0].producer_sprint,
    consumers: [.[].consumer_sprint] | unique | sort
  })
' "$ASSIGNED")

# --- Generate sprint-overview.md ---
jq -r --argjson contracts "$CONTRACT_MAP" '
  .sprints as $sprints |
  .requirements as $reqs |
  .capacity as $cap |
  $contracts as $contract_map |

  # Build uid -> unit map for looking up unit details
  reduce $sprints[] as $s ({}; reduce $s.units[] as $u (.; . + {($u.uid): $u})) as $umap |

  # Build requirement -> sprint mapping
  reduce $sprints[] as $s ({};
    reduce $s.units[] as $u (.; reduce ($u.requirements // [])[] as $r (.; .[$r] += [$s.sprint]))
  ) as $req_map |

  "# Sprint 总览\n" +
  "\n## 概览\n" +
  "\n| Sprint | 故事点 | 任务数 | 容量利用率 |" +
  "\n|--------|--------|--------|------------|" +
  "\n" + ([$sprints[] |
    "| \(.sprint) | \(.total_sp) SP | \(.units | length) 项 | \(if .total_sp * 100 / $cap | floor == ($sprints[0].total_sp * 100 / $cap | floor) then "**\(.total_sp * 100 / $cap | floor)%** ⚠️均一化" else "\(.total_sp * 100 / $cap | floor)%" end) |"
  ] | join("\n")) +
  "\n" +
  "\n## 需求覆盖\n" +
  "\n| 需求 | 覆盖 Sprint |" +
  "\n|------|-------------|" +
  "\n" + ([$reqs[] |
    .id as $rid |
    $req_map[$rid] as $sprint_list |
    if ($sprint_list | length) > 0 then
      "| \($rid) | Sprint \($sprint_list | sort | map(tostring) | join(", ")) |"
    else empty end
  ] | unique | join("\n")) +
  "\n" +
  "\n## 依赖关系图\n" +
  "\n\`\`\`mermaid" +
  "\ngraph TD" +
  "\n" + ([$sprints[] | . as $s | .units[] |
    . as $u | .dependencies[]? | select(. != "None" and . != "none") |
    "  \(.) --> \($u.uid)"
  ] | unique | join("\n")) +
  "\n\`\`\`\n" +

  # Cross-sprint contracts section
  "\n## 跨 Sprint 接口契约\n" +
  "\n| 契约名称 | 输出 Sprint | 输入 Sprint | 数据格式 | 状态 |" +
  "\n|----------|-------------|-------------|----------|------|" +
  if ($contract_map | length) > 0 then
    "\n" + ([$contract_map[] |
      $umap[.uid] as $unit |
      "| \(.uid): \($unit.name // "") | Sprint \(.producer_sprint) | Sprint \(.consumers | map(tostring) | join(", ")) | 待定义 | ⚠️ 待细化 |"
    ] | join("\n")) + "\n"
  else
    "\n| （无跨 Sprint 依赖） | — | — | — | — |\n"
  end +

  # Known limitations / debt section
  "\n## 已知限制与技术债务\n" +
  "\n| Sprint | 已知限制 | 承接 Sprint | 缓解措施 |" +
  "\n|--------|----------|-------------|----------|" +
  "\n| （由 LLM 在评审时填充） | | | |\n"
' "$ASSIGNED" > "$OUTPUT_DIR/sprint-overview.md"

# --- Generate plan-sprint-{N}.md and checklist-sprint-{N}.md for each sprint ---
TOTAL_SPRINTS=$(jq '.total_sprints' "$ASSIGNED")

for N in $(seq 1 "$TOTAL_SPRINTS"); do
  SPRINT_DATA=$(jq --argjson n "$N" '.sprints[] | select(.sprint == $n)' "$ASSIGNED")

  # plan-sprint-{N}.md
  echo "$SPRINT_DATA" | jq -r --argjson n "$N" '
    . as $sprint |
    # Build dependency status text
    ([.units[] | .dependencies[]? | select(. != "None" and . != "none")] | unique) as $deps |

    "# Sprint \($n) Plan\n" +
    "\n## 元信息" +
    "\n- **总故事点**: \(.total_sp) SP / 7 SP 容量" +
    "\n- **任务数**: \(.units | length) 项" +
    "\n- **前置依赖状态**: \(if ($deps | length) == 0 then "无前置依赖" else "依赖 \( $deps | join(", ") ) — 需确认已完成" end)" +
    "\n- **向下游输出契约**: [由 LLM 根据 unit 内容填写，如 intake_package JSON 格式]" +
    "\n" +
    "\n---\n" +

    "\n## 任务清单" +
    "\n| # | U-ID | 任务 | SP | 依赖 | 状态 |" +
    "\n|---|------|------|----|------|------|" +
    "\n" + ([.units | to_entries[] |
      "| \(.key + 1) | \(.value.uid) | \(.value.name) | \(.value.sp // 1) | \(.value.dependencies | if length == 0 then \"-\" else join(\", \") end) | ⬜ |"
    ] | join("\n")) +
    "\n" +

    # Interface contract changes section
    "\n## 接口契约变更\n" +
    "\n| 契约项 | 变更类型 | 说明 |" +
    "\n|--------|----------|------|" +
    "\n| （由 LLM 根据涉及文件和 unit 内容填写） | 新增/修改/删除 | |" +
    "\n" +

    "\n## 详细说明\n" +
    "\n" + ([.units | to_entries[] |
      $unit := .value |
      $idx := (.key + 1) |

      "### Task \($idx) (\($unit.uid)): \($unit.name)\n" +
      "\n#### 目标\n\($unit.goal)\n" +

      # Approach section - preserve all approach items
      (if ($unit.approach | length) > 0 then
        "\n#### Approach\n" +
        ([$unit.approach[] | "- \(.)"] | join("\n")) + "\n"
      else
        "\n#### Approach\n[由 LLM 根据 source-plan 补充详细实现路径]\n"
      end) +

      # Verification section - split into individual quantifiable items
      (if ($unit.verification | length) > 0 then
        "\n#### 验收标准\n" +
        ([$unit.verification | to_entries[] |
          # Check for fuzzy words
          (.value | test("完整|及时|足够|合理|适当|有效|正确|正常|尽快|充分|必要|主要|关键|重要|良好|优化|完善|确保|保证|尽量|力争|原则上|一般情况下|视情况而定")) as $has_fuzzy |
          "- [ ] **\($unit.uid).\(.key + 1)** — \(if $has_fuzzy then "⚠️[模糊] " else "" end)\(.value)" +
          (if $has_fuzzy then "\n  > ⚠️ 包含不可量化词汇，需补充数值阈值/判定算法" else "" end)
        ] | join("\n")) + "\n"
      else
        "\n#### 验收标准\n[由 LLM 根据需求补充可量化验收条件]\n"
      end) +

      # Test matrix: map test_scenarios to test methods
      (if ($unit.test_scenarios | length) > 0 then
        "\n#### 测试矩阵\n" +
        "| # | Test Scenario | 验证方式 | 预期结果 | 测试脚本 |" +
        "\n|---|---------------|----------|----------|----------|" +
        "\n" + ([$unit.test_scenarios | to_entries[] |
          "| \(.key + 1) | \(.value) | 待指定 | 待指定 | `test-\($unit.uid | ascii_downcase | gsub("_"; "-"))-\(.key + 1).sh` |"
        ] | join("\n")) + "\n"
      else
        "\n#### 测试矩阵\n[由 LLM 补充 Test Scenarios 和测试方法映射]\n"
      end) +

      # Negative test / boundary conditions
      "\n#### 负向测试 / 边界条件\n" +
      "- [ ] [由 LLM 补充：什么条件下应该阻塞/失败/降级]\n" +
      "- [ ] [由 LLM 补充：异常输入/越界/超时场景]\n" +

      # Files section with change scope
      (if ($unit.files | length) > 0 then
        "\n#### 涉及文件\n" +
        ([$unit.files[] |
          # Try to detect Create/Modify from prefix
          (if test("^Create:") then
            "- **Create**: `\(capture("^Create:") // . | ltrimstr("Create:"))` — [说明具体创建内容和用途]"
          elif test("^Modify:") then
            "- **Modify**: `\(capture("^Modify:") // . | ltrimstr("Modify:"))` — [说明具体变更范围，禁止模糊描述如\"更新\"]"
          else
            "- `\(.)` — [说明变更范围]"
          end)
        ] | join("\n")) + "\n"
      else
        ""
      end) +

      # Risk and fallback
      "\n#### 风险与降级策略\n" +
      "| 风险 | 缓解措施 | 降级方案（若失败） |" +
      "\n|------|----------|-------------------|" +
      "\n| [由 LLM 填写] | | |\n" +

      "\n---\n"
    ] | join("\n"))
  ' > "$OUTPUT_DIR/plan-sprint-${N}.md"

  # checklist-sprint-{N}.md - Enhanced 4-level structure
  echo "$SPRINT_DATA" | jq -r --argjson n "$N" '
    . as $sprint |

    "# Sprint \($n) 验收清单\n" +

    # Level 1: Architecture guardrails
    "\n## 一、架构红线合规（不通过则整体阻断）\n" +
    "- [ ] 新增逻辑优先落入 helper modules，非直接堆叠单一大文件\n" +
    "  - 验证：单文件新增代码行占比 < 20%，或已抽取独立 helper\n" +
    "- [ ] 若必须修改单一大文件，已抽取独立 helper 并附带单元测试\n" +
    "- [ ] 接口契约变更已同步到 schema.md / schema.json\n" +
    "- [ ] 自动化 schema↔实现一致性校验通过（如有 schema 变更）\n" +

    # Level 2: Functional acceptance - split each verification into independent items
    "\n## 二、功能验收（逐条独立可勾选）\n" +
    (if ([.units[] | .verification | length] | add) > 0 then
      "\n" + ([.units[] |
        . as $unit |
        ([.verification | to_entries[] |
          (.value | test("完整|及时|足够|合理|适当|有效|正确|正常|尽快|充分|必要|主要|关键|重要|良好|优化|完善|确保|保证|尽量|力争|原则上|一般情况下|视情况而定")) as $has_fuzzy |
          "- [ ] **\($unit.uid).\(.key + 1)** — \(if $has_fuzzy then "⚠️[需量化] " else "" end)\(.value)" +
          (if $has_fuzzy then "\n  > ⚠️ 包含不可量化词汇，验收前必须补充数值阈值/判定算法" else "" end) +
          "\n  - 验证方式：[由 LLM/开发者填写具体命令或断言]\n" +
          "  - 通过标准：[exit 0 / 字段非空 / 返回值匹配 / 时间 ≤ Xs]"
        ] | join("\n"))
      ] | join("\n\n")) + "\n"
    else
      "\n[由 LLM 根据 source-plan verification 补充]\n"
    end) +

    # Level 3: Test coverage
    "\n## 三、测试覆盖\n" +

    # 3.1 Forward tests
    (if ([.units[] | .test_scenarios | length] | add) > 0 then
      "\n### 3.1 正向测试（Test Scenarios）\n" +
      "| # | U-ID | Scenario | 测试脚本 | 状态 |" +
      "\n|---|------|----------|----------|------|" +
      "\n" + ([.units[] | . as $unit |
        .test_scenarios | to_entries[] |
        "| \(.key + 1) | \($unit.uid) | \(.value) | `test-\($unit.uid | ascii_downcase | gsub("_"; "-"))-\(.key + 1).sh` | ⬜ |"
      ] | join("\n")) + "\n"
    else
      "\n### 3.1 正向测试（Test Scenarios）\n" +
      "[由 LLM 根据 source-plan Test Scenarios 补充表格]\n"
    end) +

    # 3.2 Negative tests
    "\n### 3.2 负向测试 / 边界条件\n" +
    "- [ ] [由 LLM 补充：阻塞条件 / 权限越界 / 异常输入测试]\n" +
    "- [ ] [由 LLM 补充：降级 / 超时 / 资源耗尽测试]\n" +
    "- [ ] [由 LLM 补充：schema 校验失败 / 数据损坏恢复测试]\n" +

    # 3.3 Regression tests
    "\n### 3.3 回归测试范围\n" +
    "- [ ] 本 Sprint 相关测试套件全部 exit 0\n" +
    "- [ ] 非本 Sprint 测试失败不阻塞交付，但需确认不影响 main 稳定性\n" +
    "- [ ] 上游依赖 Sprint 的核心测试仍通过\n" +

    # Level 4: Doc/Schema/Config sync
    "\n## 四、文档 / Schema / 配置同步\n" +
    "- [ ] 所有涉及文件变更已逐项确认（Create/Modify → Verify）\n" +
    "- [ ] schema.md 与 schema.json 字段名/类型/约束一致（差异 0 项）\n" +
    "- [ ] 用户流程文档已同步更新\n" +
    "- [ ] ADR / 架构文档已同步更新（如有架构变更）\n" +
    "- [ ] 配置变更已验证向后兼容\n" +
    "- [ ] 向下游 Sprint 的接口契约已文档化\n" +

    # Verification commands
    "\n## 验证命令\n" +
    "\n\`\`\`bash\n" +
    "# 必须明确列出每个命令的通过标准，禁止仅写脚本名\n" +
    (if ([.units[] | .test_scenarios | length] | add) > 0 then
      ([.units[] | . as $unit |
        .test_scenarios | to_entries[] |
        "# \( $unit.uid ) Test Scenario \(.key + 1): \(.value)\n" +
        "bash scripts/tests/test-\($unit.uid | ascii_downcase | gsub("_"; "-"))-\(.key + 1).sh\n" +
        "# 期望：exit 0，输出包含 \"PASS\"\n"
      ] | join("\n"))
    else
      "# TODO: 根据 Test Scenarios 填充具体验证命令\n"
    end) +
    "\n# 通用校验\n" +
    "make lint  # 期望：exit 0\n" +
    "make typecheck  # 期望：exit 0\n" +
    "\`\`\`\n" +

    # Sign-off
    "\n## 签核\n" +
    "- [ ] 开发完成\n" +
    "- [ ] 全部测试通过（含负向测试）\n" +
    "- [ ] Code Review 完成\n" +
    "- [ ] **文档与实现一致性已确认**\n" +
    "- [ ] **架构红线合规已确认**\n" +
    "- [ ] **向下游 Sprint 接口契约已确认**\n" +
    "- [ ] 合并到 main\n"
  ' > "$OUTPUT_DIR/checklist-sprint-${N}.md"
done

echo "Generated files in $OUTPUT_DIR:" >&2
ls -1 "$OUTPUT_DIR"/*.md >&2
