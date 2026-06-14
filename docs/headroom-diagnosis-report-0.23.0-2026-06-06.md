# Headroom Proxy 诊断报告(**0.23.0 时点存档**)

> **📦 归档说明(2026-06-14)**:本报告是 **headroom-ai 0.23.0** 在 **2026-06-06 21:07 UTC** 时的诊断快照。**0.23.0 → 0.25.0 升级后内容仍可作为时点证据,但所有数字 / 字段 / 行号都已过期**。
>
> **关于 0.25.0 升级后的诊断**:见 [HEADROOM.md §0.0 0.25.0 升级要点](./HEADROOM.md#00-0250-升级要点2026-06-14-升级) 和 [HEADROOM-OPS.md §7 关键事实速记](./HEADROOM-OPS.md#7-关键事实速记)。Phase 4 真流量对比 + 新诊断报告待后续工作。
>
> 本文件名已于 2026-06-14 从 `headroom-diagnosis-report-2026-06-06.md` 改为 `headroom-diagnosis-report-0.23.0-2026-06-06.md` 以明示时点。Git 重命名已保留。

---

# Headroom Proxy 诊断报告

> **生成时间**: 2026-06-06 21:07 UTC  
> **Proxy 版本**: 0.23.0  
> **Proxy PID**: 637240  
> **运行模式**: token  
> **配置源**: `/home/stark/.config/headroom/config.yaml`

---

## 一、执行摘要

本次诊断检查了 Headroom Proxy 的 **Token 压缩效果** 和 **Cache 效果**。核心发现：

| 维度 | 状态 | 关键发现 |
|------|------|---------|
| **Prefix Cache** | ✅ 极佳 | 97.7% 命中率，100% 请求命中，节省 $2.62 |
| **Codex 压缩** | ✅ 有效 | gpt-5.5 平均压缩率 **5.9%**，单次最高 **6.65%** |
| **Claude 压缩** | ⚠️ 极低 | MiniMax-M3 平均压缩率 **0.7%**，大量 tool 消息被排除 |
| **Kompress 模型** | ❌ 不可用 | HF 模型下载失败（网络 308 redirect 后断连），fallback 到 passthrough |
| **Code-Aware** | ❌ 未激活 | ContentRouter 内部硬编码 `enable_code_aware=False` |

---

## 二、服务状态概览

```
Proxy:     ✓ 运行中 (PID=637240)
Status:    healthy (ready=True)
Uptime:    ~18 分钟
Mode:      token
Optimize:  ENABLED
Cache:     ENABLED
Memory:    ENABLED (multi-provider)
CodeAware: ENABLED (proxy 层面)
Telemetry: DISABLED
```

### 后端路由

| 路径 | 目标 Provider | URL |
|------|--------------|-----|
| `/v1/messages` | anthropic | `https://api.minimaxi.com/anthropic` |
| `/v1/chat/completions` | openai | `https://api.codexzh.com/v1` |
| `/v1/responses` | openai | `https://api.codexzh.com/v1` (HTTP + WebSocket) |

---

## 三、Token 压缩效果分析

### 3.1 总体流量

| 指标 | 数值 |
|------|------|
| 总 API 请求 | **141** |
| 总输入 Tokens | **6,766,130** |
| 总输出 Tokens | **97,990** |
| 总节省 Tokens | **162,704** (2.35%) |
| 压缩节省金额 | **$0.0014** |
| Cache 节省金额 | **$2.6152** |

### 3.2 Claude (Anthropic → MiniMax-M3) 路径

| 指标 | 数值 |
|------|------|
| 请求数 | **105** |
| 输入 Tokens | **4,328,923** |
| 节省 Tokens | **30,209** |
| 压缩率 | **0.7%** |
| 客户端 | `claude-code` |

**最近请求示例**（10 条）:

| # | 输入 Tokens | 优化后 | 节省 | 压缩率 | 延迟 | Transforms |
|---|------------|--------|------|--------|------|-----------|
| 136 | 43,807 | 43,807 | 0 | 0.0% | 3.7s | `router:excluded:tool` ×17 |
| 137 | 44,314 | 44,314 | 0 | 0.0% | 4.5s | `router:excluded:tool` ×17 |
| 138 | 44,686 | 44,686 | 0 | 0.0% | 5.3s | `router:excluded:tool` ×17 |
| 139 | 44,821 | 44,821 | 0 | 0.0% | 3.2s | `router:excluded:tool` ×18 |
| 140 | 45,219 | 45,219 | 0 | 0.0% | 6.0s | `router:excluded:tool` ×17 |
| 141 | 46,123 | 46,123 | 0 | 0.0% | 3.6s | `router:excluded:tool` ×17 |
| 142 | 46,876 | 46,876 | 0 | 0.0% | 3.8s | `router:excluded:tool` ×19 |
| 143 | 47,580 | 47,580 | 0 | 0.0% | 4.7s | `router:excluded:tool` ×19 |
| 135 | 10,862 | 10,862 | 0 | 0.0% | **330.9s** | `router:excluded:tool` ×1 |

**关键发现**: Claude 请求中几乎所有消息都被标记为 `router:excluded:tool`，ContentRouter 选择不压缩 tool 消息。但即使是非 tool 内容（如请求 #135，只有 1 个 excluded:tool），也没有产生任何 token 节省。

### 3.3 Codex (OpenAI → gpt-5.5/5.4) 路径

| 指标 | gpt-5.5 | gpt-5.4 | gpt-5.4-mini |
|------|---------|---------|-------------|
| 请求数 | 31 | 4 | 1 |
| 输入 Tokens | 2,101,873 | 124,351 | 210,983 |
| 节省 Tokens | **131,789** | 568 | 138 |
| 压缩率 | **5.9%** | 0.5% | 0.1% |

**最佳压缩示例** (Request #135, OpenAI):

```
原始 Tokens:    105,992
优化后 Tokens:   98,942
节省 Tokens:      7,050
压缩率:           6.65%
总延迟:           5,976 ms
优化延迟:         6.7 ms
Transforms:
  - openai:responses:tool_schema_compaction
  - router:openai:responses:function_call_output:mixed
  - mixed
  - router:openai:responses:function_call_output:diff
  - diff
  - router:openai:responses:function_call_output:search
  - search
Cache Hit:        true
```

### 3.4 Codex WebSocket 实时压缩

| 指标 | 数值 |
|------|------|
| 处理 Units | 1,407 |
| 修改 Units | 126 (8.95%) |
| Passthrough | 791 (56.2%) — 太小不压 |
| 压缩器无操作 | 322 (22.9%) |
| 压缩后没变小 | 168 (11.9%) |
| 成功压缩 | 126 |
| Kompress 路径 | 124 units (8.81%) |
| 节省 Tokens | **132,703** |

**策略分布**:
- passthrough: 791
- mixed: 267
- text: 174
- kompress: 124
- log: 24
- diff: 14
- search: 13

---

## 四、Cache 效果分析

### 4.1 Provider 前缀缓存 (Anthropic/OpenAI 原生)

| 指标 | 数值 | 说明 |
|------|------|------|
| Cache Read Tokens | **6,988,798** | 从缓存读取的 tokens |
| Uncached Input Tokens | 161,725 | 未缓存的输入 tokens |
| 总请求数 | 123 | |
| Cache Hit 请求数 | 123 | **100% 请求命中** |
| Token 命中率 | **97.7%** | |
| 请求命中率 | **100.0%** | |
| 节省金额 | **$2.6152** | |
| Cache Bust 次数 | 0 | 压缩未破坏缓存 |

### 4.2 Headroom Proxy 缓存

| 指标 | 数值 |
|------|------|
| 条目数 | 0 |
| 最大条目 | 1,000 |
| 命中次数 | 0 |
| TTL | 3,600s |

**说明**: Proxy 层的缓存（结果缓存）当前没有命中。前缀缓存的收益全部来自 Provider 端（Anthropic cache_control / OpenAI 自动缓存）。

### 4.3 压缩 vs Cache 净收益

| 指标 | 数值 |
|------|------|
| 压缩节省 Tokens | 162,704 |
| Cache Bust 损失 Tokens | 0 |
| 净收益 Tokens | **162,704** |

**结论**: 当前压缩策略未对 Provider 前缀缓存造成负面影响（零 bust）。

---

## 五、根因分析

### 5.1 为什么 Claude 路径压缩率仅 0.7%？

**原因 1: Kompress 模型未下载**

```
HF Cache 路径:
  ~/.cache/huggingface/hub/models--chopratejas--kompress-base/
  └── snapshots/1c9123429e.../onnx/
      └── (空 — 模型文件未成功下载)
```

代码路径:
```
ContentRouter.apply()
  → KompressCompressor.compress()
    → _load_kompress()
      → hf_hub_download()  ← 网络阻塞 ~12s，然后失败
        → except Exception: logger.warning(...); return _passthrough()
```

Kompress 压缩器在模型不可用时**静默 fallback 到 passthrough**，不产生任何 token 节省。

**原因 2: Tool 消息被 ContentRouter 排除**

Claude Code 的请求中大量消息是 tool 调用结果。ContentRouter 的 `skip_user_messages=True` 和 tool 排除策略导致这些消息不被压缩。

最近请求的 transforms_applied 全部是 `router:excluded:tool`，说明：
- Tool 消息占总 token 的绝大部分
- 可压缩的文本内容比例很低

**原因 3: Code-Aware 压缩被硬编码关闭**

```python
# headroom/transforms/content_router.py:ContentRouterConfig
enable_code_aware: bool = False  # Disabled: use code graph MCP tools instead
```

即使请求中有代码块，AST 压缩器也不会被调用。

### 5.2 为什么 Codex 路径压缩率有 5.9%？

Codex 路径使用 OpenAI Responses API，其工具输出格式（JSON function_call_output）触发了以下策略：

1. **tool_schema_compaction**: OpenAI 工具 schema 精简
2. **mixed**: 混合内容拆分压缩
3. **diff**: diff 格式压缩
4. **search**: 搜索结果压缩

这些策略**不依赖 Kompress 模型**，是纯规则/启发式的，因此不受模型下载失败影响。

### 5.3 12 秒 Overhead 的来源

早期请求（proxy 刚启动时）的 overhead_ms 高达 **11,974ms**。来源：

- `_load_kompress()` 首次调用时尝试下载 148MB ONNX 模型
- `hf_hub_download()` 阻塞等待网络连接
- 约 12 秒后超时/失败，fallback 到 passthrough
- 后续请求的 overhead 降至 **170ms - 3,655ms**（取决于是否触发其他加载）

---

## 六、配置审计

### 6.1 用户配置 (`config.yaml`)

| 配置项 | 设定值 | 状态 |
|--------|--------|------|
| `mode` | `token` | ✅ 正确 |
| `code_aware` | `true` | ⚠️ proxy 层面开启，但 ContentRouter 内部关闭 |
| `code_graph` | `true` | ✅ 开启 |
| `cache` | `true` | ✅ 开启 |
| `memory` | `true` | ✅ 开启 |
| `telemetry` | `off` | ✅ 关闭 |
| `hf.endpoint` | `https://hf-mirror.com` | ⚠️ 308 redirect 到 huggingface.co 后连接失败 |

### 6.2 ContentRouter 内部默认值（不可通过 config.yaml 覆盖）

| 配置项 | 默认值 | 影响 |
|--------|--------|------|
| `enable_code_aware` | `False` | 代码块不被 AST 压缩(源码注释:`Disabled: use code graph MCP tools instead`) |
| `enable_kompress` | `True` | 但因模型缺失 fallback |
| `enable_smart_crusher` | `True` | JSON 数组可被压缩 |
| `enable_search_compressor` | `True` | 搜索结果压缩(`how-compression-works` 列在 7 Compressor 表里) |
| `enable_log_compressor` | `True` | 构建/测试日志压缩 |
| `enable_html_extractor` | `True` | HTML 提取后再压 |
| `enable_image_optimizer` | `True` | 图片 token 优化 |
| `skip_user_messages` | `True` | 用户消息不被压缩(它们是"分析对象"而非"压缩对象") |
| `protect_recent_code` | `4` | 最近 4 条消息的代码不被压缩(`protect_analysis_context=True` 时启用) |
| `protect_recent_reads_fraction` | `0.0` | 保护最近 N% 的 tool 输出。0.0 = 保护 ALL(最安全)。Claude 90% tool 不被压的**第二重保险** |
| `min_ratio_relaxed` | `0.85` | context 较空时:压到原始的 85% 为止(宽松) |
| `min_ratio_aggressive` | `0.65` | context 较满时:压到原始的 65% 为止(激进)。两者线性插值 |
| `compress_assistant_text_blocks` | `False` | **assistant 自己产出的 text 不被压缩**——这是 §4.1 零 cache bust 的**根因**(原样 echo 给上游作 prefix cache key) |
| `fallback_strategy` | `KOMPRESS` | Kompress 缺失时 passthrough |

#### 6.2.1 `DEFAULT_EXCLUDE_TOOLS` 真实值（Claude 90% tool 被排除的根因）

`headroom/config.py` 第 211-226 行的常量定义:

```python
DEFAULT_EXCLUDE_TOOLS: frozenset[str] = frozenset({
    "Read", "Glob", "Grep", "Write", "Edit", "Bash",
    # Lowercase variants
    "read", "glob", "grep", "write", "edit", "bash",
})
```

**关键洞察**:Claude Code 的核心工具集(Read/Glob/Grep/Write/Edit/Bash)**正好命中这 6 个 tool 名**(含大小写共 12 个)——所以报告里看到的"几乎所有消息都被标记为 `router:excluded:tool`"**不是 heuristic 判断**,是 `ContentRouter` 启动时**硬编码的默认白名单直接 reject**。

注意:`Bash` 虽然在排除列表中,但它的**输出**(build log / test output)是后续 LogCompressor 的理想压缩目标。排除的是 tool 调用本身(tool_use block),不是 tool 输出。

### 6.3 官方 docs 与源码冲突清单

报告数字 + 源码引用已经过 headroom 0.23.0 源码 100% 验证,但跟官方 docs(`/docs/installation`、`/docs/how-compression-works`、`/docs/proxy`、`/docs/configuration`)对照后,发现 2 处需要解释的"不一致":

| 项 | 官方 docs 说法 | 源码 0.23.0 实际 | 处理 |
|---|---|---|---|
| `HEADROOM_LOG_LEVEL` env | 存在,默认 `INFO`,在 `/docs/installation` page 列了 | `grep HEADROOM_LOG_LEVEL` 整个 0.23.0 包 **0 匹配** | 以 docs 为准——可能 docs 是 0.24+ 版本,本部署 0.23.0 没实现。**未来升级 0.24+ 时该 env 可能生效** |
| `HEADROOM_MODE` 默认值 | `optimize`,在 `/docs/installation` page 列了 | proxy 端实际跑 `token`(见 §2 Mode) | **不矛盾**——是**两套独立 mode**:proxy 端 `token`/`cache`(已抓 `/docs/configuration` 验证),SDK 端 `audit`/`optimize`/`simulate`(构造函数 `headroom_mode` 参数)。docs 没说清楚这俩的区别,容易误读 |

> 本节是 2026-06-06 docs + 源码交叉验证的诚实记录。**未来如果官方 docs 或源码版本变化,以新版本为准**。


---

## 七、分层节省效果

| 层级 | 节省 Tokens | 节省 USD | 说明 |
|------|------------|----------|------|
| **Proxy 压缩** | 162,704 | $0.0014 | Headroom 主动压缩 |
| **Prefix Cache** | 6,988,798 (read) | $2.6152 | Provider 原生缓存折扣 |
| **CLI Filtering** | 0 | — | RTK 未安装/未启用 |
| **总计** | — | **$2.6166** | |

---

## 八、性能指标

### 8.1 延迟分布

| 指标 | Claude (MiniMax-M3) | Codex (gpt-5.5) |
|------|---------------------|-----------------|
| 平均总延迟 | ~4.5s | ~6.0s |
| 最大总延迟 | **330.9s** (请求 #135) | — |
| 平均优化延迟 | ~400ms | ~7ms |
| 最大优化延迟 | 3,655ms | — |

### 8.2 历史累计（持久化存储）

| 指标 | 数值 |
|------|------|
| 历史总请求 | 171 |
| 历史总输入 Tokens | 11,129,062 |
| 历史总节省 Tokens | 334,859 |
| 历史总成本 | $0.1004 |
| 历史压缩节省 | $0.0014 |

---

## 九、问题清单与建议

### 🔴 P0: Kompress 模型下载失败

**问题**: 148MB ONNX 模型无法从 hf-mirror 下载（308 redirect → huggingface.co → 连接中断）。

**影响**: 
- Claude 路径纯文本内容无法被 ML 压缩
- 每次 proxy 重启后首次请求额外阻塞 ~12 秒

**建议**:
1. 手动下载模型到 HF Cache（需稳定网络）
2. 或设置 `HF_ENDPOINT=https://huggingface.co` 直接访问（需代理/VPN）
3. 或临时关闭 Kompress 避免阻塞：`HEADROOM_KOMPRESS_BACKEND=none`

### 🟡 P1: Claude Tool 消息占比过高

**问题**: Claude Code 请求中 90%+ tokens 是 tool 结果，ContentRouter 选择不压缩。

**建议**:
1. 检查 ContentRouter 的 tool 排除逻辑是否合理
2. 某些 tool 结果（如大文件读取、搜索返回）实际上可以安全压缩
3. 考虑启用 `HEADROOM_INTERCEPT_ENABLED=1`（tool result interceptors，实验性）

### 🟡 P2: Code-Aware 压缩被硬编码关闭

**问题**: `ContentRouterConfig.enable_code_aware = False` 不可通过配置覆盖。

**建议**:
1. 等待 Headroom 版本更新支持配置覆盖
2. 或手动 patch `content_router.py` 临时开启

### 🟢 P3: Prefix Cache 效果极佳，继续保持

**状态**: 97.7% token 命中率，100% 请求命中率，零 cache bust。

**建议**: 当前策略已是最优，无需调整。

---

## 十、结论

| 维度 | 评分 | 说明 |
|------|------|------|
| **Prefix Cache** | ⭐⭐⭐⭐⭐ | 97.7% 命中率，节省 $2.62 |
| **Codex 压缩** | ⭐⭐⭐⭐ | 5.9% 压缩率，策略有效 |
| **Claude 压缩** | ⭐ | 0.7% 压缩率，Kompress 模型缺失 + Tool 消息排除 |
| **网络基础设施** | ⭐ | HF 模型下载失败 |
| **整体 ROI** | ⭐⭐⭐ | 总节省 $2.62/会话，主要来自缓存 |

**下一步**: 修复 Kompress 模型下载后，Claude 路径压缩率有望提升至 3-8%（参考 Codex 路径）。

---

*报告由 `headroom-ctl` 诊断命令生成*  
*诊断时间: 2026-06-06 21:07 UTC*
