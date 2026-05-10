## 附录 A：其他核心流程的叙事化版本

> 📎 **相关 ASCII 流程图**：[`ascii-overview.md`](./ascii-overview.md) — 角色职责速查表

---

### F0. Phase 0 平台能力确认（叙事版） `[Hermes 官方]`

**【场景上下文】**
在开始设计 Profile 之前，系统需要验证 Hermes v0.13.0 的关键能力是否真实可用。

**【Jacky 心理活动】**

> "在开始写代码之前，Jacky（你）要求确认：Hermes Agent v0.13.0 是否真的提供了 DESIGN 中提到的所有能力？
> 不能只是看文档说'支持'，必须实际跑一遍。"

**【系统执行验证】**

```bash
# 验证 1: Kanban Board 创建
$ hermes kanban boards create test-verify --name "Test Verification"
[hermes] Board created: test-verify
[hermes] Database: ~/.hermes/kanban/test-verify.db

# 验证 2: 任务创建 + 依赖链
$ hermes kanban create --title "Parent" --board test-verify
[hermes] Task created: t_test_001

$ hermes kanban create --title "Child" --parents t_test_001 --board test-verify
[hermes] Task created: t_test_002

# 验证 3: 任务状态流转
$ hermes kanban claim t_test_001
[hermes] Task t_test_001 claimed

$ hermes kanban complete t_test_001 --summary "Done"
[hermes] Task t_test_001 completed
[hermes] t_test_002 promoted to ready (parent done)

# 验证 4: Profile 隔离
$ hermes profiles list
[hermes] Available profiles:
  - default
  - orchestrator (custom)
  - implementer (custom)

# 验证 5: Curator 存在
$ hermes curator status
[hermes] Curator: running
[hermes] Last cleanup: 2026-05-09T02:00:00Z
[hermes] Skills managed: 12

# 生成验证报告
cat > capability-verification.md << 'EOF'
| 能力 | 官方文档 | 实测命令 | 结果 | 备注 |
|------|---------|---------|------|------|
| Kanban Board | §3.1 | boards create | ✅ PASS | SQLite 持久化 |
| 任务依赖 | §3.3 | create --parents | ✅ PASS | DAG 支持 |
| 状态流转 | §3.2 | claim/complete | ✅ PASS | 自动 promote |
| Profile 隔离 | §5 | profiles list | ✅ PASS | 独立 toolsets |
| Curator | §8 | curator status | ✅ PASS | 后台服务 |
| Gateway | §6 | (配置检查) | ✅ PASS | Telegram 已配置 |
EOF
```

**【Jacky 看到验证报告】**

> "所有关键能力都验证通过了。
> 现在可以开始设计 Profile 和实施增量能力了。"

---

### F2. 背压感知任务准入（叙事版） `[Phase 19 增量]` `[设计假设]`

**【场景上下文】**
Project Gamma 同时有 5 个任务在跑，Implementer 生成了大量代码，但 Reviewer 审查速度跟不上。

**【系统内部】Dispatcher 背压日志：**

```
[2026-05-10T14:00:02Z] Backpressure check:
[2026-05-10T14:00:02Z]   implementer_ready: 12
[2026-05-10T14:00:02Z]   tech-reviewer_ready: 2
[2026-05-10T14:00:02Z]   ratio: 6.0 (threshold: 4.0)
[2026-05-10T14:00:02Z] ACTION: PAUSING implementer spawn
[2026-05-10T14:00:02Z] Log: backpressure paused: ratio=6.0, impl_queue=12, rev_queue=2

[2026-05-10T14:01:02Z] Backpressure check:
[2026-05-10T14:01:02Z]   ratio still 6.0
[2026-05-10T14:01:02Z] ACTION: PAUSED (continuing)

[2026-05-10T14:05:02Z] Backpressure check:
[2026-05-10T14:05:02Z]   implementer_ready: 11
[2026-05-10T14:05:02Z]   tech-reviewer_ready: 3
[2026-05-10T14:05:02Z]   ratio: 3.67
[2026-05-10T14:05:02Z] ACTION: REDUCED spawn (1 per 2 cycles)

[2026-05-10T14:10:02Z] Backpressure check:
[2026-05-10T14:10:02Z]   implementer_ready: 8
[2026-05-10T14:10:02Z]   tech-reviewer_ready: 5
[2026-05-10T14:10:02Z]   ratio: 1.6
[2026-05-10T14:10:02Z] ACTION: NORMAL spawn resumed
```

**【系统向 Jacky 推送】**

```
📊 Project Gamma — 背压调速报告

14:00 发现审查积压: implementer 队列 12，reviewer 队列 2
系统动作: 暂停派发新的 implementer

14:05 积压缓解: ratio 降至 3.67
系统动作: 降速派发（每 2 轮派 1 个）

14:10 恢复正常: ratio 1.6
系统动作: 恢复正常派发

审查吞吐量: 5 tasks / 10min
当前队列: implementer 8, reviewer 5

[查看详情] [调整阈值]
```

**【Jacky 心理活动】**

> "系统自动调速了。 implementer 产出太快，reviewer 跟不上，
> 系统就暂停招新的 implementer，等 reviewer 消化完。
> 
> 这就像工厂流水线的自动阀门——上游太快了就把阀门关小一点。
> 我不需要手动干预，系统自己处理好了。"

---

### F3. L3 风险升级（叙事版） `[Phase 19 增量]`

**【场景上下文】**
Project Delta 的 Implementer 在执行数据库迁移任务时，脚本中包含 `DROP TABLE users CASCADE`。

**【Implementer 内心OS】**

> "我在执行数据库迁移脚本。迁移文件里有：
> ```sql
> DROP TABLE users CASCADE;
> CREATE TABLE users (...);
> ```
> 
> 这是一个破坏性操作！会删除所有用户数据。
> 根据 R14 的 checklist，'被 risk policy 拦截'必须 block。
> 让我检查 risk policy..."

**【系统拦截】Risk Policy Engine：**

```
[RiskPolicy] Command matched: "DROP TABLE"
[RiskPolicy] Pattern: "DROP TABLE"
[RiskPolicy] Level: L3
[RiskPolicy] Approver: user (Jacky)
[RiskPolicy] Action: BLOCK
```

**【Implementer 执行 block】**

```python
kanban_block(
    task_id="t_delta_001",
    reason="risk-policy-intercepted: L3 command 'DROP TABLE users CASCADE'\n"
           "Pattern: DROP TABLE\n"
           "Migration file: migrations/20260510_reset_users.sql\n"
           "Impact: All user data will be deleted\n"
           "Recommendation: Use ALTER TABLE or backup before drop"
)
```

**【系统向 Jacky 推送】**

```
🚨 Project Delta — L3 风险拦截，需要您决策

任务: t_delta_001 (数据库迁移)
拦截命令: DROP TABLE users CASCADE
风险级别: L3 (破坏性操作)

影响:
• 将删除 users 表及所有关联数据
• 涉及 14,230 条用户记录
• 无自动备份机制

建议选项:
A) 拒绝 — 改用 ALTER TABLE 或创建新表迁移
B) 批准 — 先手动备份，再执行 DROP
C) 要求更多信息 — 查看完整迁移脚本

⚠️ 此决策永不超时，必须您手动确认
```

**【Jacky 心理活动】**

> "DROP TABLE users？！这会把所有用户删掉的！
> 
> 等等，让我看看迁移脚本的完整内容...
> 也许这是一个正常的 schema 重构？"

**【Jacky 查看详情】**

```bash
$ hermes kanban show t_delta_001 --full

# 查看迁移脚本
cat migrations/20260510_reset_users.sql
```

**【系统返回】**

```sql
-- migrations/20260510_reset_users.sql
-- ⚠️ DESTRUCTIVE: This will delete ALL user data

DROP TABLE users CASCADE;

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**【Jacky 心理活动】**

> "这确实是一个破坏性迁移。但没有数据备份流程。
> 如果我批准了，所有用户数据就没了。
> 
> 正确的做法应该是：
> 1. 先备份现有 users 表
> 2. 创建新表结构
> 3. 迁移数据（如果有格式变化）
> 4. 验证后删除旧表
>
> 我不应该批准这个 DROP。让我拒绝，并给出正确方案。"

**【Jacky 决策】**

```bash
hermes kanban unblock t_delta_001 \
    --resolution "REJECTED: DROP TABLE is too risky without backup.\n\nCorrect approach:\n1. CREATE TABLE users_new (...new schema...)\n2. INSERT INTO users_new SELECT * FROM users\n3. Verify data integrity\n4. RENAME users TO users_old\n5. RENAME users_new TO users\n6. DROP users_old AFTER 7 days"
```

**【系统提示】**

```
[hermes] Task t_delta_001 unblocked with REJECTION
[hermes] User decision: Reject DROP TABLE, use safe migration path
[hermes] Audit log: L3 decision recorded (task=t_delta_001, decision=reject, user=jacky)
[hermes] Re-spawning implementer with updated instructions
```

**【Implementer 收到决策后】**

> "Jacky 拒绝了 DROP TABLE，并给出了安全的迁移方案。
> 让我按新的方案重写迁移脚本。"

```bash
cat > migrations/20260510_migrate_users.sql << 'EOF'
-- Safe migration: create new table, migrate data, swap

CREATE TABLE users_new (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO users_new (id, email, password_hash, created_at)
SELECT id, email, password_hash, created_at FROM users;

-- Verify count matches
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM users_new;

-- Atomic swap (in transaction)
BEGIN;
ALTER TABLE users RENAME TO users_old;
ALTER TABLE users_new RENAME TO users;
COMMIT;

-- Old table will be dropped after 7-day grace period
-- TODO: schedule DROP TABLE users_old after 2026-05-17
EOF
```

**【Jacky 看到修正后的脚本】**

> "这样就安全多了。数据先迁移到新表，验证通过后再做原子重命名。
> 旧表保留 7 天，万一有问题可以回滚。
> 
> L3 拦截机制确实有用——如果没有它，Implementer 可能就真的执行了 DROP TABLE，
> 我只有在数据丢了之后才会发现。"

---
