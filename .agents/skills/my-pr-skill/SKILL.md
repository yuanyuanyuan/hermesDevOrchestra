---
name: my-pr-skill
description: >
  统一封装所有 GitHub 操作，为 my-pr-review、my-pr-review-response、my-sprint-execute
  等 Skill 提供标准化的 GitHub 交互接口。
  底层优先使用 gh CLI 原生命令，原生不支持的操作用 gh api 补齐。
  所有具体命令被封装在 scripts/ 目录下的独立脚本中；本 SKILL.md 只描述接口契约和路由规则。
---

# My PR Skill — GitHub 操作统一封装层

## 设计原则

1. **脚本化**：所有 GitHub 操作由 `scripts/` 目录下的独立脚本完成，SKILL.md 只定义调用契约
2. **优先 gh CLI**：能用 `gh pr`、`gh repo`、`gh issue` 等原生命令的，绝不绕路
3. **gh api 补齐**：gh 没有直接命令的（如批量获取 reviews、update PR branch），用 `gh api` 调用 REST API
4. **变量标准化**：所有脚本统一使用 `--number=N` 等 CLI 参数，调用方不再拼写 gh 命令
5. **零副作用承诺**：本 Skill 只读或只写 GitHub，不碰本地工作区文件（除 `--output` 指定路径外）

## 环境要求

- `gh` CLI 已安装且已认证（`gh auth status` 通过）
- 当前目录为项目本地仓库（gh 自动识别所属仓库）
- 具有 `repo` 或 `pull_requests:write` 权限的 GitHub Token

## 脚本目录

本 Skill 的所有脚本位于：

```
${MY_PR_SKILL_DIR}/scripts/
```

- 若环境变量 `MY_PR_SKILL_DIR` 已设置，直接使用。
- 否则，调用方可通过相对路径推导：
  ```bash
  MY_PR_SKILL_DIR="$(dirname "$0")/../my-pr-skill"
  MY_PR_SKILL_SCRIPTS="${MY_PR_SKILL_DIR}/scripts"
  ```

---

## 脚本清单与路由表

| 脚本 | 职责 | 调用方示例 |
|------|------|-----------|
| `get-repo-info.sh` | 获取仓库 owner / repo / JSON | `${SCRIPTS}/get-repo-info.sh --owner` |
| `get-pr-metadata.sh` | 获取 PR 元数据（标题、分支、SHA、状态等） | `${SCRIPTS}/get-pr-metadata.sh --number=8 --field=url` |
| `get-pr-diff.sh` | 获取 PR diff 补丁 | `${SCRIPTS}/get-pr-diff.sh --number=8 --output=/tmp/pr.diff` |
| `get-pr-reviews.sh` | 获取 PR reviews 和 review comments | `${SCRIPTS}/get-pr-reviews.sh --number=8 --output=/tmp/reviews.json` |
| `get-pr-comments.sh` | 获取 PR 下方 issue comments | `${SCRIPTS}/get-pr-comments.sh --number=8 --output=/tmp/comments.json` |
| `submit-review.sh` | 提交 PR review（REQUEST_CHANGES / COMMENT / APPROVE） | `${SCRIPTS}/submit-review.sh --number=8 --event=COMMENT --body-file=/tmp/review.md` |
| `post-comment.sh` | 在 PR 下发送普通 comment | `${SCRIPTS}/post-comment.sh --number=8 --body-file=/tmp/comment.md` |
| `manage-pr.sh` | 创建 PR / 编辑标签 / 检查状态 | `${SCRIPTS}/manage-pr.sh --create --title="..." --body-file=... --head=...` |
| `update-pr-branch.sh` | 用 base 最新代码更新 PR branch | `${SCRIPTS}/update-pr-branch.sh --number=8` |
| `search.sh` | 搜索代码或 issues | `${SCRIPTS}/search.sh --type=code --query="..."` |

---

## 调用约定（调用方必须遵守）

1. **脚本路径统一**：通过 `${MY_PR_SKILL_SCRIPTS}` 引用脚本，禁止直接写 `gh ...`
2. **参数标准化**：所有脚本接受 `--number=N` 参数指定 PR；输出定向使用 `--output=FILE`
3. **缓存目录统一**：临时文件写入 `${REPO_DIR}/.tmp/`，命名格式 `pr-${PR_NUMBER}-*.json`
4. **错误处理**：脚本失败时返回非零退出码，调用方需检查 `$?`
5. **不绕过**：调用方不得在本 Skill 已封装的场景下直接写 gh 命令（如有缺失接口，先扩展本 Skill）

---

## 扩展规范

如果调用方需要本 Skill 未封装的 GitHub 操作：

1. 在 `scripts/` 下新增独立脚本
2. 优先尝试用 `gh` 原生命令实现；原生不支持的，用 `gh api` 封装
3. 脚本必须支持 `--help`、统一参数风格、返回非零退出码表示失败
4. 将新脚本添加到「脚本清单与路由表」
5. 更新所有引用方的调用方式
