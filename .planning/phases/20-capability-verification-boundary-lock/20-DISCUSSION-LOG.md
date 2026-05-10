# Phase 20: Capability Verification & Boundary Lock - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-10
**Phase:** 20-capability-verification-boundary-lock
**Areas discussed:** 验证矩阵证据标准, 未通过项回写策略, 失败项 backlog 落点

---

## 验证矩阵证据标准

| Option | Description | Selected |
|--------|-------------|----------|
| 最小实跑优先（推荐） | 能本机跑最小端到端就必须实跑并留命令/退出码/关键输出；只有明显不适合本机闭环的能力，才允许文档级或 help 级证据 | ✓ |
| 轻证据即可 | `--help`、命令可见性、官方文档摘录、配置项存在就可以判定通过 | |
| 严格实跑 | 除非客观上完全无法本机验证，否则没有最小可运行用例就不算通过 | |
| 其他 | 用户自定义标准 | |

**User's choice:** 最小实跑优先
**Notes:** 文档级或 help 级证据仅作为本机最小闭环明显不适用时的例外路径。

---

## 未通过项回写策略

| Option | Description | Selected |
|--------|-------------|----------|
| 先 matrix，后回写（推荐） | 先把 verdict 全收敛到一份 capability matrix，再按 matrix 结果统一修改 `DESIGN/REQUIREMENTS` | ✓ |
| 直接回写文档 | 验证一项改一项，边验证边改 phase 19 文档 | |
| 双轨并行 | matrix 和 `DESIGN/REQUIREMENTS` 同步更新，但以 matrix 为审计入口 | |
| 其他 | 用户自定义策略 | |

**User's choice:** 先 matrix，后回写
**Notes:** 用户另外要求把验证失败的官方能力自动转成后续待办，而不是只停留在 matrix 备注里。

---

## 失败项 backlog 落点

| Option | Description | Selected |
|--------|-------------|----------|
| ROADMAP Backlog（推荐） | 统一进 `.planning/ROADMAP.md` 的 backlog 区，作为后续 phase 候选 | ✓ |
| Future Requirements | 直接进 `.planning/REQUIREMENTS.md` 的 future requirements | |
| 两处都写 | `ROADMAP Backlog` 放行动入口，`Future Requirements` 保留需求归档 | |
| 其他 | 用户自定义落点 | |

**User's choice:** ROADMAP Backlog
**Notes:** 验证失败项需要具备后续执行入口，因此优先放到 roadmap backlog。是否同步写入其他文档，留给后续 planning 决定。

---

## the agent's Discretion

- 官方能力清单范围留给后续 research/planner 决定。
- 版本锚点策略留给后续 research/planner 决定。

## Deferred Ideas

None.
