# Phase 13: Evidence Audit & Discoverability - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 13-evidence-audit-and-discoverability
**Areas discussed:** 根目录索引形式, AGENTS.md 追加策略, 路径引用清单格式与存放, 仓库状态快照范围

---

## 根目录索引形式

| Option | Description | Selected |
|--------|-------------|----------|
| README.md — 轻量级项目首页 | 包含项目简介、状态标注、文档入口链接；不重复增强层内容 | ✓ |
| POINTER.md — 极简指针文件 | 只写一行指向 docs/hermes-dev-orchestra/；侵入性最低 | |
| 不新增文件，扩展现有文件 | 在 AGENTS.md 或 CLAUDE.md 中追加目录导航 | |

**Follow-up Q1: 是否标注版本和状态？**
- Options: Yes / No
- **Selected:** Yes — 标注当前版本和状态（"v1.2 migration in progress"）

**Follow-up Q2: 是否包含快速开始命令？**
- Options: 包含极简快速开始（2-3 个命令）/ 只保留链接
- **Selected:** 只保留链接，不重复命令文档

---

## AGENTS.md 追加策略

| Option | Description | Selected |
|--------|-------------|----------|
| 文件末尾（所有 GSD blocks 之后） | 零风险覆盖，但离文件开头较远 | |
| GSD:project-end 之后，stack 之前 | 逻辑最相关，但需小心标记边界 | |
| 用显式分隔标记，插入文件末尾 | 清晰区分 GSD managed 和项目自定义内容 | ✓ |

**Follow-up Q1: 内容包含哪些部分？**
- Options: Package Boundary + Role Boundary + 目录导航 / 只追加目录导航和简要边界 / 详细展开所有边界定义
- **Selected:** Package Boundary + Role Boundary + 目录导航

**Follow-up Q2: 与现有 Architecture section 的关系？**
- Options: 与 Architecture 互补而非重复 / 完整重写特化版
- **Selected:** 与 Architecture 互补而非重复（只补充 Dev Orchestra 特有约束）

**Follow-up Q3: CLAUDE.md 是否同步更新？**
- Options: Yes — 更新 CLAUDE.md / No — 保持 CLAUDE.md 不变
- **Selected:** Yes — 更新 CLAUDE.md，指向 AGENTS.md 新 section 和 `.planning/SPEC.md`

---

## 路径引用清单格式与存放

| Option | Description | Selected |
|--------|-------------|----------|
| Markdown 表格 | 表格形式，列：文件/行号/路径/上下文/分类；最清晰易读 | ✓ |
| 纯文本列表（含 rg 原始输出） | 保留 rg 原始输出，最低维护成本 | |
| 结构化 JSON | 方便脚本处理，不便于直接阅读 | |

**Follow-up Q1: 存放位置？**
- Options: .planning/phases/13-xxx/ 下 / .planning/audit/ 下 / 根目录
- **Selected:** .planning/phases/13-evidence-audit-and-discoverability/ 下

**Follow-up Q2: 分类方式？**
- Options: 按用途分类 / 按引用路径类型分类 / 不分类
- **Selected:** 按引用路径类型分类（scripts-bin, scripts-lib, skills, docs）

---

## 仓库状态快照范围

| Option | Description | Selected |
|--------|-------------|----------|
| 完整快照 | 分支名、commit SHA、git status、未追踪文件说明、最近 commit 历史 | ✓ |
| 精简快照 | 只包含分支名和 git status --short 输出 | |
| 仅记录变更归属 | 不生成独立文件，归属判断写入 CONTEXT.md | |

**Follow-up Q1: 格式？**
- Options: Markdown 报告 / Shell 输出捕获 / Markdown + 原始输出
- **Selected:** Markdown 报告（结构化可读）

**Follow-up Q2: 存放位置？**
- Options: 与路径引用清单合并 / 独立文件 / 存放到 STATE.md
- **Selected:** 与路径引用清单合并为 `13-EVIDENCE.md`

---

## Claude's Discretion

- Exact wording of README.md project intro
- Specific Agent Role Boundary constraint examples
- Number of recent commits in snapshot (guideline: 5)
- Additional navigation links beyond mandated three

## Deferred Ideas

None — all discussion stayed within Phase 13 scope.
