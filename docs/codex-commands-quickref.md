# Codex 命令快速参考

> 使用方式：在对话中 `@docs/codex-commands-quickref.md` 然后说明你要执行的任务

---

## 核心规则

**必须带冒号**：所有命令格式为 `/codex:xxx`（不是 `/codex xxx`）

原因：系统中存在两个 Codex
- ✅ `/codex:xxx` → OpenAI 官方插件（正确）
- ❌ `/codex xxx` → gstack 技能（错误）

---

## 命令速查

| 命令 | 用途 | 适用场景 |
|------|------|----------|
| `/codex:review` | 代码审查 | 审查 git diff 变更 |
| `/codex:adversarial-review` | 对抗性审查 | 质疑设计选择、找潜在问题 |
| `/codex:rescue` | 通用任务 | **文档审查**、调查、修复 |
| `/codex:setup` | 设置 | 首次配置、认证 |
| `/codex:status` | 状态 | 查看任务进度 |
| `/codex:result` | 结果 | 获取任务输出 |
| `/codex:cancel` | 取消 | 终止运行中的任务 |

---

## 常用场景模板

### 代码审查（git diff）
```
@docs/codex-commands-quickref.md

执行 /codex:review
```

### 对抗性代码审查
```
@docs/codex-commands-quickref.md

执行 /codex:adversarial-review
```

### 文档/方案审查
```
@docs/codex-commands-quickref.md

执行 /codex:rescue 审查 [文件路径]，关注 [具体关注点]
```

### 后台运行（大任务）
```
@docs/codex-commands-quickref.md

后台执行 /codex:rescue --background [任务描述]
```

### 指定模型
```
@docs/codex-commands-quickref.md

执行 /codex:rescue --model gpt-5.4 [任务描述]
```

### 指定推理强度
```
@docs/codex-commands-quickref.md

执行 /codex:rescue --effort high [任务描述]
```

---

## 参数参考

### rescue 命令参数
```
/codex:rescue [--background|--wait] [--resume|--fresh] [--model <model>] [--effort <level>] [prompt]
```

| 参数 | 说明 |
|------|------|
| `--background` | 后台运行 |
| `--wait` | 前台运行（等待结果） |
| `--resume` | 继续之前的对话 |
| `--fresh` | 开始新对话 |
| `--model gpt-5.4` | 指定模型 |
| `--effort high` | 推理强度（none/minimal/low/medium/high/xhigh） |

### review/adversarial-review 参数
```
/codex:review [--wait|--background] [--base <ref>] [--scope auto|working-tree|branch]
/codex:adversarial-review [--wait|--background] [--base <ref>] [--scope auto|working-tree|branch] [focus]
```

| 参数 | 说明 |
|------|------|
| `--base main` | 指定基准分支 |
| `--scope working-tree` | 审查工作树 |
| `--scope branch` | 审查整个分支 |
| `--scope auto` | 自动检测（默认） |

---

## 常见错误

| ❌ 错误 | ✅ 正确 |
|---------|---------|
| `/codex review` | `/codex:review` |
| `/codex adversarial-review` | `/codex:adversarial-review` |
| `/codex rescue xxx` | `/codex:rescue xxx` |
| `/codex setup` | `/codex:setup` |

---

## 文件位置

- OpenAI 官方插件：`~/.claude/plugins/cache/openai-codex/codex/1.0.4/`
- gstack 技能（不要用）：`~/.claude/skills/gstack/codex/`
