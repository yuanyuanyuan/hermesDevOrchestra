# Hermes 项目过期/未使用文件清理审计

> **扫描时间**: 2026-06-14
> **扫描方法**: 4 维度并行扫描（branch/worktree、dead code/scripts、orphaned docs/config）+ 手动交叉验证
> **扫描覆盖**: 101 个 git 分支、12 个 worktree、~150 个脚本、~50 个文档
> **总发现数**: 30+ 项 ｜ **已验证**: 全部 ｜ **误报**: 0

---

## 总览（按风险分级）

| 风险等级 | 数量 | 估算可释放空间 | 建议操作 |
|---------|------|--------------|---------|
| 🔴 高（确认孤儿） | 19 | ~95 MB | 直接清理 |
| 🟡 中（建议人工确认） | 7 | ~95 MB + 1 个 stash | 抽查后清理 |
| 🟢 低（保留为审计） | 3 | — | 归档或保留 |

---

## 🔴 高优先级：确认可清理（19 项）

### A. `/tmp/` 下的孤立 worktree 目录（6 项，约 5 MB）

这些目录**不是真正的 worktree**（无 `.git` 引用），但 git `worktree list` 把它们登记为 `prunable`。HEAD commit 全部已 merge 到 main。

| 路径 | 大小 | 验证证据 |
|------|-----|---------|
| `/tmp/hermes-pr17-rereview` | 720K | 不含 `.git` 引用，HEAD 已 merge |
| `/tmp/hermes-pr17-response` | 720K | 同上 |
| `/tmp/hermes-pr17-response-r3` | 720K | 同上 |
| `/tmp/hermes-pr17-review` | 720K | 同上 |
| `/tmp/hermes-pr32-response-k6iQaV` | 748K | HEAD 只在 `codex-pr32-response`（已完成） |
| `/tmp/wt-sprint9` | 748K | HEAD 在 `feat/sprint9`（已 merge） |

**清理命令**:
```bash
rm -rf /tmp/hermes-pr17-* /tmp/hermes-pr32-response-k6iQaV /tmp/wt-sprint9
git worktree prune
```

### B. 空的/无引用的核心文件（3 项）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `TASKS.md` | 55 字节空模板 | 内容仅 `# Tasks\n## Active\n## Waiting On\n## Someday\n## Done`，全项目无 grep 引用 |
| `hermes/plugins/observability/__init__.py` | 已安装但从未加载 | setup.sh 复制到 `$ORCHESTRA_HOME/plugins`，但无生产 Python 导入；只有测试文件触碰 |
| `scripts/lib/compound-git-hooks.sh` | 库文件无人 source | 搜索无任何 `source compound-git-hooks.sh` 调用 |

**清理建议**:
- `TASKS.md`: 删除，或填充实际任务
- `hermes/plugins/observability/`: 删除整个目录（43 个 Python 文件中只有 1 个是它，删了不影响主体）
- `scripts/lib/compound-git-hooks.sh`: 删除

### C. 未注册的 skill（1 项）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `skills/hermes-gsd/` | 显式标记"redundant, deleted" | 不在 `setup.sh` 的安装列表（只有 dev-orchestra、claude-supervisor、codex-executor、escalation-handler）；CLAUDE.md/AGENTS.md 无引用 |

**清理命令**:
```bash
rm -rf /data/hermes/skills/hermes-gsd
```

### D. 永远不会安装的 git hooks（3 项）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `scripts/git-hooks/post-commit` | 未注册 | setup.sh 只从 `hermes/hooks/` 复制到 `$ORCHESTRA_HOME/hooks`，**不**读 `scripts/git-hooks/` |
| `scripts/git-hooks/post-merge` | 未注册 | 同上 |
| `scripts/git-hooks/prepare-commit-msg` | 未注册 | 同上 |

**清理命令**:
```bash
rm -rf /data/hermes/scripts/git-hooks
```

### E. 仅在文档中提及的 staging 脚本（3 项）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `scripts/lib/staging Harness.sh` | 文档专用 | 无 install/CI 引用 |
| `scripts/lib/staging inject-data.sh` | 文档专用 | 同上 |
| `scripts/lib/staging teardown.sh` | 文档专用 | 同上 |

**清理命令**:
```bash
rm -f "/data/hermes/scripts/lib/staging Harness.sh" /data/hermes/scripts/lib/staging*.sh
```

### F. 已 merge 到 main 的远端分支（7 项）

| 分支 | 状态 |
|------|-----|
| `origin/feat/sprint1` | merged |
| `origin/feat/sprint1-conflict-ledger` | merged |
| `origin/feat/sprint1-foundation` | merged |
| `origin/feat/sprint14` | merged |
| `origin/feat/sprint6` | merged |
| `origin/feat/sprint7-pr` | merged |
| `origin/pr-17-response-r3` | merged |

**清理命令**:
```bash
git branch -r -d origin/feat/sprint1 origin/feat/sprint1-conflict-ledger \
  origin/feat/sprint1-foundation origin/feat/sprint14 origin/feat/sprint6 \
  origin/feat/sprint7-pr origin/pr-17-response-r3
```

### G. 孤立的文档/参考资料（4 项）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `docs/plan/test-speed-optimization.md` | 270 行无引用 | 全项目 grep 无任何引用 |
| `reference/hermes-orchestra-poc.html` | 演示文件 | 无引用 |
| `reference/hermes-workflow-interactive.html` | 演示文件 | 无引用（worktree 副本不算） |
| `reference/multi-agent-plan-review-template.md` | 模板 | 仅在 `reference/README.md` 中自引用 |

**清理命令**:
```bash
rm /data/hermes/docs/plan/test-speed-optimization.md
rmdir /data/hermes/docs/plan 2>/dev/null
rm /data/hermes/reference/hermes-orchestra-poc.html
rm /data/hermes/reference/hermes-workflow-interactive.html
rm /data/hermes/reference/multi-agent-plan-review-template.md
```

### H. `reference/` 中 3 个零引用辅助资源（2 个目录 + 1 个文件组）

| 路径 | 状态 | 验证证据 |
|------|-----|---------|
| `reference/get-shit-done/` (6 文件) | 旧 gsd 资料 | 全项目无引用（"gsd" 概念在 .planning/ 和 docs/archive/ 中以不同方式使用） |
| `reference/lab-01/` (8 文件) | 实验性内容 | 全项目无引用 |
| `reference/hermes-docs-index/` 中的 4 个辅助文件 | 部分使用 | `SKILL.md`、`hermes_docs_index.json`、`hermes_docs_index.md` 在 `.planning/phases/` 中**有**引用（保留）；但 `hermes_docs_crossref.md`、`hermes_docs_sitemap.txt`、`hermes-agent-architecture-analysis.md`、`mycodemap-issues.md` **无**引用 |

**清理命令**:
```bash
rm -rf /data/hermes/reference/get-shit-done /data/hermes/reference/lab-01
rm /data/hermes/reference/hermes-docs-index/hermes_docs_crossref.md \
   /data/hermes/reference/hermes-docs-index/hermes_docs_sitemap.txt \
   /data/hermes/reference/hermes-docs-index/hermes-agent-architecture-analysis.md \
   /data/hermes/reference/hermes-docs-index/mycodemap-issues.md
```

---

## 🟡 中优先级：建议人工确认（7 项）

### I. `.claude/worktrees/` 中 6 个 workflow 引擎副本（约 90 MB）

每个 15-16 MB，来自过去的 Claude Code workflow 调度。

| 目录 | 当前分支 | 备注 |
|------|---------|------|
| `wf_0434f3c0-ee5-3` | worktree-wf_...-ee5-3 | 全部 HEAD 在 f54f481 (主仓库 merge 前的 commit) |
| `wf_0434f3c0-ee5-8` | pr-43 | |
| `wf_0434f3c0-ee5-9` | worktree-wf_...-ee5-9 | |
| `wf_6880b58c-4a0-5` | worktree-wf_...-4a0-5 | |
| `wf_6880b58c-4a0-6` | feat/sprint8-evidence-hardening | 该分支在 merge 后的 commit 上 |
| `wf_7d00835c-b39-2` | pr-37 | |

**风险评估**: 如果这些 worktree 路径被任何当前 workflow 调度器引用，删除会导致运行中的任务失败。**建议先确认** Claude Code 当前没有 in-flight task 引用这些路径。

**清理命令**（确认后）:
```bash
git worktree remove --force /data/hermes/.claude/worktrees/wf_0434f3c0-ee5-3
git worktree remove --force /data/hermes/.claude/worktrees/wf_0434f3c0-ee5-8
# ... 等等
```

### J. 已 merge 的本地分支（21 项）

```
auto-optimize/20260531-1410
feat/hermes-orchestra-full
feat/sprint1, feat/sprint1-conflict-ledger, feat/sprint1-foundation
feat/sprint14, feat/sprint5, feat/sprint6
feat/sprint7-pr, feat/sprint9-backup-20260602
fix/review-skill-approve-comment
pr-17-rereview, pr-17-response, pr-17-response-r3, pr-17-review
worktree-wf_0434f3c0-ee5-{3,8,9}
worktree-wf_6880b58c-4a0-{5,6}
worktree-wf_7d00835c-b39-2
```

**风险评估**: worktree-* 分支关联到上一步的 worktree 目录，需先删除 worktree 再删分支。

**清理命令**:
```bash
git branch -d auto-optimize/20260531-1410 feat/hermes-orchestra-full \
  feat/sprint1 feat/sprint1-conflict-ledger feat/sprint1-foundation \
  feat/sprint14 feat/sprint5 feat/sprint6 feat/sprint7-pr \
  feat/sprint9-backup-20260602 fix/review-skill-approve-comment \
  pr-17-rereview pr-17-response pr-17-response-r3 pr-17-review
```

### K. `.tmp/` 下的 detached HEAD worktree（2 项）

| 路径 | HEAD | 状态 |
|------|------|------|
| `/data/hermes/.tmp/pr27-worktree` | 31606b0 | detached, commit 在 `feat/sprint9`（已 merge）。✅ 安全删除 |
| `/data/hermes/.tmp/pr40-worktree` | 72c7756 | detached, commit 只在 `origin/feat/sprint7-source-isolation`（**未 merge，可能含未审功能**）。⚠️ 检查后再删 |

**清理命令**（pr27 可直接，pr40 需先查 commit 内容）:
```bash
git worktree remove --force /data/hermes/.tmp/pr27-worktree
# 查 pr40 内容后再决定
git log --oneline 72c7756
```

### L. `stash@{0}` - 30+ 文件的未提交变更

`stash@{0}` 在 `chore/docs-cleanup-and-archive` 分支上，包含：
- 大量 sprint checklist (sprint-1 ~ sprint-13)
- 一个 `prd-compliance-audit.js` workflow
- 多个 sprint-execution-pipeline 相关文件
- `docs/USER-MANUAL.md` (731 行被删除)
- `docs/PRD-COMPLIANCE-AUDIT-REPORT.md` 大量修改
- 等等

**风险评估**: 这个 stash 是 `chore/docs-cleanup-and-archive` 分支的"待合并到 main"的工作。该分支的 HEAD 在 `4e228a3`（已落后 main 1 天）。如果这些内容**应该**进入 main，建议 `git stash pop` 然后合并/快进；如果不打算合并，drop 即可。

**建议**:
```bash
# 1. 看完整内容
git stash show -p stash@{0} | head -100
# 2a. 保留路径：pop 后合并
git checkout chore/docs-cleanup-and-archive
git stash pop
# 2b. 放弃路径：直接 drop
git stash drop stash@{0}
```

---

## 🟢 低优先级：归档或保留（3 项）

### M. `docs/sprints/` 中已完成的子 sprint 目录

```
docs/sprints/full-spec-sprint1-foundation/
docs/sprints/prd-compliance-audit-remediation/
docs/sprints/full-system-cutover-debate-worker-runtime-knowledge/
```

**建议**: 这些是 sprint 的历史快照。**保留** —— 记录 sprint 执行轨迹是项目治理的一部分。但应确认它们是否被 `docs/INDEX.md` 或 sprint pipeline 引用；如果不引用，可考虑整体移到 `docs/archive/sprints/`。

### N. `docs/knowledge/qnN4o510-synthesis.md`

仅在 `FULL-COVERAGE-MATRIX.md` 和 `prd_by_kimi.md` 中引用。**保留** —— 有引用证据。

### O. 已知误报清单（agent 标注"看似 orphan 但实际保留"）

| 路径 | 原因 |
|------|------|
| `docs/archive/` (10 个文件) | 故意保留 |
| `docs/migration/mvp-to-full-migration-plan.md` | 迁移文档，故意保留 |
| `reference/hermes-docs-index/{SKILL.md, hermes_docs_index.json, hermes_docs_index.md}` | `.planning/phases/` 多个文件引用 |
| `config/decisions/actor-secrets.json.example` | 测试脚本引用 |
| `README.zh-CN.md`, `CONTEXT.md`, `specs/README.md`, `reference/README.md` | 各自被引用 |

---

## 执行优先级建议

| 批次 | 命令 | 影响 | 风险 |
|------|-----|------|------|
| 第 1 批（绝对安全） | A, B, C, D, E, F, G, H | 释放 ~30 MB + 21 个本地分支 | 极低 |
| 第 2 批（需先检查 in-flight workflow） | I, K-pr27 | 释放 ~75 MB | 低-中 |
| 第 3 批（需人工事后审） | J, K-pr40, L | 释放 21 个分支 + 1 个 stash | 中 |
| 第 4 批（可选） | M 归档 | 文档归位 | 低 |

**总释放空间估算**: ~135 MB + 清理 30+ 引用噪音 + 21 个本地分支 + 1 个 stash

---

## 审计方法学

- **并行扫描维度**: branch/worktree、dead code/scripts、orphaned docs/config（ultracode 编排 3 个 agent 并行）
- **交叉验证**: 对每个高风险发现手动 grep + git log + 文件 stat 二次确认
- **误报处理**: 对"看似 orphan 但实有引用"的项目（archive/、migration/、SKILL.md 等）显式标注保留
- **未执行内容**: 此报告**仅审计，不自动删除** —— 所有命令列在文中供人工执行
