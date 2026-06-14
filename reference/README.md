# Hermes Reference 索引

> 本目录集中存放项目参考文档、指南、模板及交互式工具。
> 最后更新：2026-06-14

---

## 当前内容

| 文件/目录 | 类型 | 说明 |
|-----------|------|------|
| [`hermes-workflow-interactive.html`](./hermes-workflow-interactive.html) | 交互页面 | Hermes 工作流交互式可视化页面 |
| [`hermes-workflow.css`](./hermes-workflow.css) | 样式 | Hermes 工作流页面样式 |
| [`hermes-workflow.js`](./hermes-workflow.js) | 脚本 | Hermes 工作流页面交互逻辑 |
| [`hermes-docs-index/`](./hermes-docs-index/) | 索引目录 | Hermes Agent 官方文档 LLM 语义索引（540+ 页） |

### `hermes-docs-index/` 详情

| 文件 | 用途 | 格式 |
|---|---|---|
| `SKILL.md` | 索引使用规则（触发条件、AI Agent 检索流程、hot_pages） | Markdown |
| `hermes_docs_index.json` | 机器索引 — AI Agent 通过代码读取、关键词匹配、检索相关页面 | JSON |
| `hermes_docs_index.md` | 人类导航 — 按分类层级组织的 Markdown 导航索引 | Markdown |

索引数据来源：`hermes-agent.nousresearch.com/docs`，`last_indexed`: 2026-05-09。

---

## 已归档（保留历史，不在主索引中）

- `docs/archive/reference/hermes-orchestra-poc.html` — 旧 POC HTML（2026-05-11）
- `docs/archive/reference/multi-agent-plan-review-template.md` — 旧 Multi-Agent 审查模板
- `docs/archive/reference/get-shit-done/` — 旧 GSD 框架文档（实验用）
- `docs/archive/reference/lab-01/` — 旧交互式实验室页面

---

## 维护说明

- 本目录仅保留**当前活跃使用**的参考资料
- 过期内容请归档到 `docs/archive/reference/`，而非直接删除
- 索引更新应同步修改本 README
