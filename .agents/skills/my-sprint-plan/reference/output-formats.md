# 输出格式参考

## Spec 格式（功能规格说明）

Spec 从 ce-plan 的 Requirements 和 Implementation Units 中提取，结构化为可交付的功能规格。

```markdown
# [项目名] 功能规格说明

## 概述

[1-2 句话描述功能目标和范围]

## 功能需求

### FR-1: [需求名称]
- **描述**: [详细描述]
- **验收标准**: [可验证的条件]
- **优先级**: [P0/P1/P2]

### FR-2: ...

## 非功能需求

- **性能**: [具体指标]
- **安全**: [具体要求]
- **兼容性**: [具体约束]

## 接口契约

### API 端点（如有）
| 方法 | 路径 | 描述 |
|------|------|------|
| POST | /api/xxx | ... |

### 数据模型（如有）
| 实体 | 字段 | 类型 | 约束 |
|------|------|------|------|
| User | id | uuid | PK |

## 范围边界

### 包含
- [功能点]

### 不包含
- [明确排除的功能点]

## 风险与依赖

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| ... | ... | ... |
```

## Schema 格式（API/数据库变更）

当 Plan 涉及 API 端点变更或数据库 Schema 变更时生成。

```markdown
# [项目名] Schema 变更说明

## API 变更

### 新增端点

#### `POST /api/v1/[resource]`

**请求体**:
```json
{
  "field1": "string (required)",
  "field2": "integer (optional)"
}
```

**响应**:
```json
{
  "id": "uuid",
  "field1": "value",
  "created_at": "ISO8601"
}
```

**错误码**:
| 状态码 | 描述 | 场景 |
|--------|------|------|
| 400 | Bad Request | 参数校验失败 |
| 409 | Conflict | 资源已存在 |

### 修改端点

#### `PATCH /api/v1/[resource]/:id`

[变更描述]

## 数据库变更

### 新增表

```sql
CREATE TABLE [table_name] (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field1 VARCHAR(255) NOT NULL,
  field2 INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_[table]_[field] ON [table_name]([field]);
```

### 修改表

```sql
ALTER TABLE [table_name]
  ADD COLUMN IF NOT EXISTS [column] [type] [constraints];
```

### 数据迁移

[迁移策略描述，如有]

## 向后兼容性

- [ ] 新增字段有默认值
- [ ] 旧端点仍然可用
- [ ] 无破坏性变更
```
