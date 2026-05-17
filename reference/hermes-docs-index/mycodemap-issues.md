# mycodemap 使用问题收集

> 收集时间: 2026-05-12
> 项目: hermes-agent (https://github.com/nousresearch/hermes-agent)
> mycodemap 版本: 2.7.1

## 问题清单

### Issue 1: `mycodemap init` 多项目类型标记检测失败

**现象**: 当项目同时存在 `package.json` 和 `pyproject.toml` 时，`mycodemap init` 抛出错误：
```
Error: 检测到多个项目类型标记: package.json, pyproject.toml。非交互环境请使用 --profile <name> 指定。
```

**影响**: 无法在非交互环境（如 CI/CD、AI agent 调用）中自动初始化。

**复现步骤**:
```bash
cd /tmp/hermes-agent-analysis/hermes-agent
mycodemap init  # 失败
mycodemap init --yes  # 也失败，报同样的错误
mycodemap init --profile python --yes  # 需要同时指定两个参数才能成功
```

**预期行为**: `mycodemap init --yes` 应能在检测到多类型时使用默认 profile（或按文件比例自动选择），或至少提供更清晰的错误提示。

**根因**: `init.js:61` 中 `resolveProfile()` 在非交互环境下严格要求 `--profile` 参数，但 `--yes` 标志本应表示"使用默认值继续"。

---

### Issue 2: `mycodemap generate` 因废弃的 mode 配置值失败

**现象**: `mycodemap init --profile python --yes` 生成的 `config.json` 包含 `"mode": "hybrid"`，但 `mycodemap generate` 拒绝该值：
```
Error: [DEPRECATED_PARSER_MODE] 配置文件中的 "mode" 旧值 fast/smart/hybrid 已废弃；请删除该字段或改为 tree-sitter
```

**影响**: 初始化后的项目无法直接运行 generate，需要手动编辑 config.json。

**复现步骤**:
```bash
mycodemap init --profile python --yes
cat .mycodemap/config.json  # 包含 "mode": "hybrid"
mycodemap generate  # 失败
# 手动删除 mode 字段后才能成功
```

**预期行为**: init 命令生成的配置不应包含已废弃的字段。

**根因**: init 命令的 Python profile 模板未更新，仍然写入 `"mode": "hybrid"`，而 generate 命令已废弃该字段。

---

### Issue 3: 未初始化工作区时 `mycodemap generate` 静默返回空结果

**现象**: 在未运行 `mycodemap init` 的项目中直接运行 `mycodemap generate`，不会报错，但返回 0 文件、0 行、0 模块。

**影响**: 用户以为分析成功，实际结果为空，浪费时间排查。

**复现步骤**:
```bash
cd /some/new/project
mycodemap generate  # 输出成功，但所有统计为 0
mycodemap doctor    # 提示 "workspace-not-initialized"
```

**预期行为**: 应在 generate 时检测工作区状态，如果未初始化则提示用户先运行 `mycodemap init`，或自动初始化。

---

### Issue 4: Python 项目 exclude 规则包含测试文件

**现象**: init 生成的 Python profile config 中 exclude 规则包含：
```json
"**/*_test.py",
"**/test_*.py"
```

**影响**: 测试文件不会被纳入代码地图分析。对于需要理解测试覆盖情况的场景（如架构分析），这可能导致遗漏。

**建议**: 将测试文件排除改为可选配置，默认不排除，让用户自行决定。

---

### Issue 5: `mycodemap doctor` 输出格式不友好

**现象**: `mycodemap doctor` 以 JSON 数组格式输出，包含 severity、id、message 等字段，但没有可读的摘要或颜色标识。

**复现步骤**:
```bash
mycodemap doctor
```

**预期行为**: 应提供类似 `npm doctor` 的人类可读输出格式，带颜色标识（OK/WARN/ERROR），JSON 作为 `--json` 选项的替代输出。

---

### Issue 6: `mycodemap complexity` 不支持 `--top` 参数

**现象**: 文档或 help 中可能暗示了 `--top N` 参数，但实际不支持：
```bash
mycodemap complexity --top 20  # error: unknown option '--top'
```

**建议**: 添加 `--top N` 参数用于限制输出数量，大型项目中复杂度列表可能很长。

---

## 使用环境

- **OS**: Linux 6.8.0-88-generic (Ubuntu)
- **Node**: v24.14.0
- **mycodemap**: 2.7.1
- **项目**: hermes-agent (Python, 565 files, ~400K lines)

## 解决方案/Workaround

| Issue | Workaround |
|-------|-----------|
| #1 多类型检测 | 使用 `mycodemap init --profile python --yes` |
| #2 废弃 mode | 初始化后手动删除 config.json 中的 `"mode"` 字段 |
| #3 空结果 | 运行 `mycodemap doctor` 检查状态，确保先 init |
| #4 测试排除 | 手动编辑 config.json 的 exclude 规则 |
| #5 doctor 格式 | 使用 `mycodemap doctor 2>&1 \| python3 -m json.tool` |
| #6 --top 参数 | 使用 `mycodemap complexity 2>&1 \| head -N` |
