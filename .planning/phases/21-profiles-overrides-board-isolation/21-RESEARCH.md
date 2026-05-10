# Phase 21 Research: Profiles, Overrides & Board Isolation

**Phase:** 21 — Profiles, Overrides & Board Isolation  
**Date:** 2026-05-10  
**Status:** Complete

## Research Questions

1. Phase 21 应该把 11 个 workflow profiles 以什么形态落成：纯 repo 模板、纯 installer 生成，还是 hybrid？
2. Hermes 官方 profile / SOUL / kanban / memory 现有语义下，项目级 override 应该落在哪个目录层，而不污染 `~/.hermes/profiles/`？
3. `tech-reviewer` 与 `reviewer` 的命名分歧是否必须在 Phase 21 锁定？
4. 8 个 active + 3 个 reserved profiles 怎样变成可执行仓库产物，而不是继续停留在设计文档？
5. 哪些验证命令能证明 merge 语义、board/workspace/profile/memory 命名，以及多项目隔离没有串线？

## Findings

### 1. Hermes 官方 profile 单元本质上就是独立 `HERMES_HOME`，所以 Phase 21 应以“生成项目级 Hermes home”作为隔离核心

Phase 20 已本地验证：

- `HERMES_HOME=/tmp/... hermes profile create reviewer --no-alias --no-skills`
- `hermes profile show reviewer`
- `hermes profile use reviewer`

这些命令证明官方 profile surface 是真实可用的，而且 profile 文件实际落在目标 `HERMES_HOME/profiles/<name>` 下。官方文档索引也支持同一个结论：

- `https://hermes-agent.nousresearch.com/docs/user-guide/profiles`
- `https://hermes-agent.nousresearch.com/docs/reference/profile-commands`

规划含义：

- Phase 21 不应把“项目隔离”理解为只是在全局 `~/.hermes/profiles/` 下加几个 override 文件。
- 更稳妥的实现单元是：把 `.hermes/projects/{project_slug}/` 作为该项目的 Hermes runtime root，并在这里生成该项目自己的 `profiles/`、`SOUL.md`、memory/session 相关状态。
- 这样可以天然满足 `board/workspace/profile/memory` 统一由 `project_slug` 派生，而不是靠多处约定松散拼接。

### 2. 交付形态应选择 hybrid：仓库内维护 canonical profile catalog，installer/helper 负责生成项目态产物

三种路径对比如下：

| 方案 | 优点 | 问题 |
|------|------|------|
| 纯 repo 模板 | 容易审阅，改动可追踪 | 不能自动落成项目级隔离 runtime，用户还得手工复制/拼接 |
| 纯 installer 生成 | 运行时简单 | 仓库里缺少稳定 source-of-truth，11 个 profiles 的边界不易 code review |
| hybrid | 既有可审阅源文件，也有可执行生成路径 | 需要额外一个 sync/assemble helper |

推荐结论：

- 仓库内保留一套 **canonical profile catalog**，作为“全局 base”的权威来源。
- Phase 21 新增一个专用 helper，例如 `orch-profile-sync`，把 canonical base + 项目 override 编译到 `.hermes/projects/{project_slug}/`。
- `setup.sh` 只负责安装 package/helper；项目级 runtime 生成由 `orch-init` 或 `orch-profile-sync` 触发。

这比“直接把项目 override 写进 `~/.hermes/profiles/`”更符合 PROF-01，也比“只写说明文档不落盘”更接近可执行 MVP。

### 3. `SOUL.md` 的 `global -> project -> role` 语义应被实现为本地装配步骤，而不是假设 Hermes 官方原生支持分层 SOUL

官方文档明确说明 `SOUL.md` 是 Hermes 实例主身份入口：

- `https://hermes-agent.nousresearch.com/docs/user-guide/features/personality`
- `https://hermes-agent.nousresearch.com/docs/guides/use-soul-with-hermes`

但官方资料没有给出“分层 SOUL merge”的现成机制。因此 D-21-03 虽然已经锁定了顺序：

- `global -> project -> role`

真正可执行的落法应是：

1. 仓库保存 role-level SOUL source。
2. 项目 override 目录保存 project-specific SOUL fragment。
3. `orch-profile-sync` 在生成项目 runtime 时，把三层内容装配成最终写入项目级 Hermes home 的 `SOUL.md` 或 profile SOUL 文件。

也就是说，Phase 21 里的 `extends: global` 是**本地编排契约**，不是对 Hermes 核心能力的额外假设。

### 4. Phase 21 必须锁定 canonical role slug 为 `reviewer`，`tech-reviewer` 只保留为设计期遗留别名

当前材料存在两种名字：

- 设计表格里是 `tech-reviewer`
- Roadmap / Requirements / Phase 22 依赖描述里主要使用 `reviewer`
- Phase 20 的 runtime probe 也直接创建了 `reviewer`

如果不在 Phase 21 锁定，Phase 22 的 assignee、队列统计、guardrails、timeout 和 handoff metadata 都会继续漂移。

推荐结论：

- Phase 21 将 runtime canonical slug 锁定为 `reviewer`
- `tech-reviewer` 只作为设计文档兼容说明或 alias 注释保留，不再作为生成产物目录名

Canonical role slugs：

- Active: `pm`, `orchestrator`, `researcher`, `implementer`, `reviewer`, `qa-tester`, `devops-engineer`, `sre-observer`
- Reserved: `pm-researcher`, `product-designer`, `growth-marketer`

### 5. 11 个 profiles 应以“catalog source + reserved disabled contract”落成，而不是只在 DESIGN.md 留一个表

Phase 21 的 repo artifact 至少需要能表达：

- 每个 role 都有明确 `config.yaml`
- 每个 role 都有明确 `SOUL.md`
- reserved roles 的 `toolsets.enabled: []` 与 `model: none` 可被静态验证
- active roles 的职责边界和 toolset allow/deny 能被 grep/test 验证

最小可执行目录建议：

```text
docs/orchestra/hermes/profile-distribution/
  distribution.yaml
  profiles/
    pm/
    orchestrator/
    researcher/
    implementer/
    reviewer/
    qa-tester/
    devops-engineer/
    sre-observer/
    pm-researcher/
    product-designer/
    growth-marketer/
```

这个 catalog 是 repo 内可审阅的 global base；项目态 runtime 则由 helper 生成到：

```text
{repo}/.hermes/projects/{project_slug}/
```

### 6. 项目 override contract 需要把 YAML 配置和 SOUL fragment 分开，避免把 markdown 塞进 override YAML

在不扩大 scope 的前提下，最小合同应拆成两类文件：

```text
{repo}/.hermes/profiles/{role}.override.yaml
{repo}/.hermes/profiles/{role}.project.md
```

用途：

- `.override.yaml`：承接 `model` 与 `toolsets.enabled/disabled`
- `.project.md`：承接项目专属 SOUL 规则片段

这样更符合当前锁定语义：

- `model`：项目级直接覆盖
- `toolsets`：双集合合并，项目优先
- `SOUL.md`：按固定顺序装配

同时避免把“项目 SOUL 片段”强行塞进一个 YAML 字段，后续实现和审查都更清晰。

### 7. board、workspace、profile、memory 的隔离合同应显式落到 project metadata，而不是只靠环境变量口头约定

锁定映射已经明确：

- board = `{project_slug}`
- workspace root = `.hermes/projects/{project_slug}/`
- override dir = `{repo}/.hermes/profiles/`
- memory namespace = `project:{project_slug}`
- 任务/日志/run prefix 也由同一 slug 派生

Phase 21 应新增一个项目元数据文件，例如：

```text
{repo}/.hermes/projects/{project_slug}/project.json
```

其中至少记录：

- `project_slug`
- `board_slug`
- `workspace_root`
- `override_dir`
- `memory_namespace`
- `profile_catalog_version`

这样 `orch-init` / `orch-start` / `orch-status`、后续 Phase 22 dispatcher、以及 tests 都能从同一事实源读取，而不是重复拼字符串。

### 8. 验证重点不是“profile 能创建”，而是“merge 后的项目态 runtime 不污染全局且双项目不串线”

Phase 20 已经证明 Hermes 官方 profile/kanban/memory surface 存在。Phase 21 的验证重点应转成本地 orchestration contract：

1. 11 个 profile source 是否齐全，reserved 是否真 disabled。
2. `reviewer` canonical naming 是否稳定，没有继续产出 `tech-reviewer/` 目录。
3. `orch-profile-sync` 是否把 base + override 编译到 `.hermes/projects/{slug}/`，且不会写回 `~/.hermes/profiles/`。
4. 两个不同 `project_slug` 的生成结果里：
   - board slug 不同
   - memory namespace 不同
   - runtime root 不同
   - profile SOUL / config 互不覆盖
5. Phase 21 文档和 helper 是否把 Phase 20 的外部 blocker 与本 phase 结果区分开。

## Recommended Implementation

1. 在 `docs/orchestra/hermes/profile-distribution/` 建立 11 个 canonical profile source，锁定 `reviewer` 为运行时正式名称。
2. 在仓库根新增 `.hermes/profiles/` contract 文档与示例 override 文件，约定 `.override.yaml` + `.project.md` 双文件模式。
3. 新增 `docs/orchestra/scripts/bin/orch-profile-sync`，负责把 canonical base + 项目 override 组装到 `.hermes/projects/{project_slug}/`。
4. 更新 `docs/orchestra/scripts/bin/orch-init`、`orch-start`、`orch-status`、`lib/orch-common.sh`，让项目元数据显式记录 `project_slug`、board slug、workspace root、override dir、memory namespace。
5. 为 Phase 21 新增两类测试：
   - `test-profile-packaging.sh`：验证 11 个 profiles、merge 语义、无全局污染
   - `test-project-isolation.sh`：验证两个 project slug 的 board/workspace/profile/memory 完全隔离
6. 最后再回写 `.planning/ROADMAP.md`、`.planning/REQUIREMENTS.md`、`.planning/PROJECT.md` 与 `21-VERIFICATION.md`，把 PROF-01 / PROF-02 / FLOW-02 / MEM-01 的交付证据固定下来。

## Validation Architecture

### Static Contract Checks

执行阶段应有一组 grep 级检查，至少覆盖：

- 11 个 profile 目录与 `config.yaml` / `SOUL.md`
- `reviewer` 存在且 `tech-reviewer` 不再作为生成目录
- reserved profiles 的 `toolsets.enabled: []`
- `.hermes/profiles/` 中双文件 override contract
- `project.json` 里 `board_slug`, `workspace_root`, `memory_namespace`

### Runtime Smoke Checks

执行阶段应通过临时 repo 或临时 project slug 跑两组最小闭环：

```bash
rtk docs/orchestra/scripts/tests/test-profile-packaging.sh
rtk docs/orchestra/scripts/tests/test-project-isolation.sh
```

这两个测试的职责应分别是：

- `test-profile-packaging.sh`：验证 base catalog + override 的编译结果
- `test-project-isolation.sh`：验证 `alpha` / `beta` 两个 slug 的 runtime root、board、memory、profile 输出互不串线

### Aggregate Gate

Phase 21 结束前仍应运行：

```bash
rtk make test
```

但验证记录必须区分两类结果：

- 若新加的 Phase 21 测试失败，这是本 phase 回归
- 若仍只失败在已知 `upstream-status` pin mismatch，这是 Phase 20 已记录的外部 blocker，不得误记为 Phase 21 设计失败

## Risks

| Risk | Mitigation |
|------|------------|
| 继续把项目 override 直接理解为“修改 `~/.hermes/profiles/`”。 | 统一采用 generated project home：`.hermes/projects/{project_slug}/`。 |
| SOUL layering 被误当成 Hermes 核心原生功能。 | 在 helper 中显式实现装配；文档写清这是本地 contract。 |
| `tech-reviewer` / `reviewer` 命名继续漂移到 Phase 22。 | 在 Phase 21 直接锁定 canonical runtime slug 为 `reviewer`。 |
| reserved profiles 被创建但仍可能被 spawn。 | reserved 统一 `toolsets.enabled: []` 且 `model: none`，并加静态测试。 |
| 只验证单项目，导致 board/workspace/memory 串线问题到 Phase 22 才暴露。 | Phase 21 强制加入双项目隔离 smoke test。 |
| `rtk make test` 的遗留 pin mismatch 混淆本 phase 结果。 | 在 `21-VERIFICATION.md` 单列 inherited blocker，避免误归因。 |

## Research Complete

Phase 21 的最佳执行路径已经明确：

- 交付形态采用 **hybrid**
- 隔离单元采用 **project-scoped `HERMES_HOME`**
- `SOUL.md` merge 采用 **本地装配**
- runtime canonical naming 锁定为 **`reviewer`**
- 验证重点放在 **无全局污染 + 双项目不串线**
