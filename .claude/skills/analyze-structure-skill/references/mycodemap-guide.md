# mycodemap 使用指南

## 概述

mycodemap 是一个代码分析 CLI 工具，用于生成代码地图、查询符号、分析依赖和评估变更影响。本指南介绍如何在结构分析中使用 mycodemap。

## 安装检测

```bash
# 检测 mycodemap 可用性
if command -v mycodemap &> /dev/null; then
    CODEMAP="mycodemap"
elif [ -f "./node_modules/.bin/mycodemap" ]; then
    CODEMAP="./node_modules/.bin/mycodemap"
else
    CODEMAP="npx @mycodemap/mycodemap"
fi
```

## 核心命令

### 1. 生成代码地图

```bash
$CODEMAP generate
```

**输出文件**：
- `.mycodemap/AI_MAP.md`：项目结构概览，适合 AI 阅读
- `.mycodemap/CONTEXT.md`：项目上下文信息
- `.mycodemap/codemap.json`：结构化数据，供 CLI 查询使用

**使用场景**：
- 项目初始化时生成代码地图
- 代码变更后重新生成（建议在 git hook 中自动执行）
- 分析前确保代码地图是最新的

### 2. 查询符号

```bash
# 查询符号定义
$CODEMAP query -s "<symbol-name>"

# JSON 输出（适合程序处理）
$CODEMAP query -s "<symbol-name>" -j

# 限制结果数量
$CODEMAP query -s "<symbol-name>" -l 5
```

**输出信息**：
- 符号定义位置（文件、行号）
- 符号类型（函数、类、变量等）
- 符号签名和文档
- 引用位置列表

**使用场景**：
- 查找函数/类的定义位置
- 了解符号的使用范围
- 重构前查找所有引用

### 3. 查询模块

```bash
# 查询模块信息
$CODEMAP query -m "<module-path>"

# JSON 输出
$CODEMAP query -m "<module-path>" -j
```

**输出信息**：
- 模块导出符号列表
- 模块依赖的其他模块
- 模块被哪些模块依赖
- 模块复杂度指标

**使用场景**：
- 了解模块职责和接口
- 分析模块依赖关系
- 评估模块设计质量

### 4. 搜索功能

```bash
# 关键词搜索
$CODEMAP query -S "<keyword>"

# 限制结果数量
$CODEMAP query -S "<keyword>" -l 10

# 正则表达式搜索
$CODEMAP query -S "/pattern/" -l 5
```

**使用场景**：
- 查找特定功能的代码位置
- 搜索配置项或常量
- 定位错误处理代码

### 5. 依赖分析

```bash
# 查看模块依赖
$CODEMAP deps -m "<module-path>"

# JSON 输出
$CODEMAP deps -m "<module-path>" -j

# 查看所有依赖
$CODEMAP deps -j
```

**输出信息**：
- 直接依赖列表
- 间接依赖（传递依赖）
- 依赖类型（运行时/开发/可选）
- 依赖版本

**使用场景**：
- 理解模块依赖关系
- 检测循环依赖
- 评估依赖稳定性

### 6. 影响分析

```bash
# 查看文件变更影响
$CODEMAP impact -f "<file-path>"

# 传递影响（包含间接依赖）
$CODEMAP impact -f "<file-path>" --transitive

# JSON 输出
$CODEMAP impact -f "<file-path>" -j
```

**输出信息**：
- 直接受影响的文件列表
- 间接受影响的文件列表（传递依赖）
- 影响路径

**使用场景**：
- 评估代码变更的影响范围
- 制定测试策略
- 规划重构步骤

### 7. 循环依赖检测

```bash
# 检测循环依赖
$CODEMAP cycles

# JSON 输出
$CODEMAP cycles -j
```

**输出信息**：
- 循环依赖路径列表
- 每个循环涉及的模块
- 循环长度

**使用场景**：
- 识别架构问题
- 规划重构优先级
- 评估代码质量

### 8. 复杂度分析

```bash
# 查看复杂度分布
$CODEMAP complexity

# 查看特定文件复杂度
$CODEMAP complexity -f "<file-path>"

# 查看最复杂文件
$CODEMAP complexity --top

# 限制数量
$CODEMAP complexity --top -l 10
```

**输出信息**：
- 圈复杂度分布
- 认知复杂度分布
- 热点文件列表
- 复杂度趋势

**使用场景**：
- 识别需要重构的代码
- 评估代码质量
- 制定重构优先级

## 分析策略

### 1. 自顶向下分析

```bash
# 1. 生成代码地图
$CODEMAP generate

# 2. 阅读项目概览
cat .mycodemap/AI_MAP.md

# 3. 查询核心模块
$CODEMAP query -m "src/core"

# 4. 分析核心模块依赖
$CODEMAP deps -m "src/core"

# 5. 深入分析子模块
$CODEMAP query -m "src/core/auth"
```

### 2. 依赖驱动分析

```bash
# 1. 查看所有依赖
$CODEMAP deps -j

# 2. 检测循环依赖
$CODEMAP cycles

# 3. 分析依赖稳定性
$CODEMAP deps -m "src/utils" -j

# 4. 评估依赖质量
$CODEMAP complexity -f "src/utils/index.ts"
```

### 3. 热点聚焦分析

```bash
# 1. 查看复杂度分布
$CODEMAP complexity

# 2. 查看最复杂文件
$CODEMAP complexity --top -l 10

# 3. 分析热点模块
$CODEMAP query -m "src/complex-module"

# 4. 评估重构需求
$CODEMAP impact -f "src/complex-module/index.ts" --transitive
```

### 4. 接口优先分析

```bash
# 1. 查询模块导出
$CODEMAP query -m "src/api" -j

# 2. 分析接口使用
$CODEMAP impact -f "src/api/index.ts"

# 3. 评估接口设计
$CODEMAP query -s "export function" -l 20
```

## 高级用法

### 1. 批量分析

```bash
# 分析所有模块依赖
for module in src/*/; do
    echo "=== $module ==="
    $CODEMAP deps -m "$module" -j
done
```

### 2. 自定义报告

```bash
# 生成依赖报告
$CODEMAP deps -j > deps-report.json

# 生成复杂度报告
$CODEMAP complexity -j > complexity-report.json

# 合并报告
jq -s '.' deps-report.json complexity-report.json > full-report.json
```

### 3. 集成到 CI/CD

```yaml
# .github/workflows/code-analysis.yml
- name: Generate Code Map
  run: mycodemap generate

- name: Check Cycles
  run: |
    cycles=$(mycodemap cycles -j | jq length)
    if [ "$cycles" -gt 0 ]; then
      echo "Found $cycles circular dependencies"
      exit 1
    fi

- name: Complexity Check
  run: |
    high=$(mycodemap complexity --top -l 1 -j | jq '.[0].complexity')
    if [ "$high" -gt 20 ]; then
      echo "High complexity detected: $high"
      exit 1
    fi
```

## 故障排除

### 1. 代码地图过期

**症状**：查询结果不准确或缺少新文件

**解决**：
```bash
# 重新生成代码地图
$CODEMAP generate
```

### 2. 查询结果为空

**症状**：查询符号或模块无结果

**解决**：
```bash
# 检查代码地图是否存在
ls -la .mycodemap/

# 重新生成
$CODEMAP generate

# 使用模糊搜索
$CODEMAP query -S "<keyword>"
```

### 3. 性能问题

**症状**：命令执行缓慢

**解决**：
```bash
# 使用 --depth 限制分析深度
$CODEMAP generate --depth 3

# 使用 --exclude 排除目录
$CODEMAP generate --exclude "node_modules,dist,build"
```

## 最佳实践

1. **定期更新**：在 git hook 中自动更新代码地图
2. **版本控制**：将 `.mycodemap/` 加入 `.gitignore`
3. **增量分析**：大项目使用 `--depth` 限制分析深度
4. **组合使用**：结合多个命令获取全面洞察
5. **自动化**：将分析集成到 CI/CD 流程
