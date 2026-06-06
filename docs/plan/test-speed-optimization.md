# 测试速度优化方案

> 生成时间: 2026-06-05
> 基于: scripts/tests/ 静态分析（151 个测试脚本，~24,000 行）

## 一、现状概览

| 维度 | 现状 |
|------|------|
| 测试数量 | 151 个 bash 脚本 |
| 总行数 | ~24,000 行 |
| 执行方式 | `run-all.sh` 串行 `for` 循环 |
| 测试框架 | 自定义 bash assert 库 (`scripts/tests/lib/assert.sh`) |
| 并行能力 | 无 |

## 二、最慢测试分析

### 🥇 第 1 名：`test-gateway-integration-points.sh`（791 行）

**瓶颈：**
- 启动真实 Gateway HTTP 服务器（uvicorn），等待健康检查（轮询最长 5 秒）
- 串行调用 ~25 个 API 端点，覆盖整个模块矩阵
- 包含全量 schema 校验调用（`validate-all`）
- 每个 HTTP 请求有网络往返开销

**预估耗时：8-15 秒**

### 🥈 第 2 名：`test-release-pipeline.sh`（473 行）

**瓶颈：**
- 调用 `orch-full-contract-validate`（加载 17 个配置文件 + schema 校验 + cross-reference）
- 内置 `time.sleep(2)` 故意等待（测试超时机制，不可优化）
- 4 个真实 Python 子进程执行（subprocess.run）

**预估耗时：6-10 秒**

### 🥉 第 3 名：`test-improvement-e-class-mini-debate.sh`（279 行）

**瓶颈：**
- 15 次独立的 `python3 -c` 调用
- 每次 Python 进程启动开销 ~100ms（fork + 解释器初始化 + 模块导入）
- 累计 ~1.5 秒仅用于进程启动

**预估耗时：2-3 秒**

### 第 4 名：`test-gateway-seam-extraction.sh`（344 行）

**瓶颈：** 同时启动 Gateway 服务器 + 13 次 Python 子进程调用

### 第 5 名：`test-intake-completion-prd-fields.sh`（280 行）

**瓶颈：** 14 次 `python3 -c` 调用，模式与 e-class-mini-debate 相同

### 重复调用 `orch-full-contract-validate` 的测试（每次 1-3 秒）

| 测试 | 行数 |
|------|------|
| `test-release-pipeline.sh` | 473 |
| `test-worker-registry.sh` | 422 |
| `test-runtime-activation.sh` | 364 |
| `test-self-evolution.sh` | 354 |
| `test-debate-member-invocation.sh` | 309 |
| `test-debate-assembly.sh` | 175 |
| `test-debate-engine.sh` | 169 |
| `test-degradation-policy.sh` | 150 |
| `test-fixture-policy.sh` | 135 |

9 个测试各自独立调用，假设每次 1.5 秒，累计浪费约 13.5 秒。

## 三、优化方案

### 方案 1：并行化 `run-all.sh`（P0，最大收益）

**目标：** 将串行执行改为并行执行

**实现：**

```bash
# run-all.sh 改造
#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_JOBS="${TEST_PARALLELISM:-$(nproc)}"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

shopt -s nullglob
test_scripts=("$TEST_DIR"/test-*.sh)

run_test() {
    local test_script="$1"
    local log_file="$LOG_DIR/$(basename "$test_script").log"
    if head -n 1 "$test_script" | grep -qE '^#!.*python'; then
        runner=(python3)
    else
        runner=(bash)
    fi
    if "${runner[@]}" "$test_script" >"$log_file" 2>&1; then
        echo "PASS $test_script"
    else
        echo "FAIL $test_script"
        cat "$log_file" >&2
    fi
}

export -f run_test
export TEST_DIR LOG_DIR

# GNU parallel 或 xargs 并行
printf '%s\n' "${test_scripts[@]}" | xargs -P "$MAX_JOBS" -I{} bash -c 'run_test "$@"' _ {}

# 统计结果
PASSED=$(grep -c "^PASS" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
FAILED=$(grep -c "^FAIL" "$LOG_DIR"/*.log 2>/dev/null || echo 0)
echo "Summary: $PASSED passed, $FAILED failed"
```

**预估收益：** 在 8 核机器上从 N 秒 → 接近最慢单个测试的时间（~15 秒），**提速 5-8x**

**风险：**
- 大部分测试使用 `mktemp -d` 创建隔离临时目录，天然无冲突
- 需确认无测试写入共享路径（如 `/tmp` 下的固定文件名）
- Gateway 服务器测试需要分配不同端口（已用动态端口绑定，无冲突）

---

### 方案 2：消除 `orch-full-contract-validate` 重复调用（P1）

**问题：** 9 个测试各自独立运行全量契约校验（加载 17 个配置文件 + schema + cross-reference），输出完全相同。

**分析：**
- 所有 9 个测试验证的是同一个仓库的同一个配置状态
- 每个测试只从输出中 grep 自己关心的 PASS 行
- 已有专门的 `test-full-contract-validation.sh` 负责全量校验

**方案：删除其他测试中的 `orch-full-contract-validate` 调用**

理由：
1. 全量契约校验已由 `test-full-contract-validation.sh` 覆盖
2. Makefile 的 `lint-json` target 也做配置文件校验
3. 其他测试的业务逻辑（debate assembly 选择、worker registry 加载）不依赖全量校验的结果
4. 即使全量校验失败，这些测试也不会报不同的错误

**涉及文件（9 个）：**
- `test-debate-assembly.sh`
- `test-debate-engine.sh`
- `test-debate-member-invocation.sh`
- `test-degradation-policy.sh`
- `test-fixture-policy.sh`
- `test-release-pipeline.sh`
- `test-runtime-activation.sh`
- `test-self-evolution.sh`
- `test-worker-registry.sh`

**每个文件的改动：** 删除以下 2-3 行：

```bash
# 删除这些行
FULL_VALIDATE_OUTPUT="$("$REPO_ROOT/scripts/bin/orch-full-contract-validate" --repo "$REPO_ROOT")"
grep -Fq "PASS ..." <<<"$FULL_VALIDATE_OUTPUT" || fail "..."
grep -Fq "PASS ..." <<<"$FULL_VALIDATE_OUTPUT" || fail "..."
```

**预估收益：** 每个测试节省 1-3 秒，9 个测试累计节省 ~13.5 秒

---

### 方案 3：合并 Python 子进程调用（P2）

**问题：** 部分测试每个测试用例都启动独立的 `python3 -c` 进程，累计启动开销显著。

**目标文件：**
- `test-improvement-e-class-mini-debate.sh`（15 次 → 1 次）
- `test-intake-completion-prd-fields.sh`（14 次 → 1 次）
- `test-gateway-ai-integration.sh`（13 次 → 合并）

**示例（e-class-mini-debate 改造前）：**

```bash
# 每个测试用例独立调用 Python
RESULT=$(python3 -c "
from e_class_mini_debate import create_e_class_dispute
dispute = create_e_class_dispute(...)
print(dispute['status'] == 'pending')
")
```

**改造后：**

```bash
# 单个 Python heredoc 批量执行所有测试
python3 - "$REPO_ROOT" <<'PY'
import sys
sys.path.insert(0, sys.argv[1] + '/scripts/lib')

from e_class_mini_debate import create_e_class_dispute, execute_e_class_debate, ...

# Test 2
dispute = create_e_class_dispute(...)
assert dispute['status'] == 'pending', "Test 2 failed"

# Test 3
report = execute_e_class_debate(...)
assert report['status'] == 'completed', "Test 3 failed"

# ... 所有测试用例

print("ALL PASSED")
PY
```

**预估收益：** 每个测试节省 1-2 秒（减少进程启动次数）

---

### 方案 4：合并 Gateway 服务器测试（P3）

**问题：** 2 个测试（`gateway-ai-integration`、`gateway-seam-extraction`）各自启动独立的 Gateway HTTP 服务器。

**方案：** 将两个测试合并为一个，共享同一个 Gateway 实例。

**预估收益：** 节省一次服务器启动时间（~3-5 秒）

---

### 方案 5：jsonschema 校验 wrapper（P3）

**问题：** 15 个测试调用 `python3 -m jsonschema`，每次重新导入 jsonschema 模块。

**方案：** 创建 `scripts/lib/validate_schema.sh` wrapper：

```bash
#!/usr/bin/env bash
# validate_schema.sh <schema> <instance>
python3 - "$1" "$2" <<'PY'
import json, sys, jsonschema
schema = json.load(open(sys.argv[1]))
instance = json.load(open(sys.argv[2]))
jsonschema.validate(instance, schema)
print("VALID")
PY
```

**预估收益：** 1-2%（影响较小）

## 四、实施优先级

| 优先级 | 方案 | 预估提速 | 实现难度 | 风险 |
|--------|------|----------|----------|------|
| **P0** | 并行化 `run-all.sh` | 5-8x | 低 | 低（需验证无共享状态） |
| **P1** | 消除重复 `orch-full-contract-validate` | ~13.5s | 低 | 无（已有专门测试覆盖） |
| **P2** | 合并 Python 子进程调用 | 1-2s | 中 | 低 |
| **P3** | 合并 Gateway 服务器测试 | ~3-5s | 低 | 低 |
| **P3** | jsonschema wrapper | ~1s | 低 | 低 |

## 五、推荐实施顺序

1. **第一步：P0 并行化** — 投入产出比最高，一行改动可能提速 5-8x
2. **第二步：P1 消除重复校验** — 消除设计层面的冗余，不引入缓存风险
3. **第三步：P2 Python 合并** — 逐文件改造，可分批进行
4. **第四步：P3 Gateway 合并 + jsonschema wrapper** — 锦上添花

## 六、验证方法

每个方案实施后：

1. `time bash scripts/tests/run-all.sh` 对比总耗时
2. `bash scripts/tests/run-all.sh` 确认 0 FAILED
3. 单独运行改造过的测试，确认输出不变
