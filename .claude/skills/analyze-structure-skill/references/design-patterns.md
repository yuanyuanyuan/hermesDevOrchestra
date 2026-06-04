# 设计模式识别指南

## 概述

本指南帮助识别项目中使用的设计模式和架构风格，评估模式的适用性和实现质量。设计模式是架构的重要组成部分，正确使用可以提高代码质量，错误使用可能导致复杂性增加。

## 架构风格识别

### 1. 分层架构（Layered Architecture）

**特征**：
- 代码按职责分层（表现层、业务层、数据层）
- 上层依赖下层，下层不依赖上层
- 层间通过接口通信

**识别方法**：
```bash
# 查看目录结构
ls -la src/

# 查看层间依赖
$CODEMAP deps -m "src/presentation" -j
$CODEMAP deps -m "src/business" -j
$CODEMAP deps -m "src/data" -j

# 检查是否有反向依赖
$CODEMAP impact -f "src/data/index.ts" -j | jq '.[] | select(.file | startswith("src/presentation"))'
```

**优点**：
- 职责清晰，易于理解
- 支持独立开发和测试
- 便于团队分工

**缺点**：
- 可能导致性能问题（层间调用开销）
- 可能导致过度工程化
- 可能导致层间耦合

**适用场景**：
- 企业级应用
- 复杂业务逻辑
- 需要清晰职责分离的项目

### 2. 微服务架构（Microservices Architecture）

**特征**：
- 应用拆分为多个独立服务
- 服务间通过 API 通信
- 每个服务独立部署和扩展

**识别方法**：
```bash
# 查看服务目录
ls -la services/

# 查看服务间依赖
$CODEMAP deps -m "services/user" -j
$CODEMAP deps -m "services/order" -j

# 检查 API 定义
$CODEMAP query -S "api" -j | jq '.[] | select(.file | startswith("services/"))'
```

**优点**：
- 独立部署和扩展
- 技术栈灵活
- 故障隔离

**缺点**：
- 运维复杂度高
- 分布式系统挑战
- 数据一致性难保证

**适用场景**：
- 大型复杂系统
- 需要高可用和可扩展性
- 团队规模较大

### 3. 事件驱动架构（Event-Driven Architecture）

**特征**：
- 组件通过事件通信
- 发布-订阅模式
- 松耦合设计

**识别方法**：
```bash
# 查看事件定义
$CODEMAP query -S "event" -j | jq '.[] | select(.type == "class" or .type == "interface")'

# 查看事件发布
$CODEMAP query -S "emit" -j | jq length
$CODEMAP query -S "publish" -j | jq length

# 查看事件订阅
$CODEMAP query -S "on(" -j | jq length
$CODEMAP query -S "subscribe" -j | jq length
```

**优点**：
- 松耦合，易于扩展
- 支持异步处理
- 便于集成外部系统

**缺点**：
- 调试困难
- 事件流复杂
- 可能导致事件风暴

**适用场景**：
- 实时数据处理
- 复杂业务流程
- 需要高扩展性的系统

### 4. 插件架构（Plugin Architecture）

**特征**：
- 核心功能稳定，扩展功能通过插件实现
- 定义清晰的插件接口
- 支持动态加载插件

**识别方法**：
```bash
# 查看插件定义
$CODEMAP query -S "plugin" -j | jq '.[] | select(.type == "class" or .type == "interface")'

# 查看插件注册
$CODEMAP query -S "register" -j | jq length
$CODEMAP query -S "extend" -j | jq length

# 查看插件加载
$CODEMAP query -S "loadPlugin" -j | jq length
$CODEMAP query -S "require(" -j | jq '.[] | select(.file | contains("plugin"))'
```

**优点**：
- 高度可扩展
- 核心稳定
- 便于第三方扩展

**缺点**：
- 接口设计复杂
- 版本兼容性挑战
- 性能开销

**适用场景**：
- 框架和库
- 需要高度可扩展的系统
- 生态系统建设

### 5. 管道-过滤器架构（Pipe-Filter Architecture）

**特征**：
- 数据通过管道传递
- 每个过滤器处理特定任务
- 过滤器可组合

**识别方法**：
```bash
# 查看管道定义
$CODEMAP query -S "pipe" -j | jq length
$CODEMAP query -S "pipeline" -j | jq length

# 查看过滤器定义
$CODEMAP query -S "filter" -j | jq '.[] | select(.type == "class" or .type == "function")'

# 查看中间件
$CODEMAP query -S "middleware" -j | jq length
```

**优点**：
- 灵活组合
- 易于测试
- 支持并行处理

**缺点**：
- 可能导致性能问题
- 调试困难
- 错误处理复杂

**适用场景**：
- 数据处理管道
- 请求处理管道
- 流式处理

## 设计模式识别

### 创建型模式

#### 1. 单例模式（Singleton）

**识别方法**：
```bash
# 查看单例实现
$CODEMAP query -S "getInstance" -j | jq length
$CODEMAP query -S "static instance" -j | jq length
$CODEMAP query -S "private constructor" -j | jq length
```

**实现质量评估**：
- 是否线程安全？
- 是否支持延迟初始化？
- 是否易于测试？

#### 2. 工厂模式（Factory）

**识别方法**：
```bash
# 查看工厂方法
$CODEMAP query -S "create" -j | jq '.[] | select(.name | test("create[A-Z]"))'
$CODEMAP query -S "Factory" -j | jq '.[] | select(.type == "class")'
```

**实现质量评估**：
- 是否遵循开闭原则？
- 是否支持扩展？
- 是否易于测试？

#### 3. 建造者模式（Builder）

**识别方法**：
```bash
# 查看建造者实现
$CODEMAP query -S "Builder" -j | jq '.[] | select(.type == "class")'
$CODEMAP query -S "build()" -j | jq length
$CODEMAP query -S "with(" -j | jq length
```

**实现质量评估**：
- 是否支持链式调用？
- 是否验证构建结果？
- 是否易于使用？

### 结构型模式

#### 1. 适配器模式（Adapter）

**识别方法**：
```bash
# 查看适配器实现
$CODEMAP query -S "Adapter" -j | jq '.[] | select(.type == "class")'
$CODEMAP query -S "adapt" -j | jq length
$CODEMAP query -S "wrap" -j | jq length
```

**实现质量评估**：
- 是否保持接口一致？
- 是否处理异常情况？
- 是否影响性能？

#### 2. 装饰器模式（Decorator）

**识别方法**：
```bash
# 查看装饰器实现
$CODEMAP query -S "Decorator" -j | jq '.[] | select(.type == "class")'
$CODEMAP query -S "decorate" -j | jq length
$CODEMAP query -S "wrap" -j | jq length
```

**实现质量评估**：
- 是否保持接口一致？
- 是否支持组合？
- 是否易于扩展？

#### 3. 外观模式（Facade）

**识别方法**：
```bash
# 查看外观实现
$CODEMAP query -S "Facade" -j | jq '.[] | select(.type == "class")'
$CODEMAP query -S "facade" -j | jq length
```

**实现质量评估**：
- 是否简化接口？
- 是否隐藏复杂性？
- 是否易于使用？

### 行为型模式

#### 1. 观察者模式（Observer）

**识别方法**：
```bash
# 查看观察者实现
$CODEMAP query -S "Observer" -j | jq '.[] | select(.type == "class" or .type == "interface")'
$CODEMAP query -S "subscribe" -j | jq length
$CODEMAP query -S "notify" -j | jq length
```

**实现质量评估**：
- 是否支持多个观察者？
- 是否处理异常情况？
- 是否避免内存泄漏？

#### 2. 策略模式（Strategy）

**识别方法**：
```bash
# 查看策略实现
$CODEMAP query -S "Strategy" -j | jq '.[] | select(.type == "class" or .type == "interface")'
$CODEMAP query -S "strategy" -j | jq length
```

**实现质量评估**：
- 是否支持动态切换？
- 是否易于扩展？
- 是否易于测试？

#### 3. 命令模式（Command）

**识别方法**：
```bash
# 查看命令实现
$CODEMAP query -S "Command" -j | jq '.[] | select(.type == "class" or .type == "interface")'
$CODEMAP query -S "execute" -j | jq length
$CODEMAP query -S "undo" -j | jq length
```

**实现质量评估**：
- 是否支持撤销？
- 是否支持宏命令？
- 是否易于扩展？

## 模式适用性评估

### 评估标准

| 标准 | 说明 | 权重 |
|------|------|------|
| 问题匹配度 | 模式是否适合解决当前问题 | 30% |
| 实现复杂度 | 模式实现是否过于复杂 | 25% |
| 可维护性 | 模式是否提高代码可维护性 | 25% |
| 性能影响 | 模式是否影响性能 | 20% |

### 评估方法

```bash
# 1. 识别模式使用
$CODEMAP query -S "<pattern-name>" -j | jq length

# 2. 分析实现复杂度
$CODEMAP complexity -f "<pattern-file>" -j | jq '.[0].complexity'

# 3. 评估可维护性
$CODEMAP query -m "<pattern-module>" -j | jq '.exports | length'

# 4. 性能分析
$CODEMAP impact -f "<pattern-file>" --transitive -j | jq length
```

### 评估报告

```markdown
## 模式适用性评估

### 模式：[模式名称]
- 使用位置：[文件列表]
- 问题匹配度：[评分] - [说明]
- 实现复杂度：[评分] - [说明]
- 可维护性：[评分] - [说明]
- 性能影响：[评分] - [说明]
- 综合评分：[总分]
- 建议：[保留/重构/移除]
```

## 模式问题识别

### 1. 模式滥用

**症状**：
- 简单问题使用复杂模式
- 过度设计
- 不必要的抽象

**识别方法**：
```bash
# 检查模式使用是否必要
$CODEMAP query -S "<pattern-name>" -j | jq '.[] | {file, line, context}'

# 分析模式复杂度
$CODEMAP complexity -f "<pattern-file>" -j | jq '.[0].complexity'
```

**解决**：
- 移除不必要的模式
- 简化过度设计
- 使用更简单的解决方案

### 2. 模式误用

**症状**：
- 模式实现不正确
- 模式使用场景不当
- 模式组合不当

**识别方法**：
```bash
# 检查模式实现
$CODEMAP query -S "<pattern-name>" -j | jq '.[] | .implementation'

# 分析模式组合
$CODEMAP deps -m "<pattern-module>" -j | jq '.dependencies'
```

**解决**：
- 修正模式实现
- 调整使用场景
- 优化模式组合

### 3. 模式缺失

**症状**：
- 应该使用模式的地方没有使用
- 代码重复
- 耦合度过高

**识别方法**：
```bash
# 查找重复代码
$CODEMAP complexity -j | jq '.[] | select(.duplications > 0)'

# 分析耦合度
$CODEMAP deps -j | jq '.[] | {module, dependencies: .dependencies | length}'
```

**解决**：
- 引入适当模式
- 提取重复代码
- 降低耦合度

## 模式重构指南

### 重构步骤

1. **识别重构目标**：
   - 识别需要重构的模式
   - 评估重构影响
   - 制定重构计划

2. **准备重构**：
   - 编写测试覆盖
   - 创建重构分支
   - 备份代码

3. **执行重构**：
   - 逐步重构
   - 每步验证
   - 及时提交

4. **验证重构**：
   - 运行测试
   - 代码审查
   - 性能测试

### 重构示例

#### 从单例到依赖注入

**Before**：
```typescript
class Database {
  private static instance: Database;
  private constructor() {}
  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }
}
```

**After**：
```typescript
class Database {
  constructor(private config: Config) {}
}

class UserService {
  constructor(private db: Database) {}
}
```

#### 从硬编码到策略模式

**Before**：
```typescript
function process(data: any, type: string) {
  if (type === 'json') {
    return JSON.parse(data);
  } else if (type === 'xml') {
    return parseXML(data);
  }
}
```

**After**：
```typescript
interface Parser {
  parse(data: any): any;
}

class JSONParser implements Parser {
  parse(data: any) { return JSON.parse(data); }
}

class XMLParser implements Parser {
  parse(data: any) { return parseXML(data); }
}

function process(data: any, parser: Parser) {
  return parser.parse(data);
}
```

## 最佳实践

### 1. 选择合适的模式

- 根据问题选择模式，不是根据习惯
- 优先使用简单模式
- 避免过度设计

### 2. 正确实现模式

- 遵循模式的核心思想
- 适应项目实际情况
- 保持实现简洁

### 3. 合理组合模式

- 避免模式冲突
- 保持组合清晰
- 文档化组合原因

### 4. 持续评估模式

- 定期评估模式效果
- 及时调整不适合的模式
- 记录模式使用经验
