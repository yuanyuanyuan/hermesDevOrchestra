# GSD 快速参考卡片

> 打印后放在显示器旁 | 版本: v1.50.0 | 2026-05-13

---

## 核心六步循环

```bash
/gsd-new-project           # 1. 初始化
/gsd-discuss-phase 1       # 2. 讨论
/gsd-plan-phase 1          # 3. 计划
/gsd-execute-phase 1       # 4. 执行
/gsd-verify-work 1         # 5. 验证
/gsd-ship 1                # 6. 发布
```

---

## 最常用命令

| 命令 | 用途 | 何时使用 |
|------|------|----------|
| `/gsd-progress` | 查看状态 | 不知道下一步时 |
| `/gsd-progress --next` | 自动推进 | 想让 GSD 自动选择 |
| `/gsd-fast "task"` | 快速修复 | 错字、配置、小改动 |
| `/gsd-quick "task"` | 快速任务 | 需要验证的小功能 |
| `/gsd-resume-work` | 恢复工作 | 新会话开始时 |
| `/gsd-capture "idea"` | 捕获想法 | 随时有灵感时 |

---

## 阶段管理

```bash
/gsd-phase "New feature"           # 添加阶段
/gsd-phase --insert 3 "Urgent fix" # 插入阶段 3.1
/gsd-phase --edit 5                # 编辑阶段
/gsd-phase --remove 7              # 移除阶段
```

---

## 质量保证

```bash
/gsd-code-review 3                 # 代码审查
/gsd-code-review 3 --fix           # 审查并修复
/gsd-review --phase 3 --all        # 跨 AI 评审
/gsd-secure-phase 3                # 安全审查
/gsd-ui-review 3                   # UI 审计
```

---

## 调试

```bash
/gsd-debug "Bug description"       # 启动调试
/gsd-debug --diagnose "Error"      # 仅诊断
/gsd-debug list                    # 列出会话
/gsd-debug continue slug           # 继续会话
/gsd-forensics "What failed"       # 后期调查
```

---

## 上下文管理

```bash
/gsd-pause-work                    # 暂停工作
/gsd-resume-work                   # 恢复工作
/gsd-thread "Topic"                # 创建线程
/gsd-thread list                   # 列出线程
/gsd-capture --note "Idea"         # 快速笔记
/gsd-capture --note list           # 列出笔记
```

---

## 代码库分析

```bash
/gsd-map-codebase                  # 完整分析
/gsd-map-codebase --fast           # 快速概览
/gsd-map-codebase --query auth     # 搜索 intel
/gsd-graphify build                # 构建知识图谱
/gsd-ingest-docs                   # 导入现有文档
```

---

## 里程碑

```bash
/gsd-new-milestone "v2.0"          # 新里程碑
/gsd-milestone-summary             # 生成摘要
/gsd-audit-milestone               # 审计完成情况
/gsd-complete-milestone            # 归档里程碑
```

---

## 配置

```bash
/gsd-config                        # 常用设置
/gsd-config --advanced             # 高级设置
/gsd-config --profile quality      # 切换配置
/gsd-settings                      # 交互式设置
```

---

## 健康检查

```bash
/gsd-health                        # 检查健康
/gsd-health --repair               # 修复问题
/gsd-health --context              # 上下文利用率
/gsd-stats                         # 项目统计
```

---

## 特殊模式

| 模式 | 命令 | 说明 |
|------|------|------|
| 自主执行 | `/gsd-autonomous` | 自动运行所有阶段 |
| 管理器 | `/gsd-manager` | 交互式命令中心 |
| 工作流 | `/gsd-workstreams` | 并行工作流管理 |
| TDD | `/gsd-plan-phase --tdd` | 测试驱动开发 |
| MVP | `/gsd-mvp-phase` | 垂直切片规划 |

---

## 文件位置

```
.planning/
├── PROJECT.md          # 项目愿景
├── REQUIREMENTS.md     # 需求
├── ROADMAP.md          # 路线图
├── STATE.md            # 当前状态
├── config.json         # 配置
├── research/           # 研究成果
├── phases/             # 阶段工件
│   └── 01-xxx/
│       ├── CONTEXT.md  # 讨论结果
│       ├── RESEARCH.md # 研究
│       ├── PLAN.md     # 计划
│       ├── SUMMARY.md  # 执行摘要
│       └── UAT.md      # 验证
├── todos/              # 捕获的待办
└── debug/              # 调试会话
```

---

## 常见场景

### 场景 1: 新项目

```bash
/gsd-map-codebase       # 如有现有代码
/gsd-new-project        # 初始化
/gsd-discuss-phase 1    # 开始讨论
```

### 场景 2: 继续昨天的工作

```bash
/gsd-resume-work        # 恢复上下文
/gsd-progress           # 检查状态
/gsd-progress --next    # 继续
```

### 场景 3: 快速修复

```bash
/gsd-fast "fix typo"    # 一行命令
```

### 场景 4: 紧急修复插入

```bash
/gsd-phase --insert 3 "Fix critical bug"
/gsd-discuss-phase 3.1
/gsd-plan-phase 3.1
/gsd-execute-phase 3.1
```

### 场景 5: 代码质量检查

```bash
/gsd-code-review 1 --fix    # 审查并修复
/gsd-review --phase 1 --all # 多 AI 评审
```

### 场景 6: 调试问题

```bash
/gsd-debug "Bug description"
# 或
/gsd-debug --diagnose "Intermittent error"
```

---

## 配置快速切换

```bash
# 高质量模式
/gsd-config --profile quality

# 平衡模式
/gsd-config --profile balanced

# 预算模式
/gsd-config --profile budget
```

---

## 提示

1. **不要跳过讨论** — `/gsd-discuss-phase` 捕获的关键决策会影响整个阶段
2. **总是验证** — `/gsd-verify-work` 是质量保证的关键
3. **使用代码审查** — `/gsd-code-review --fix` 自动修复常见问题
4. **定期健康检查** — `/gsd-health` 发现潜在问题
5. **捕获想法** — `/gsd-capture --note` 记录任何灵感

---

## 命令前缀速查

| 运行时 | 前缀 | 示例 |
|--------|------|------|
| Claude Code | `/gsd-` | `/gsd-new-project` |
| Codex | `$gsd-` | `$gsd-new-project` |
| Gemini CLI | `/gsd:` | `/gsd:new-project` |

---

*快速参考卡片 v1.0 | 2026-05-13*
