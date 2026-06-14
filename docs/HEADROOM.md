# Headroom 配置手册

> 适用版本:`headroom-ai 0.25.0`  |  面向中国大陆 + gotoken relay 用户的实战手册  |  最后更新:2026-06-14
>
> **2026-06-14 升级说明**:从 0.23.0 升级到 0.25.0(详见 §0.0)。`docs/headroom-diagnosis-report-2026-06-06.md` 是 0.23.0 时点证据,**不反映 0.25.0**。本节(§0.0)记录主要 API 变化与文档同步说明。

Headroom 是 LLM 调用的上下文压缩代理,装在你和真实 LLM 之间,自动把工具结果(日志/JSON/源码/搜索结果)压缩后再发给上游,从而省 token 省钱。

---

## 0.0 0.25.0 升级要点(2026-06-14 升级)

> 本节记录 0.23.0 → 0.25.0 的主要 API 变化。**完整 changelog 见** [GitHub Releases](https://github.com/chopratejas/headroom/releases/tag/v0.25.0)。本节只列与本手册现有内容相关的变化。

### 0.0.1 Kompress 默认 backend 切换(#799)

| | 0.23.0 | 0.25.0 |
|---|---|---|
| 模型名 | `chopratejas/kompress-base` | **`chopratejas/kompress-v2-base`** |
| 默认 ONNX | 单一 fp32(148MB) | **`onnx/kompress-int8-wo.onnx`(weight-only int8, 261MB)** |
| Fallback | 无 | `onnx/kompress-fp32.onnx`(601MB,lossless reference) → `onnx/kompress-int8.onnx`(v1-era) |
| 加载时序 | 首次请求触发,阻塞 ~12s | 同 0.23.0(但首次请求包含 int8/fp32 fallback 链) |

**对 Hermes 的影响**:
- `~/.cache/huggingface/hub/models--chopratejas--kompress-base/`(0.23.0 缓存)**作废**
- 第一次启会下载新模型(默认 int8-wo,261MB;如果 hf-mirror 仍 308-redirect 会 fallback 到 fp32 601MB)
- 之前的 `Kompress 模型 ~148MB ONNX` 描述全部需要更新(诊断报告 P0 bug 治不了根因,网络问题独立)

### 0.0.2 ContentRouterConfig 字段扩容(18 → 28)

0.25.0 新增 10 个字段。完整新字段列表见 §3.1.1,影响最大的几个:

| 新字段 | 默认 | 含义 | 来源 |
|---|---|---|---|
| `protect_error_outputs` | `True` | 保护 error 输出不被破坏(配套 `error_protection_max_chars=8000`) | #851 compression safety rails |
| `min_chars_for_block_compression` | `500` | gated Markdown-KV compaction formatter 阈值 | #859 |
| `exclude_tools` | `None`(用 `DEFAULT_EXCLUDE_TOOLS`) | 配置化排除(以前是硬编码常量) | — |
| `compress_tagged_content` | `False` | 标 `read_lifecycle + smart_crush` 标签的内容是否压 | #249 |
| `read_lifecycle` | `<factory>` | read_lifecycle 标签属性 | #249 |
| `tool_profiles` | `None` | per-tool 压缩配置 | #249 |
| `ccr_enabled` | **`True`**(0.23.0 是 `False`) | **CCR 默认开启** | #875 |
| `ccr_inject_marker` | **`True`**(0.23.0 是 `False`) | 默认注入 CCR retrieval markers | — |
| `smart_crusher_max_items_after_crush` | `None` | SmartCrusher 上限(0.23.0 无此字段) | #859 |
| `smart_crusher_with_compaction` | `True` | 配合 schema compaction | #859 |

**对 Hermes 的影响**:
- `ccr_enabled=True` 默认开启意味着**CCR marker 注入现在是默认行为**——之前 §3.1.1 的"prefix cache 0 bust 根因 = `compress_assistant_text_blocks=False`"的论述仍然成立(CCR marker 不改 assistant text),但 CCR 现在会主动把压缩内容做可逆标记
- `protect_error_outputs=True` 修了 §4.1 的"零 cache bust"假设下未覆盖的边界(error output 现在也保 prefix key)

### 0.0.3 多 Provider 内存架构(#824 Hermes agent plugin)

0.23.0 时期描述的"proxy 只 recall,不主动 add;memory 工具仅 SDK 暴露"在 0.25.0 已升级:

| Provider | 0.23.0 行为 | 0.25.0 行为 |
|---|---|---|
| **Anthropic** | proxy recall 注入 system msg | **Native `memory_20250818` 工具暴露给 LLM + recall 注入** |
| **OpenAI / Gemini / Others** | 不支持 | **Function calling 格式暴露** |
| **存储后端** | 单一 sqlite | **统一向量存储后端,多 provider 共享** |
| **DB 模式** | project 模式(cwd 决定) | project 模式 + 可用 `x-headroom-project-id` / `x-headroom-cwd` header 覆盖 |

**对 Hermes 的影响**:
- 0.23.0 时 §5.6.6 担心的"relay 不支持 `memory_20250818` → 400 错"现在**仍然适用于 relay**——gotoken 可能不识别 native tool
- 0.25.0 文档原话:"**Anthropic: Uses native memory tool (memory_20250818) - subscription safe**"——意思是 native tool 是订阅安全的,但前提是 LLM 能识别
- 建议:**保留 0.23.0 的"memory 默认开,但 relay 慎用"判断**;§5.6.6 风险段基本可沿用

### 0.0.4 路由扩展(#793 Vertex AI)

0.25.0 启动 banner 新增一条路由(0.23.0 没有):

```
/v1/projects/.../publishers/... → https://us-central1-aiplatform.googleapis.com
```

`x-headroom-project-id` + `x-headroom-location` header 触发 Vertex AI 路由。Hermes 当前不用 Vertex,本手册 §3.4 表加一行即可,其他不动。

### 0.0.5 /health 新增 upstream 检查(#744)

0.23.0 只有 startup / http_client / cache / rate_limiter / memory 5 个 check。0.25.0 增加:

```json
"upstream": {
  "enabled": true,
  "ready": true,
  "status": "healthy",
  "url": "https://api.gotoken.top",
  "error": null
}
```

**对 Hermes 的影响**:`headroom-ctl status` 输出的 "── 其它 env" 段需要新增 upstream 健康行。

### 0.0.6 其他保留不变的事实(2026-06-14 验证)

下面这些文档内容**0.23.0 → 0.25.0 验证未变**,无需改写:

| 事实 | 验证命令 |
|------|---------|
| `HEADROOM_LOG_LEVEL` env 在 0.25.0 仍不存在 | `grep HEADROOM_LOG_LEVEL ~/.local/share/uv/tools/headroom-ai/lib/python3.13/site-packages/headroom/ -r` 0 命中 |
| `memory_20250818` 工具名不变 | `grep NATIVE_MEMORY_TOOL_TYPE memory_tool_adapter.py` |
| `DEFAULT_EXCLUDE_TOOLS` 12 个工具名不变 | Python inspect `sorted(DEFAULT_EXCLUDE_TOOLS)` = `[Bash, Edit, Glob, Grep, Read, Write, bash, edit, glob, grep, read, write]` |
| `enable_code_aware=False` dataclass 默认不变 | `inspect.signature(ContentRouterConfig)` |
| `protect_recent_reads_fraction=0.0` 不变 | 同上 |
| `min_ratio_relaxed=0.85` / `min_ratio_aggressive=0.65` 不变 | 同上 |
| `compress_assistant_text_blocks=False` 不变 | 同上 |
| `HEADROOM_MODE` 取值 `token` / `cache`(及 5 个 legacy aliases)不变 | `headroom/proxy/modes.py` 源码 |

---

## 0. 一次性前置

```bash
# 安装(已装可跳)—— 必须带 [all] extra,否则缺 fastapi/uvicorn
uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai[all]"

# 创建配置目录
mkdir -p ~/.config/headroom ~/log/headroom ~/bin

# 确认
which headroom      # /home/stark/.local/bin/headroom
headroom --version  # headroom, version 0.23.0
```

### 0.1 环境变量角色速查(避免混用)

| 变量 | 谁用 | 给谁 | 说明 |
|---|---|---|---|
| `ANTHROPIC_BASE_URL` | **Claude Code client** | headroom proxy (8787) | Claude Code 启动时设,让请求进 proxy |
| `ANTHROPIC_AUTH_TOKEN` | **Claude Code client** | headroom proxy | Claude Code 启动时设,proxy 收到后**原样转发**给上游,值会带 `Bearer ` 前缀(官方: "Custom value for the `Authorization` header (the value you set here will be prefixed with `Bearer`)") |
| `ANTHROPIC_TARGET_API_URL` | **headroom proxy 自己** | 真 LLM API | proxy 启动时设,告诉 proxy 转发到哪(默认 `https://api.anthropic.com`) |
| `ANTHROPIC_API_KEY` | **Claude Code client** | 真 Anthropic API | 只有直连真 Anthropic(不走 proxy)时用 |
| `OPENAI_BASE_URL` | **Codex / Cursor / 任何 OpenAI 客户端** | headroom proxy (8787/v1) | 启动客户端时设 |
| `OPENAI_API_KEY` | **Codex / OpenAI 客户端** | headroom proxy → 上游 | 客户端发给 proxy,proxy 原样转给上游(用于 OpenAI 兼容) |
| `HEADROOM_MEMORY` | **headroom proxy 自己** | — | 启 `--memory` 时设 `1`,proxy 加载 embedder + 每次请求自动 recall(2026-06-06 默认开) |
| `HEADROOM_CODE_GRAPH` | **headroom proxy 自己** | — | 启 `--code-graph` 时设 `1`,索引整个 cwd + watch files(2026-06-06 默认开) |

> **链路**:`claude` → (`ANTHROPIC_BASE_URL`+`ANTHROPIC_AUTH_TOKEN`) → headroom proxy:8787 → (`ANTHROPIC_TARGET_API_URL`+从 client 拿到的 token) → gotoken.top → 模型
>
> 所以 gotoken relay 这种"Authorization: Bearer sk-..." 风格用的是 `ANTHROPIC_AUTH_TOKEN`;真 Anthropic API 用 `X-Api-Key` 风格的是 `ANTHROPIC_API_KEY`。**别混了**。

---

### 0.2 重要:代理模式**不需要** `headroom init` 也不需要 hook

> **官方来源**(2026-06-06 抓取验证):
> - [Quickstart](https://headroom-docs.vercel.app/docs/quickstart) — 0 处提到 hook, 0 处提到 `init`
> - [Installation](https://headroom-docs.vercel.app/docs/installation) — 0 处 hook, 0 处 init
> - [Proxy Server](https://headroom-docs.vercel.app/docs/proxy) — 0 处 hook, 0 处 init, 5 处 `wrap`
> - [Configuration](https://headroom-docs.vercel.app/docs/configuration) — 0 处 hook, 0 处 init
> - 推测的 `/docs/init`、`/docs/agents`、`/docs/cli` 三个页面 **404** / **不存在**

**官方 quickstart 的 4 步**(原文):
> 1. Install
> 2. Compress messages
> 3. Send to your LLM
> 4. Check your savings
> Alternative: proxy mode (zero code changes)

**`Alternative: proxy mode (zero code changes)` 章节原文**:
> ```bash
> # Start the proxy
> headroom proxy --port 8787
>
> # Point Claude Code at it
> ANTHROPIC_BASE_URL=http://localhost:8787 claude
> ```

**`/docs/configuration` 页面列出的所有 headroom 子命令**:
> ```
> headroom proxy --no-cache
> headroom proxy --llmlingua
> headroom proxy --no-optimize
> ...
> ```
>
> — **没有 `headroom init`**。

#### 结论

| 模式 | 是否需要 `headroom init` | 是否需要 hook | 官方文档支持 |
|---|---|---|---|
| **代理模式(本手册推荐)** | ❌ 不需要 | ❌ 不需要 | ✅ quickstart + proxy |
| `headroom wrap` | ❌ 不需要 | ❌ 不需要 | ✅ proxy 页面 `# OpenAI Codex  headroom wrap codex` |
| `headroom init` 懒启动 | ⚠️ headroom CLI 自带子命令 | ✅ 必须(改 settings.json) | ❌ 官方文档**不教**这个用法 |

**`headroom init claude/codex` 的真实用途**(从 headroom 0.23 CLI 源码):

- 它会**改** `~/.claude/settings.json` 或 `~/.codex/config.toml`,注入 `SessionStart` / `PreToolUse` hook
- hook 触发时调用 `headroom init hook ensure --profile <name>`
- 这个 ensure 命令检查 proxy 在不在跑,**不在就** `start_detached_agent` 拉起

也就是说 `init` 是给"**懒启动守护**"用的:
- 你不想 `nohup` 也不想写 systemd,只想"开 claude 时 proxy 自动起"
- 代价是改你的 settings.json,加一堆 hook 命令,uv tool 装位置变就失效

**官方 quickstart 的姿势就是不用 init**:
```bash
# 一次性起 proxy(后台)
nohup headroom proxy --port 8787 > ~/log/headroom/proxy.log 2>&1 &

# 每次用就设 env var(不污染全局)
ANTHROPIC_BASE_URL=http://localhost:8787 claude
OPENAI_BASE_URL=http://localhost:8787/v1 codex
```

**本手册全程不推荐 `headroom init`**。要常驻就用 nohup(本手册的 `headroom-up` 脚本)或上 systemd(`headroom install apply` 走 managed deploy)。

---

### 0.3 Proxy 模式开关:`HEADROOM_MODE`

> **2026-06-06 补**:之前漏写——`HEADROOM_MODE` 是 headroom proxy **唯一**控制"压缩策略"的环境变量。

#### 0.3.1 真实取值(从 `headroom/proxy/modes.py` 源码 + `headroom proxy --help` 抓取)

| 值 | 行为 | 适合场景 | 默认? |
|---|---|---|---|
| **`token`** | 优先压缩:历史 turn 可被重写以最大化省 token | 省钱优先,不在意 prefix cache | ✅ **默认** |
| **`cache`** | 冻结历史 turn 以最大化 provider prefix cache 命中率 | 速度优先,Anthropic 1h cache 用得满时 | ❌ |

**Legacy aliases**(还能用,但建议改新名):

| Alias | 等价于 |
|---|---|
| `token_mode` | `token` |
| `token_savings` | `token` |
| `token_headroom` | `token` |
| `cache_mode` | `cache` |
| `cost_savings` | `cache` |

> 任何未知值会触发 warning 并 fallback 到 `token`(见 `modes.py:normalize_proxy_mode`)。

#### 0.3.2 用法

```bash
# 方式 1:env(推荐,放进 ~/.config/headroom/proxy.env)
export HEADROOM_MODE=token       # 或 cache

# 方式 2:CLI 标志(等价)
headroom proxy --mode cache --port 8787

# 方式 3:完全 passthrough(不走任何优化)
headroom proxy --no-optimize --port 8787
# 注意:--no-optimize 跟 HEADROOM_MODE 是两回事,优先级更高
```

#### 0.3.3 跟 SDK 的 `default_mode` 不是一回事

> ⚠️ **容易混淆的两套 mode**(2026-06-06 抓 `/docs/configuration` 页确认)

| 名字 | 在哪用 | 取值 | 来源 |
|---|---|---|---|
| **`HEADROOM_MODE` env** | `headroom proxy` 启动时 | `token` / `cache` | proxy CLI `--mode` |
| **`default_mode` 参数** | `HeadroomClient(...)`(Python/TS SDK) | `audit` / `optimize` / `simulate` | SDK 构造函数 |
| **`headroom_mode` 参数** | `headroom_ai.acreate(...)` 单次请求 | `audit` / `optimize` / `simulate` | SDK 单次覆盖 |

> 你看到的"audit / optimize / simulate"是 **SDK 表格** 里的,跟 proxy 没关系。本手册**只用 proxy**,所以只需关心 `token` / `cache`。
>
> 如果你想"audit 模式但走 proxy"——目前 0.23.0 **没有** proxy 端的 audit 开关,只能 SDK 内用。proxy 端"无修改"= `--no-optimize` = 完全 passthrough(没 stats、没节省)。

#### 0.3.4 当前部署状态

| 项 | 值 |
|---|---|
| `HEADROOM_MODE` 是否在 proxy env | ❌ **未设**(走默认 `token`) |
| proxy `/health.config.mode` 字段 | proxy `/health` 不返回 mode 字段(只有 optimize/cache/code_graph/memory/learn) |
| proxy `/stats` 里有 mode? | `summary.mode="token"` 字段存在 |

**如何确认当前 mode 在跑什么**:
```bash
curl -sS http://127.0.0.1:8787/stats | python3 -c "import json,sys; print(json.load(sys.stdin)['summary']['mode'])"
# 期望: token (默认) / cache (设了之后)
```

#### 0.3.5 选哪个?决策表

| 你最在意 | 选 | 理由 |
|---|---|---|
| 省钱省 token | `token`(默认) | 历史 turn 可重写,压缩更狠 |
| 速度 / 命中率 | `cache` | 冻结 prefix,Anthropic 1h cache 命中多 |
| 想看效果先别压 | `cache` | 至少历史不变,方便对比 baseline |
| relay(gotoken)/中转 | `token` | relay 通常不兑现 prefix cache,选 token 划算 |

#### 0.3.6 相关:Log 配置(常被一并问)

> **澄清**:`HEADROOM_LOG_LEVEL` 这个 env var **在 headroom 0.25.0 仍然不存在**(2026-06-14 `grep` 整个 0.25.0 已装包 0 匹配,跨版本验证无变化)。

> ⚠️ **docs/源码差异(2026-06-06 标记,2026-06-14 复验)**:`/docs/installation` page 明确列了 `HEADROOM_LOG_LEVEL` env(默认 `INFO`)——**跟源码对不上**。**至少到 0.25.0 该 env 仍未实现**,page 描述可能是规划中或文档先行。**未来版本如果加上,本节需要更新**。

proxy 真正的 log 配置:

| 方式 | 作用 | 来源 |
|---|---|---|
| `--log-file PATH` | 把 JSONL 日志写到指定文件 | `headroom proxy --help` |
| `--log-messages` | 启用完整 request/response 内容记录(默认**关**,会写明文到 log) | `headroom proxy --help` |
| `HEADROOM_TELEMETRY=off` | 关匿名统计(不是 log level) | `--no-telemetry` 等价 |
| `level=logging.INFO` | Python stdlib logger 硬编码在 `server.py`,**不可改** | 源码 |

想降 log 详细度:目前 0.23.0 没法,只能 redirect 到 `/dev/null` 或用 `grep` 过滤。

---

---

## 1. 完全关闭 headroom

```bash
# 1. 停 proxy
pkill -f "headroom proxy" || true

# 2. 验证端口空
ss -tlnp 2>/dev/null | grep 8787 || echo "8787 端口已空"

# 3. 启动 claude 时**不要**设 ANTHROPIC_BASE_URL
claude   # 自动走 ~/.claude/settings.json 里的 https://api.gotoken.top
```

**效果**:跟没装 headroom 一模一样,零开销。

---

## 2. 最小开启(passthrough 代理)

只做透明管道,无压缩无缓存,适合验证链路或日后逐步加能力。

```bash
HF_HUB_DISABLE_XET=1 \
HF_ENDPOINT=https://hf-mirror.com \
ANTHROPIC_TARGET_API_URL=https://api.gotoken.top \
ANTHROPIC_AUTH_TOKEN=sk-... \
HEADROOM_TELEMETRY=off \
nohup headroom proxy --port 8787 > ~/log/headroom/proxy.log 2>&1 &

# 用
ANTHROPIC_BASE_URL=http://localhost:8787 claude
```

---

## 3. 完整配置(推荐)— **2026-06-06 改用 config.yaml**

> **重要变更**:旧的 `~/.config/headroom/proxy.env` + 3 个独立 shell 脚本(`headroom-up` / `-down` / `-status`)已被**单文件统一方案替代**:
>
> - `~/.config/headroom/config.yaml` —— **唯一真相源**,所有配置
> - `~/bin/headroom-ctl` —— **单文件管理脚本**,6 个子命令
>
> 详见运维手册 `HEADROOM-OPS.md` §1.1 / §1.2 / §2 / §3 / `apply`。本节只放 schema 速查。

### 3.1 配置文件 `~/.config/headroom/config.yaml`

```yaml
# ==============================================================================
# Headroom 统一配置(唯一真相源)
# ==============================================================================
proxy:
  port: 8787
  log: /tmp/headroom.log
  pidfile: ~/.headroom/headroom.pid

  # 4 个独立后端 URL + token(从源码 proxy/server.py 验证)
  upstreams:
    anthropic:
      url: https://api.minimaxi.com/anthropic          # 你的实际 upstream
      token: sk-cp-xxxx...
    openai:
      url: https://api.codexzh.com/v1
      token: sk-xxxx...
    # gemini:    { url: ..., token: ... }   # 注释掉就不启用
    # cloudcode: { url: ..., token: ... }

  # 特性开关
  features:
    code_aware: true        # → HEADROOM_CODE_AWARE_ENABLED=1(AST 压缩,纯本地,2026-06-06 起默认开)
    # 2026-06-06:code_graph 默认开(用户原话"启动脚本默认要开启 code_graph")。
    # code_graph = 代码图谱 intelligence(不同于 code_aware):
    #   - 索引整个 cwd + watch files(持续 I/O)
    #   - 跟 codebase-memory-mcp 通信
    #   - 官方要求从项目根启 proxy(本部署 cwd=/data/hermes 满足)
    # 想关: HEADROOM_CODE_GRAPH=0 headroom-ctl start(临时) 或 features.code_graph: false(持久)
    code_graph: true        # → HEADROOM_CODE_GRAPH=1
    # 2026-06-06:memory 默认开。DB 暂时是空的,启 --memory 后:
    #   - 每次请求自动 recall(DB 空时零开销,返回 [])
    #   - 加载 embedder 模型(~50MB 内存,~1-2s 启动延迟)
    #   - 不会主动 add(只能 SDK 工具或 CLI 触发)
    # 想关: HEADROOM_MEMORY=0 headroom-ctl start(临时) 或 features.memory: false(持久)
    # 详细: §5.6 三写一读 + 调用时机
    memory: true             # → HEADROOM_MEMORY=1
    learn_proxy: false
    mode: token             # token | cache,详见 §0.3
    telemetry: "off"        # 显式字符串,避免 YAML 1.1 off→false 陷阱

  # HF 模型下载(中国网络必须)
  hf:
    disable_xet: true
    endpoint: https://hf-mirror.com

# 客户端配置(headroom-ctl apply 会同步到对应文件)
claude_code:
  enabled: true
  base_url: http://127.0.0.1:8787
  model: MiniMax-M3[1M]
  settings_file: ~/.claude/settings.json

codex:
  enabled: true
  model_provider: headroom   # 对应 [model_providers.headroom]
  config_file: ~/.codex/config.toml
  auth_file: ~/.codex/auth.json
  providers:
    headroom:
      name: Headroom Local
      base_url: http://127.0.0.1:8787/v1
      wire_api: responses
      requires_openai_auth: true

paths:
  home: ~/.headroom
  memory_db: /data/hermes/headroom_memory.db
  hf_cache: ~/.cache/huggingface
```

#### 3.1.1 ContentRouter 完整 Config 字段表(供查阅)

> **来源**:对照 headroom 0.25.0 源码 `transforms/content_router.py` 的 `ContentRouterConfig` 数据类 + `config.py` 的 `DEFAULT_EXCLUDE_TOOLS`(2026-06-14 `inspect.signature()` 实测)。**多数字段在 proxy 0.25.0 启动时硬编码,不可通过 `config.yaml` 覆盖**——本表供查阅"为什么某些行为是默认的"。
>
> **字段数量变化**:**0.23.0 是 18 个字段,0.25.0 扩到 28 个**(新增 10 个,主要是 CCR 默认开关、error output 保护、gated compaction 阈值、tool profiles)。
>
> **0.23.0 → 0.25.0 默认值变化**:
> - `ccr_enabled`: `False` → **`True`**(#875 shared compression store)
> - `ccr_inject_marker`: `False` → **`True`**

| Config 字段 | 类型 | 默认值 | 含义 | 源 |
|---|---|---|---|---|
| `enable_code_aware` | `bool` | **`False`** | AST 压缩开关。源码注释:`Disabled: use code graph MCP tools instead` | `content_router.py:439` |
| `enable_kompress` | `bool` | `True` | Kompress(ModernBERT 文本压缩)。模型缺失时静默 fallback passthrough | `content_router.py:441` |
| `enable_smart_crusher` | `bool` | `True` | JSON 数组压缩 | `content_router.py:442` |
| `enable_search_compressor` | `bool` | `True` | 搜索结果压缩 | `content_router.py:443` |
| `enable_log_compressor` | `bool` | `True` | 构建/测试日志压缩 | `content_router.py:444` |
| `enable_html_extractor` | `bool` | `True` | HTML 提取后再压 | `content_router.py:445` |
| `enable_image_optimizer` | `bool` | `True` | 图片 token 优化 | `content_router.py:446` |
| `prefer_code_aware_for_code` | `bool` | `False` | 代码内容用 CodeAware 优先于 Kompress。注释:`Disabled: let code pass through unmangled` | `content_router.py:450` |
| `mixed_content_threshold` | `int` | `2` | 多少种类型算"混合" | `content_router.py:453` |
| `min_section_tokens` | `int` | `20` | 多少 token 以上才参与压缩 | `content_router.py:454` |
| `fallback_strategy` | `CompressionStrategy` | `KOMPRESS` | 无 Compressor 匹配时的兜底策略 | `content_router.py:460` |
| `skip_user_messages` | `bool` | `True` | 用户消息不参与压缩(它们是"分析对象") | `content_router.py:463` |
| `protect_recent_code` | `int` | `4` | 最近 4 条消息的代码不参与压缩(0 = 禁用) | `content_router.py:485` |
| `protect_recent_reads_fraction` | `float` | **`0.0`** | 保护最近 N% tool 输出。`0.0` = 保护 ALL(最安全)。Claude 90% tool 不被压的**第二重保险** | `content_router.py:478` |
| `protect_analysis_context` | `bool` | `True` | 检测 "analyze/review" 意图,保护代码 | `content_router.py:486` |
| `min_ratio_relaxed` | `float` | `0.85` | context 较空时,最多压到原始的 85%(宽松) | `content_router.py:493` |
| `min_ratio_aggressive` | `float` | `0.65` | context 较满时,最多压到原始的 65%(激进)。两者线性插值 | `content_router.py:494` |
| `compress_assistant_text_blocks` | `bool` | **`False`** | assistant 自己产出的 text **不压缩**——这是 prefix cache 0 bust 的**根因**(assistant text 是 cache key,改了会 bust) | `content_router.py:471` |

**0.25.0 新增字段**(本节以上未列):

| Config 字段 | 类型 | 默认值 | 含义 | 来源 |
|---|---|---|---|---|
| `protect_error_outputs` | `bool` | **`True`** | 保护 error 输出不被破坏(配套 `error_protection_max_chars`) | #851 compression safety rails |
| `error_protection_max_chars` | `int` | `8000` | error output 字符数超过此值才截断 | #851 |
| `min_chars_for_block_compression` | `int` | `500` | gated Markdown-KV compaction formatter 阈值 | #859 |
| `exclude_tools` | `frozenset\|None` | `None`(用 `DEFAULT_EXCLUDE_TOOLS`) | 配置化排除(以前只能改硬编码常量) | — |
| `compress_tagged_content` | `bool` | `False` | 标了 `read_lifecycle + smart_crush` 标签的内容是否压缩 | #249 |
| `read_lifecycle` | `ReadLifecycleConfig` | `<factory>` | read_lifecycle 标签属性(子类) | #249 |
| `tool_profiles` | `dict\|None` | `None` | per-tool 压缩配置(可精细调单个 tool) | #249 |
| `ccr_enabled` | `bool` | **`True`**(0.23.0 是 `False`) | **CCR marker 注入默认开启** | #875 shared compression store |
| `ccr_inject_marker` | `bool` | **`True`**(0.23.0 是 `False`) | 压缩内容带 retrieval marker(LLM 看到 marker 可调 `headroom_retrieve` 召原文) | — |
| `smart_crusher_max_items_after_crush` | `int\|None` | `None` | SmartCrusher 上限(0.23.0 无此字段) | #859 |
| `smart_crusher_with_compaction` | `bool` | `True` | SmartCrusher 配合 schema compaction | #859 |

**额外常量**(`config.py` 在 0.25.0 仍然存在):
`DEFAULT_EXCLUDE_TOOLS: frozenset[str] = frozenset({"Read", "Glob", "Grep", "Write", "Edit", "Bash", "read", "glob", "grep", "write", "edit", "bash"})`(2026-06-14 `sorted(DEFAULT_EXCLUDE_TOOLS)` 验证仍 12 个,跨版本无变化)。**Claude Code 核心工具集正好命中 6 个**——所以 Claude 路径 90%+ 消息被排除不是 heuristic,是默认白名单直接 reject。

> **0.25.0 行为差异提示**:`ccr_enabled=True` + `compress_assistant_text_blocks=False` 的组合意味着:assistant text 仍 100% 保留作 prefix cache key;但**其他被压缩的内容**(tool result 等)**会带 CCR retrieval marker**——LLM 理论上可以通过 `headroom_retrieve` 工具召原文,但目前 proxy 模式不暴露该工具给 LLM(0.23.0 起一直如此)。

> 完整 Compressor 列表 + Pipeline 3 阶段 + 4 个 Python 配置字段(`compression_ratio_target` / `use_entropy_preservation` / `use_magika` / `ccr_enabled`)见 [`/docs/how-compression-works`](https://headroom-docs.vercel.app/docs/how-compression-works)。

> **📌 报告 P2 误诊修正(2026-06-06 21:48 UTC 首次修正;2026-06-14 0.25.0 升级后二次修正)**
>
> `docs/headroom-diagnosis-report-2026-06-06.md` §6.2 / §9 P2 写 "`enable_code_aware: bool = False` 硬编码,不可通过配置覆盖,建议手动 patch"。**这个诊断是错的**——只看到了 `content_router.py:439` 的 dataclass 默认值,没追到完整数据流。
>
> **完整数据流**(2026-06-06 21:48 重新 grep 源码 + /stats 实测;2026-06-14 升级 0.25.0 后**行号变了**但**数据流不变**):
>
> ```
> server.py:~3570   env_code_aware = _get_env_bool("HEADROOM_CODE_AWARE_ENABLED", True)  ← env 入口,默认 True
> server.py:~372    enable_code_aware=config.code_aware_enabled                              ← 透传到 ContentRouter
> content_router.py:1245  if self.config.enable_code_aware:                                  ← 真的会用
> ```
>
> `config.code_aware_enabled` 是从 `config.yaml` 的 `code_aware: true` 解析的,所以 `enable_code_aware` 实际**可调**。
>
> **运行时佐证**(升级前 PID=637240,升级后 PID=1458870 跨版本验证):
>
> - proxy banner:`Code-Aware: ENABLED (AST-based)`
> - `/stats`:`compressions_by_strategy.code_aware` 有命中
>
> **2026-06-14 0.25.0 二次修正**:
> - **0.25.0 把 `tree_sitter_language_pack` 收成默认依赖**(uv tool upgrade 后自动安装 v1.8.1)。**之前 §1.7 的"`uv pip install ... [code]`" workaround 不再需要**
> - `tree_sitter` 0.25.0 修了 pyo3 Unsendable panic (#604,thread-local parsers),0.23.0 隐藏的崩溃隐患消失
> - 所以"双层开关"问题在 0.25.0 完全消失:**proxy 层开 + compressor 层静默失败的组合不存在了**
>
> **结论**:`enable_code_aware` 是**可配置的**(0.23.0 + 0.25.0 一致),原报告 P2 是 0.23.0 时代误诊。0.25.0 后连"silent fallback"都不存在了。报告原文保留作为 0.23.0 时点证据,本注是给后续读者对账用。
> 详细 plan:`~/.claude/plans/headroom-runtime-fix-2026-06-06.md` §3。

### 3.2 管理脚本 `~/bin/headroom-ctl`

16 个子命令(覆盖 start/wait/stop/restart/status/doctor/warmup-kompress/show-config-hints/config-show/config-edit/apply/learn/memory/agent-savings/perf/capture/evals/install):

```bash
# === 改上游/换 token/开关特性 → 改 yaml + 同步 ===
headroom-ctl config-edit   # $EDITOR 打开 yaml
headroom-ctl apply         # 同步到 settings.json / config.toml / auth.json(自动备份)
headroom-ctl restart       # 重启 proxy 让 yaml 生效

# === 看状态 ===
headroom-ctl status                # 详细状态表
headroom-ctl config-show           # 打印 yaml 当前值(脱敏)
headroom-ctl show-config-hints     # claude/codex 接入提示

# === 临时覆盖(不走 yaml) ===
HEADROOM_MODE=cache headroom-ctl restart   # 单次启 cache 模式

# === 离线工具(透传 headroom 子命令) ===
headroom-ctl learn [--apply] [--project <path>]   # 离线失败学习(见 §1.8)
headroom-ctl memory stats|list|search|add|remove  # 长程记忆 CRUD(见 §5.3)
headroom-ctl agent-savings [--check-perf]        # 渲染/验证 token-savings profile
headroom-ctl perf [--hours 24] [--format json]   # proxy 性能分析(从 log)
headroom-ctl capture network-diff <a> <b>        # 网络流量对比(MITM/diff)
headroom-ctl evals memory|memory-v2|probes       # memory 评估(LoCoMo benchmark)
headroom-ctl install apply|status|restart|stop|remove   # 持久化 deployment 管理
```

> **关键设计决定**:`learn` / `memory` **不**进 `config.yaml`——它们是**命令式数据操作**(非幂等:add 加新行、learn 重写文件),不是**声明式启动参数**。config.yaml 只装"启 proxy 时要什么状态",不装"每次重启要执行的副作用"。

**为什么单文件 vs 旧的 3 个脚本**:
| 维度 | 旧 (proxy.env + 3 脚本) | 新 (yaml + headroom-ctl) |
|---|---|---|
| 改一处影响几处 | 1 | 1 |
| client 配置(Claude/Codex)同步 | 手动 | `apply` 自动 |
| 配置文件数量 | 4 | 1 |
| 备份机制 | 无 | `.bak.时间戳` |
| Token 脱敏 | 手动 | `config-show` 自动 |

**配置来源优先级**(新方案下):
1. `~/.config/headroom/config.yaml` ← **唯一真相源**
2. shell 环境变量(`HEADROOM_MODE=cache headroom-ctl restart` 一次性)
3. 脚本内置默认

> 旧的 `proxy.env` 已被删除。脚本里保留 `CONFIG_FILE` 路径仅为文档目的,不再 source。

### 3.3 临时单次覆盖(高级用法)

```bash
# 不改 yaml,临时换 mode
HEADROOM_MODE=cache headroom-ctl restart

# 临时换上游(测试)
ANTHROPIC_TARGET_API_URL=https://api.anthropic.com \
ANTHROPIC_AUTH_TOKEN=sk-ant-test... \
  headroom-ctl restart

# 临时关 code_aware
HEADROOM_CODE_AWARE_ENABLED=0 headroom-ctl restart
```

### 3.4 看 4 个独立后端 URL(`HEADROOM-OPS.md` §1.10 有完整说明)

| 后端 | 请求路径 | env 变量 | 当前部署 |
|---|---|---|---|
| Anthropic | `/v1/messages` | `ANTHROPIC_TARGET_API_URL` | ✅ 设了 |
| OpenAI | `/v1/responses`, `/v1/chat/completions` | `OPENAI_TARGET_API_URL` | ✅ 设了 |
| Gemini | (OpenAI 兼容) | `GEMINI_TARGET_API_URL` | ❌ 未设 |
| Cloud Code | `/v1internal:streamGenerateContent` | `CLOUDCODE_TARGET_API_URL` | ❌ 未设 |

**关键**:Claude Code 和 Codex 可以**同时**走同一个 8787 端口,proxy 按请求路径路由。

### 3.5 两套压缩机制:消息级 vs 流级(机制视角)

> **2026-06-06 补**:`docs/headroom-diagnosis-report-2026-06-06.md §3.0` 的"诊断视角"提了 Claude(消息级 0.7%) vs Codex(流级 5.9%) 的数字差。本节从**机制视角**讲清这两套栈。

| 维度 | **消息级** (`ContentRouter.apply()`) | **流级** (`compression_units`) |
|---|---|---|
| **作用对象** | 每条 message/tool_result 整体 | Provider 请求 envelope 里的 "可压缩 text 范围" |
| **典型路径** | Claude 路径 `/v1/messages` | Codex WebSocket 路径 `/v1/responses` |
| **调度入口** | `ContentRouter.apply()`(`headroom/transforms/content_router.py`) | `headroom/transforms/compression_units.py` |
| **Compressor 数量** | 7 个(见 §3.1.1 + [`/docs/how-compression-works`](https://headroom-docs.vercel.app/docs/how-compression-works)) | OpenAI Responses-specific 策略(`function_call_output:mixed/diff/search`) |
| **依赖 Kompress 模型** | 是(模型缺失时静默 fallback passthrough) | 否(纯规则/启发式) |
| **排除规则** | `DEFAULT_EXCLUDE_TOOLS` + `skip_user_messages` | 单元级安全检查(provider adapter 决定) |
| **Pipeline 阶段** | `ContentRouter`(第 2 阶段) | (流级压缩,不走 ContentRouter) |

**Pipeline 3 阶段**(`/docs/how-compression-works`):
```
CacheAligner → ContentRouter → IntelligentContext
   稳定 prefix     路由到 Compressor     按 importance 评分
```

`★ Insight ─────────────────────────────────────`
- **消息级 + 流级是两套完全独立的栈**:同样的 `headroom` proxy,Claude 路径走 `ContentRouter`,Codex WebSocket 走 `compression_units`——**压缩器不重叠,排除规则不重叠,失败模式不重叠**
- **这解释了"为什么 Claude 压缩率比 Codex 低"**:不是因为 Claude 路径更复杂,是因为 `DEFAULT_EXCLUDE_TOOLS` 默认排除 6 个工具 + Claude Code 工具集**正好命中这 6 个**
- **`compression_units` 绕开了 Kompress 模型缺失问题**:它用 OpenAI Responses API 特定的启发式(`function_call_output:mixed/diff/search`),所以即使 Kompress 模型没下,Codex 路径还是能压
`─────────────────────────────────────────────────`

**对照诊断报告**:`docs/headroom-diagnosis-report-2026-06-06.md §3.0` 有完整的诊断视角(Claude vs Codex 数字对比)。

---

## 4. 选择性配置(4 个独立开关)

### 4.1a CCR Store / `headroom_retrieve` / Magika(2026-06-06 补)

> 本节内容对照官方 [`/docs`](https://headroom-docs.vercel.app/docs) 首页 + [`/docs/how-compression-works`](https://headroom-docs.vercel.app/docs/how-compression-works) 验证。这些是 headroom **内容压缩子系统**的核心概念,但官方 docs 没放在 `/docs/proxy` 也不在 `/docs/configuration`——只在 SDK 模式文档里讲。

| 概念 | 来源(2026-06-06 抓取) | 作用 |
|---|---|---|
| **CCR Store** (Content Cache & Routing Store) | `/docs` 首页 "CCR Store" 段 + `/docs/how-compression-works` `ccr_enabled=True` | headroom 自带的**结果级缓存层**,有别于 Provider 前缀缓存 |
| **`headroom_retrieve` 工具** | `/docs` 首页 + `/docs/how-compression-works` | SDK 工具函数,允许 LLM **显式取回被压缩的原文**——压缩 + 召还是无损 |
| **Magika** (Google 开源) | `/docs/how-compression-works` `use_magika: True` | Google 开源的**内容类型检测 ML**,CCR Store 用它做**内容路由**(决定走哪个 Compressor) |

**两层缓存 vs LLM 取回**:

| 层级 | 缓存什么 | 命中条件 | 失效 | 典型命中场景 |
|---|---|---|---|---|
| **CCR Store** (headroom 端) | 压缩后的 result,按 query 哈希 | 相同 query + 相同 router 决策 | TTL + LRU | 重复 query(固定 prompt + 不同 user input) |
| **Provider 前缀缓存** (upstream 端) | 上游收到的完整 prompt prefix | prefix bytes 完全一致 | 任一 byte 变 | 长对话 + 累积 message(Claude/Anthropic `cache_control` 等) |
| **`headroom_retrieve` 召原文** | LLM 工具调用 | 显式调 | tool 上下文 | LLM 觉得需要原文时主动召 |

**Pipeline 3 阶段中的 CCR 角色**(`/docs/how-compression-works`):

```
CacheAligner → ContentRouter → IntelligentContext
   稳定 prefix     路由到 Compressor     按 importance 评分
   ↑                 ↑                     ↑
 CCR Store 缓存      Magika 决定路由         决定哪些不压
(等同"内容路由表")  (Google 内容检测 ML)   (低 importance 丢)
```

**proxy 模式 vs SDK 模式**:
- **proxy 模式**(`headroom proxy`):CCR Store 走结果缓存(§3.1.1 里的 `cache` Config),`headroom_retrieve` 工具**不暴露**给 LLM(LLM 不知道有这个工具)
- **SDK 模式**(`HeadroomClient(... ccr_enabled=True)`):CCR Store + `headroom_retrieve` 都可用,LLM 通过 SDK 工具调用主动取回

> 诊断报告 `docs/headroom-diagnosis-report-2026-06-06.md §4.2.1` 有 CCR Store 的本机实测(0 命中,因为本部署工作流不重复 query)。

| 能力 | CLI 标志 | 环境变量 | 默认 | 何时开 |
|---|---|---|---|---|
| **Optimize 压缩** | `--optimize` / `--no-optimize` | — | ✅ on | 始终开(无副作用) |
| **Cache 语义缓存** | `--cache` / `--no-cache` | — | ✅ on | 重复 query 多时省得多 |
| **Rate Limit** | `--rate-limit` / `--no-rate-limit` | — | ✅ on | 防意外刷爆 token |
| **Memory 长程记忆** | `--memory` | `HEADROOM_MEMORY=on` | ❌ off | 跨 session 复用 facts |
| **Code-Aware** | `--code-aware` | `HEADROOM_CODE_AWARE_ENABLED=1` | ❌ off | 工具结果多源码/JSON/日志 |
| **Code-Graph(代码图谱)** | `--code-graph` | — | ❌ off | 索引整个 cwd + watch files,需从项目根启 + `codebase-memory-mcp` 装上(2026-06-06 默认开) |
| **Telemetry** | `--no-telemetry` | `HEADROOM_TELEMETRY=off` | ✅ on | 介意匿名统计就关 |
| **Learn** | `--learn` | — | ❌ off | 让 headroom 从失败学习(实验性) |
| **Subscription 跟踪** | `--no-subscription-tracking` | — | ✅ on | relay 模式关掉 |

**最小/完整/最大 三档**示例:

```bash
# 最小:只 passthrough
headroom proxy --port 8787 --no-optimize --no-cache --no-rate-limit

# 平衡:压缩+缓存+限速(默认)
headroom proxy --port 8787

# 最大:全开
headroom proxy --port 8787 --memory --code-aware --learn --no-subscription-tracking --no-telemetry
```

---

## 5. 使用

### 5.1 代理模式(零代码修改,推荐)

```bash
# 启 proxy(2026-06-06 起统一用 headroom-ctl)
~/bin/headroom-ctl start   # 或 `headroom-ctl start`(已 PATH)

# 跑 claude(每次启动时设 ANTHROPIC_BASE_URL,**不污染**全局 settings.json)
ANTHROPIC_BASE_URL=http://localhost:8787 claude

# OpenAI 兼容客户端
OPENAI_BASE_URL=http://localhost:8787/v1 your-app
```

> 想让 client 端**默认**走 headroom(不每次都设 env)?改 `config.yaml` 后跑 `headroom-ctl apply`,见 §3.1 / `HEADROOM-OPS.md` §1.10。

### 5.2 验证省钱效果

```bash
# 一句话
curl -sS http://localhost:8787/stats | python3 -c "
import json, sys
d = json.load(sys.stdin)['summary']
r = d['requests']; t = d['tokens']; c = d['cost']
print(f'requests: {r[\"total\"]}  failed: {r[\"failed\"]}')
print(f'tokens:   {t[\"input\"]:,} in  +  {t[\"output\"]:,} out')
print(f'saved:    {t[\"saved\"]:,} tokens ({t[\"savings_percent\"]:.1f}%)')
print(f'cost:     \${c[\"without_headroom_usd\"]:.4f} → \${c[\"with_headroom_usd\"]:.4f}  (saved \${c[\"total_saved_usd\"]:.4f}, {c[\"savings_pct\"]:.1f}%)')
"

# Prometheus 指标(给 Grafana)
curl -sS http://localhost:8787/metrics
```

### 5.3 CLI 手动管 memory

```bash
# 加记忆
headroom memory add --content "用户偏好中文回复" --category preference
headroom memory add --content "Hermes 项目用 Sprint 编号管理节奏" --category project

# 查
headroom memory list
headroom memory search "中文"
headroom memory stats

# 删
headroom memory remove <id>
```

> **2026-06-06 包装**:`headroom-ctl memory <sub> [...]` 透传上面所有子命令(如 `headroom-ctl memory stats`)。不依赖 proxy 进程在跑,但需要 proxy 启时带 `--memory` 才有数据。
> ```bash
> headroom-ctl memory stats              # 摘要
> headroom-ctl memory list               # 列出
> headroom-ctl memory search "中文"      # 搜索
> headroom-ctl memory add -c "..." -k preference   # 加
> headroom-ctl memory remove <id>        # 删
> ```

### 5.4 Bash alias(放进 `~/.bashrc`,可选)

```bash
# 2026-06-06 改用单脚本 headroom-ctl(替代旧的 3 个独立脚本 alias)
alias hr='~/bin/headroom-ctl'
alias hr-status='~/bin/headroom-ctl status'
alias hr-restart='~/bin/headroom-ctl restart'
alias hr-claude='ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude'
alias hr-codex='OPENAI_BASE_URL=http://127.0.0.1:8787/v1 codex'
alias hr-stats='curl -sS http://127.0.0.1:8787/stats | python3 -m json.tool | head -50'
alias hr-log='tail -f /tmp/headroom.log'
```

用法:

```bash
source ~/.bashrc
hr-status       # 看状态
hr-restart      # 重启
hr-claude       # 跑 claude(自动走 headroom)
hr-codex        # 跑 codex(自动走 headroom)
hr-stats        # 看省钱
hr-log          # 看 log
```

---

### 5.5 Codex 集成(零代码修改)

> **官方来源**:本节所有配置都对照
> - [Codex Config basics](https://developers.openai.com/codex/config-basic) (2026-06-05 抓取)
> - [Codex Config advanced](https://developers.openai.com/codex/config-advanced)
> - [Codex Hooks](https://developers.openai.com/codex/hooks)
> - [Headroom Proxy docs](https://headroom-docs.vercel.app/docs/proxy)

#### 5.5.1 思路

Headroom proxy 暴露 `POST /v1/chat/completions`(OpenAI 兼容),所以 codex 通过 `OPENAI_BASE_URL` 指过去就行,跟 cursor 一样。**不需要**改 `~/.codex/config.toml`,**不需要** hooks。

> **官方原文**(headroom-docs.vercel.app/docs/proxy):
> ```
> # Cursor / any OpenAI-compatible client
> OPENAI_BASE_URL=http://localhost:8787/v1 cursor
> ```

#### 5.5.2 用法

```bash
headroom-up
OPENAI_BASE_URL=http://localhost:8787/v1 codex
# 或 alias 后:
headroom-codex
```

#### 5.5.3 可选:用 `headroom wrap` 透明包装(官方支持)

```bash
# 官方 docs 原话:
#   Use `headroom wrap` to transparently proxy any CLI tool:
#     headroom wrap codex
#     headroom wrap claude
#     headroom wrap aider
#     headroom wrap cursor
#
# 启用后会拦截 codex 的网络调用,无需设 OPENAI_BASE_URL
headroom wrap codex
codex
```

> 这是 Headroom 0.23 的 `wrap` 子命令(在 `/docs/proxy` 文档里有列),会自动修改 codex 的运行时环境。具体副作用看 `headroom wrap codex --help`,**不放心就只用 `OPENAI_BASE_URL` 模式**。

#### 5.5.4 (进阶) 手动改 `~/.codex/config.toml`

只有在你需要**持久化**配置或接入**自定义 provider** 时才需要改 config.toml。Codex 配置优先级(官方原文):

> 1. CLI flags and `--config` overrides
> 2. Project config files: `.codex/config.toml` ...
> 3. Profile files (`~/.codex/profile-name.config.toml`)
> 4. **User config: `~/.codex/config.toml`**
> 5. System config (`/etc/codex/config.toml`)
> 6. Built-in defaults

**重要约束**(官方原文,config-advanced § Project overrides):
> Project config files can't override settings that redirect credentials, alter host-owned app request metadata, change provider auth, select config profiles, or run machine-local notification/telemetry commands. Codex ignores the following keys in project-local `.codex/config.toml`... `openai_base_url`, `model_provider`, `model_providers`, ...

所以 `model_provider` / `openai_base_url` **必须放在 `~/.codex/config.toml`**,不能放项目级。

**写法 A** — 用 `openai_base_url` 改 built-in OpenAI provider(最简):

```toml
# ~/.codex/config.toml
model = "gpt-4o"                              # 或其他想用的模型
openai_base_url = "http://localhost:8787/v1"   # ← 官方支持
```

**写法 B** — 自定义 provider(更显式):

```toml
# ~/.codex/config.toml
model_provider = "headroom"

[model_providers.headroom]
name = "Headroom proxy"
base_url = "http://localhost:8787/v1"
# 可选:wire_api = "chat_completions"   # 默认就是 chat_completions
# 可选:[model_providers.headroom.auth]
#        env_key = "OPENAI_API_KEY"
```

> **Reserved IDs**(官方):`openai` / `ollama` / `lmstudio` 是内置保留的,不能用作自定义 provider ID。所以用 `headroom` 这个名字。

**注意**:Codex 的 `model_provider` 字段是给 Codex 自己看的,**不影响** headroom proxy 端。proxy 端是用 `ANTHROPIC_TARGET_API_URL` 决定上游。

#### 5.5.5 (可选) Codex hooks

Codex 也支持 lifecycle hooks(类似 Claude Code 的 hooks),位置在 `~/.codex/hooks.json` 或 inline `[[hooks.X]]` in `~/.codex/config.toml`。

> **官方原文**(Codex Hooks docs):
> "Hooks are enabled by default. If you need to turn them off in `config.toml`, set:
> ```
> [features]
> hooks = false
> ```
> Use `hooks` as the canonical feature key. `codex_hooks` still works as a deprecated alias."

也就是说 **`[features] hooks = true` 是官方主推的 canonical key**(`codex_hooks` 是 deprecated alias 仍兼容)。headroom 的 `init codex` 子命令会写 `codex_hooks`,能用但不是首选——**手动写的时候用 `hooks`**。

事件列表(官方):

| 事件 | 触发时机 |
|---|---|
| `SessionStart` | 会话开始或 resume |
| `PreToolUse` | 工具调用前 |
| `PostToolUse` | 工具调用成功后 |
| `PreCompact` / `PostCompact` | 上下文压缩前后 |
| `UserPromptSubmit` | 用户提交 prompt |
| `SubagentStart` / `SubagentStop` | 子 agent 起停 |
| `Stop` | agent 响应结束 |

hooks.json 格式示例(官方原文):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.codex/hooks/session_start.py",
            "statusMessage": "Loading session notes"
          }
        ]
      }
    ]
  }
}
```

**一般用不上**——headroom 不需要靠 codex hooks 启动 proxy,proxy 自己常驻即可。

---

### 5.6 Memory:三写一读模型 + 调用时机(2026-06-06 补)

> **核心设计**:`headroom memory` 是**多写一读**架构——3 个入口能写同一个 SQLite DB,但只有 1 个读出口(proxy recall + 显式 query)。**2026-06-06 起 `--memory` 默认启用**(`config.yaml` 里 `features.memory: true`)。

#### 5.6.1 三个写入路径(写 DB)

| 路径 | 谁触发 | 时机 | 频率 |
|---|---|---|---|
| **SDK 工具函数** `HeadroomClient.memory.add()` | **LLM agent**(Claude/Codex 等)自己决定"这条要存" | LLM 在对话中判断"用户偏好/事实/决策值得记" | LLM 自决(可能 0-多次/天) |
| **CLI** `headroom-ctl memory add -c "..." -k <kind>` | **开发者** | 显式,临时 | 你自律(可能 0-几次/月) |
| **Proxy 自动** (auto-capture) | proxy 内部 | 当前**没启**(0.23.0 无此机制) | — |

**关键**:**3 个入口写到同一个 DB**(默认 `cwd/memory.db`,per-project 模式),所以你 `headroom-ctl memory add` 写一条,proxy 下次请求 recall 时就能查到。

#### 5.6.2 一个读出路径(读 DB)

| 路径 | 谁读 | 时机 | 行为 |
|---|---|---|---|
| **Proxy 自动 recall** | proxy 内部 | **每次请求处理时**(零配置) | 查 DB → 把相关 facts 注入 system message → 转发给上游 LLM。LLM 不知道有这步(隐式) |
| **SDK 工具** `memory.search(query, top_k=5)` | **LLM agent** | LLM 主动调 | 显式查"用户之前提过啥" |
| **CLI** `headroom-ctl memory list/search/stats` | **开发者** / **巡检脚本** | 显式 | 查 DB 当前状态 |

#### 5.6.3 数据流(具体例子:用户偏好中文回复)

```bash
# 1. 一次性:加偏好
headroom-ctl memory add -c "用户偏好中文回复" -k preference
# → DB 有 1 条 memory(scope=USER, importance=1.0)
```

```
你: "用中文解释这段 Python 代码"
Claude Code ──→ headroom:8787 ──→ gotoken ──→ LLM
                  │
                  ├─ 1. recall(query="用中文解释 Python", top_k=5)
                  │     → 命中 "用户偏好中文回复"
                  │
                  ├─ 2. 注入 system message
                  │     system: "...已知用户偏好: [用户偏好中文回复]..."
                  │
                  └─ 3. 转发到 LLM

LLM 看到 system msg 里有偏好 → 中文回复
```

**注意**:你不需要每次手动说"先查 memory"——headroom 每次请求自动做这步。

#### 5.6.4 启用 + 4 步上手

```bash
# 1. yaml 里启(2026-06-06 起默认 true,跳过)
headroom-ctl config-edit
# features.memory: true

# 2. 重启 proxy(必须,启动参数)
headroom-ctl restart

# 3. 验启了
headroom-ctl status | grep -i memory
# 期望:memory: True

# 4. 加几条(可省,DB 也能是空的)
headroom-ctl memory add -c "用户偏好中文回复" -k preference
headroom-ctl memory add -c "Python 风格: type hints + docstring" -k preference
headroom-ctl memory add -c "本项目 Hermes 用 Sprint 编号管理" -k project

# 5. 验 DB
headroom-ctl memory list
headroom-ctl memory stats
```

#### 5.6.5 类别(category)枚举 + 含义

| 类别 | 用途 | 例子 |
|---|---|---|
| `PREFERENCE` | 用户偏好 | "用户偏好中文回复"、"不要 emoji" |
| `FACT` | 客观事实 | "Python 3.13 在 2024-10 发布" |
| `CONTEXT` | 上下文/项目背景 | "Hermes 是 wiki 知识库项目" |
| `ENTITY` | 实体/人 | "StarkYuan 是项目 owner" |
| `DECISION` | 已做的决策 | "决定 wiki 用 wikilink 风格" |
| `INSIGHT` | 经验/洞察 | "Sprint 12 用了 4 周,太长" |

> CLI 用短名(`-k preference` / `-k fact` / ...),SDK 用全大写枚举。

#### 5.6.6 为什么不默认开?—— 风险 + 关法

> **0.23.0 文档说"relay 慎用"**:`memory_20250818` 工具如果 LLM 主动调,relay(gotoken / minimaxi)**不支持该工具 → 400 错**。
>
> **0.25.0 行为变化**(2026-06-14 升级后实测):headroom 0.25.0 启动 banner 显示 `Anthropic: Uses native memory tool (memory_20250818) - subscription safe`,这意味着:
> 1. **Anthropic 路径**:proxy 现在**会把 `memory_20250818` 当作 native tool 暴露给 LLM**(订阅级安全工具,Anthropic 官方 API 认识)。relay(gotoken / minimaxi)**不一定认识这个 tool spec**——仍是风险
> 2. **OpenAI / Gemini / Others**:走 function calling 格式(不走 native tool),relay 兼容性取决于具体 relay 实现
> 3. **Storage mode**:banner 显示 `project (per-project DB by default — set x-headroom-project-id / x-headroom-cwd to override)`——可用 header 切换 DB 模式
>
> 0.23.0 → 0.25.0 的关键差异:**0.23.0 proxy 只在 recall 阶段查 DB,不主动 add,LLM 看不到 memory_20250818 工具(SDK 模式才会暴露)**;0.25.0 默认会暴露 native tool 给 LLM。这提高了 memory 的可用性,但**对 relay 的兼容性风险也加大了**。
>
> 2026-06-14 升级决定(沿用 2026-06-06 拍板):`features.memory: true` **仍然默认开**,因为:
> 1. 启用本身无害(只是加载 embedder,多 ~50MB 内存)
> 2. DB 空时 recall 零开销(返回 [])
> 3. 真正 400 错**只在 LLM 主动调 memory 工具时**(Anthropic native)或 tool schema 不被 relay 识别时(OpenAI function calling)
> 4. 即使出 400,`features.memory: false` 一秒回滚

**关法**:
```bash
# 临时
HEADROOM_MEMORY=0 headroom-ctl restart

# 持久
headroom-ctl config-edit   # features.memory: false
headroom-ctl restart
```

#### 5.6.7 约束(谁约束、怎么约束)

| 约束 | 机制 | 谁执行 |
|---|---|---|
| **add 频率** | 无硬约束——DB 56KB/1000 条,跑一年都不爆 | 你自律 |
| **category 枚举** | SDK 校验,传 `category=foo` 报无效 | SDK |
| **向量维度** | `vector_dimension=384`(默认),proxy 不暴露 | SDK 默认值 |
| **HNSW 索引** | `hnsw_m=16` 等 3 个内部参数,proxy 不暴露 | SDK 默认值 |
| **DB 位置** | 默认 `cwd/memory.db`(per-project)。本部署是 `/data/hermes/headroom_memory.db` | proxy 启动参数 |
| **DB 写权限** | 文件系统权限(谁能写 sqlite DB 谁能 add) | OS |

#### 5.6.8 跟其他"持久化"的对比(避免混淆)

| 机制 | 谁在用 | 持久化到 | 跟 memory 的区别 |
|---|---|---|---|
| **`--memory` + recall** | headroom proxy | sqlite DB | **自动 recall**,LLM 不感知 |
| **`CLAUDE.md` / `MEMORY.md`** | LLM 读 system prompt | 文件 | **写死的**,每次启动都注入,LLM 看得到 |
| **`learn --apply` 写入 markers** | LLM 读 system prompt | CLAUDE.md 的 markers 段 | **静态**,跑一次就固定 |
| **LLM 长程 context** | LLM provider | provider 端 | **跨 session 失效**(除非用 memory) |

#### 5.6.9 跟 `learn` 的本质区别(避免误用)

| 维度 | memory | learn |
|---|---|---|
| **触发方** | 任何(LLM 工具/CLI/proxy recall) | **仅开发者手动** |
| **运行时** | 每次请求都跑(自动) | **完全离线** |
| **写目标** | sqlite DB | CLAUDE.md / MEMORY.md 文件(markers 包裹) |
| **数据形式** | 事实/偏好/决策,带 category + importance | 失败模式总结,带代码片段 |
| **LLM 读得到** | proxy recall 注入(隐式) | 启动时读 system prompt(显式) |
| **频率** | 高频(每次请求) | 低频(Sprint 末/失败后) |

> **口诀**:**memory 是"工作记忆",learn 是"项目档案"**。前者临时反复用,后者沉淀不复用。

---

### 5.7 Memory & SharedContext:使用时机 + 工作流程(2026-06-07 补,基于官方 docs + 源码)

> **来源**:`headroom-docs.vercel.app/docs/memory` 和 `/docs/shared-context`(Jina Reader 抓取,版本对齐 0.23.0)+ `headroom/shared_context.py` 完整源码(218 行)+ `memory/easy.py` 顶层 API。
>
> **本节定位**:§5.6 讲 memory 的"是什么 + 怎么管",本节讲"**什么时候用哪个 + 工作流程长啥样**",针对 4 个真实场景。文档末尾(§5.7.8)给"官方 docs vs 本地知识库"差异对照,方便后续维护者对账。

#### 5.7.1 判定流程(看到需求先选哪个)

```
                    ┌──────────────────────────┐
                    │  LLM 跨 session 记住     │
                    │  "用户偏好/项目事实"?    │
                    └──────────┬───────────────┘
                               │ 是
                               ▼
                   ┌────────────────────────┐
                   │  Memory ✅ 默认启       │
                   │  • proxy 自动 recall    │
                   │  • CLI 手加             │
                   │  • SDK with_memory()    │
                   └────────────────────────┘

                    ┌──────────────────────────┐
                    │  多 agent 协作场景       │
                    │  (agent A → agent B)?   │
                    └──────────┬───────────────┘
                               │ 是
                               ▼
                   ┌────────────────────────┐
                   │  SharedContext ⚠️ SDK  │
                   │  • 仅 Python 进程内     │
                   │  • 无 CLI / 无 proxy    │
                   │  • 自己写协调器         │
                   └────────────────────────┘
```

**口诀**:
- **"LLM 该记住什么"** → Memory(本部署默认启了)
- **"agent 之间传什么"** → SharedContext(本部署暂时用不上)
- **"我在自己代码里用"** → Memory `with_memory()` 或 SharedContext(都 SDK)
- **"我想查 DB 巡检"** → Memory CLI(`headroom-ctl memory list`)

#### 5.7.2 当前系统配置现状(2026-06-07 抓取)

| 配置 | 值 | 含义 |
|---|---|---|
| `features.memory` | `true` | proxy 启了 `--memory` 标志 ✅ |
| `paths.memory_db` | `/data/hermes/headroom_memory.db` | per-project DB,跟随启动 cwd |
| DB 状态 | 57KB,**0 行** | 还没灌过水 |
| 启的 embedder | 默认 `LOCAL` + `all-MiniLM-L6-v2` | 启动加载 ~80MB 模型 |
| 启的副作用 | proxy 启动 +1-2s,稳态 +~50MB 内存 | DB 空 recall 零开销 |
| `features.shared_context` | **无此配置项** | SDK-only,proxy 不自动用 |

#### 5.7.3 场景 A:Claude Code proxy 自动 recall(本部署默认行为)

**触发条件**:你跑 `claude` → `ANTHROPIC_BASE_URL` 指 `http://127.0.0.1:8787` → proxy 接到请求。

```
时序图:

  你  ─→  Claude Code  ─→  headroom proxy:8787  ─→  upstream LLM
              │                  │                      │
              │  1. POST 消息    │                      │
              │─────────────────→│                      │
              │                  │ 2. 查 memory DB       │
              │                  │    recall(query=...)  │
              │                  │    → top-5 命中       │
              │                  │                      │
              │                  │ 3. 拼 system msg:     │
              │                  │    "已知用户偏好:      │
              │                  │     [中文回复...]"    │
              │                  │                      │
              │                  │ 4. 转发到 upstream     │
              │                  │─────────────────────→│
              │                  │                      │
              │                  │ 5. LLM 响应           │
              │                  │←─────────────────────│
              │  6. 返回响应      │                      │
              │←─────────────────│                      │
```

**关键设计点**:
- **LLM 不知道有 memory**——这就是"代理模式"的核心:对 LLM 完全透明
- **每个请求都 recall**——即使 DB 有 1000 条,top-5 注入
- **写不进去除非用 CLI 或 SDK**——proxy 0.23.0 不主动 add(防止 LLM 写垃圾进 DB)
- **DB 跟着启动 cwd 走**——你 `cd /data/hermes` 启 proxy,就是 `/data/hermes/headroom_memory.db`

**本部署实操**:
```bash
# 1. 验证启了(已确认)
headroom-ctl status | grep memory  # → True

# 2. 加 3 条让 recall 真的能命中(场景 B 详解)
headroom-ctl memory add -c "用户偏好中文回复,简洁直接" -k preference
headroom-ctl memory add -c "Hermes 是 wiki 知识库项目" -k context
headroom-ctl memory add -c "Claude Code 走 headroom proxy :8787" -k fact

# 3. 跑 claude
hr-claude  # alias 已在 §5.4

# 4. 观察(可选)
hr-log  # tail -f /tmp/headroom.log
# 应该看到 "memory recall" log + 注入的 system msg
```

#### 5.7.4 场景 B:开发者手动加记忆(memory CLI)

**使用时机**:
- 你**明确知道**有件事 LLM 该记住
- 你想**现在立刻**让下次会话的 LLM 知道
- 不想等 LLM 自己决定(proxy 0.23.0 不主动 add)

**典型场景**:
- "我刚做完 Sprint 1 决策,记一下"
- "我换工作了,旧事实 supersede"
- "我学到个最佳实践,记下来以后参考"

**工作流程**:
```
你  ─→  headroom-ctl memory add  ─→  SQLite DB
                                         │
                                         │  写 1 条
                                         │  (category, importance, scope=USER)
                                         ▼
                                    [memory DB]
                                         │
                                         │  下次 Claude Code 请求
                                         │  → proxy recall 自动命中
                                         ▼
                                    LLM 看到这条事实
```

**实操例子**(类别速查见 §5.6.5):
```bash
# 加偏好
headroom-ctl memory add -c "用户偏好中文回复,简洁直接" -k preference

# 加事实
headroom-ctl memory add -c "Python 3.13 是 hermes dev 用的版本" -k fact

# 加决策
headroom-ctl memory add -c "决定 wiki 用 wikilink 风格" -k decision

# 查
headroom-ctl memory list
headroom-ctl memory search "中文"
headroom-ctl memory stats
```

#### 5.7.5 场景 C:多 agent 协作(SharedContext)— SDK-only,本部署 proxy 不支持

**使用时机**:
- 你写**多 agent 协调器**(CrewAI / LangGraph / OpenAI Agents SDK)
- agent A 产出**大段输出**(研究结果、代码、文档),agent B 要用
- 不希望把**全部原文**塞进 agent B 的 prompt(省 80% tokens)

**本部署现实**:
- ❌ headroom proxy **没有**自动 SharedContext 协调(proxy 走自己的 CCR 压缩,不走 SharedContext)
- ❌ 没有 `headroom-ctl shared-context` CLI
- ✅ SDK 可用,在你自己的 Python 代码里 `from headroom import SharedContext`

**API 速查**(从 `shared_context.py:218` 抓取):

| 方法 | 行为 | 关键参数 |
|---|---|---|
| `ctx.put(key, content, agent=None)` | 压缩存 | `agent` 用于追踪来源 |
| `ctx.get(key, full=False)` | 默认拿压缩版 | `full=True` 拿原文 |
| `ctx.get_entry(key)` | 拿完整元数据 | 返回 `ContextEntry`(transforms 用啥) |
| `ctx.keys()` | 列出所有有效 key | TTL 内 |
| `ctx.stats()` | 聚合统计 | `SharedContextStats`(entries/total_saved/savings_percent) |
| `ctx.clear()` | 清空 | — |

**构造参数**:`SharedContext(model="claude-sonnet-4-5-20250929", ttl=3600, max_entries=100)`

**Eviction 规则**(`shared_context.py:209-218`):
- TTL 过期 → get 时 lazy 删除
- 满 max_entries → LRU(删最旧 timestamp)

**3 个框架集成**(官方 docs 原文):

| 框架 | 集成方式 | 关键代码 |
|---|---|---|
| **CrewAI** | task 间传 output 时 `ctx.put` + `ctx.get` | `ctx.put("findings", task.output.raw)` |
| **LangGraph** | node 函数里 `ctx.put` 存 state,return `ctx.get` 进 state | `state["research_summary"] = ctx.get("research")` |
| **OpenAI Agents SDK** | handoff 的 `input_filter` 里替换长消息 | `ctx.put(msg.id, msg.content); msg.content = ctx.get(msg.id)` |

**CrewAI 完整例子**:
```python
from headroom import SharedContext
ctx = SharedContext()  # ttl=3600, max_entries=100

# Agent A: 研究员跑完,20000 tokens 报告存进 ctx
ctx.put("findings", researcher_task.output.raw, agent="researcher")
# → 内部:headroom.compress() 压成 ~4000 tokens
# → 存原版 + 压缩版到内存 dict

# Agent B: 程序员拿压缩版写代码
coder_context = ctx.get("findings")  # ~4000 tokens 摘要

# 程序员发现需要细节
full = ctx.get("findings", full=True)  # 20000 tokens 原文
```

**压缩路由**(官方原文,`put()` 内部调 `headroom.compress`):
- JSON 数组 → **SmartCrusher**(70-95% 压缩)
- Code → **CodeCompressor**(AST-aware)
- Text → **Kompress**(ModernBERT-based)或 passthrough

**本部署能跑吗**:
- 能跑,**只要你写自己的 Python 协调脚本**
- 适用场景:你用 `langgraph` 写工作流、用 `crewai` 跑研究流水线
- 不适用:Claude Code 子 agent(Claude Code 不暴露 `ctx` 给你,无法从外部干预它的 handoff)

#### 5.7.6 场景 D:自定义 Python 脚本 `with_memory()` 包装(SDK 模式)

**使用时机**:
- 你**自己写 Python 脚本**调 OpenAI / Anthropic 客户端
- 想让脚本**自动提取并存储事实**到 memory DB
- 不想手写 recall / extract 逻辑

**6 步工作流**(官方原文,零延迟):
```
你写脚本:client = with_memory(OpenAI(), user_id="alice")
                ↓
client.chat.completions.create(...)
                ↓
┌──────────────────────────────────────────────┐
│ with_memory() 包装器在中间做 6 件事:         │
│                                              │
│ 1. Inject   → 语义搜 + 注入相关 memory 到 user msg
│ 2. Instruct → 加 memory extraction 指令到 system prompt
│ 3. Call     → 转给 LLM                          │
│ 4. Parse    → 从 LLM 响应解析 <memory> 块       │
│ 5. Store    → 存到 DB (embeddings + FTS5 + HNSW)│
│ 6. Return   → 清掉 memory 块,把响应给你         │
└──────────────────────────────────────────────┘
                ↓
你的代码拿到响应(无 memory 块污染)
memory DB 多 1 条
```

**关键点**:
- **零额外延迟**——memory extraction 在同一次 LLM call 里完成
- **inline**——不用调 2 次 LLM(一次问、一次提取)
- **包装器不污染响应**——`<memory>` 块被剥掉再返回
- **跟 proxy 自动 recall 是两套机制**——SDK 包装自己 OpenAI 客户端,proxy 拦截 Claude/Codex 客户端

**本部署实操示例**:
```python
from openai import OpenAI
from headroom import with_memory

client = with_memory(
    OpenAI(api_key="sk-..."),  # 你自己的 OpenAI key
    user_id="stark",
    session_id="test-1",
)

resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "I prefer Python for backend work"}]
)
# → 0 延迟,inline 提取,DB 多了 1 条 PREFERENCE

resp2 = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "What language for my new microservice?"}]
)
# → 自动 recall Python 偏好,响应里体现
```

**3 个 embedder 后端**(官方原文,`MemoryConfig` 配置):
| 后端 | 默认模型 | 特点 |
|---|---|---|
| `LOCAL` | `all-MiniLM-L6-v2` | 默认,fast/free/private,~80MB |
| `OPENAI` | `text-embedding-3-small` | 高质量,花钱,需 `openai_api_key` |
| `OLLAMA` | `nomic-embed-text` | 本地 ollama server,免费 |

**Supersession 链**(事实变化保留历史,可回滚):
```python
from headroom.memory import HierarchicalMemory, MemoryCategory

memory = await HierarchicalMemory.create()

# Original
orig = await memory.add(
    content="User works at Google",
    user_id="alice",
    category=MemoryCategory.FACT,
)

# User changes jobs
new = await memory.supersede(
    old_memory_id=orig.id,
    new_content="User now works at Anthropic",
)

# Get full chain
chain = await memory.get_history(new.id)
# [
#   Memory(content="User works at Google", is_current=False),
#   Memory(content="User now works at Anthropic", is_current=True),
# ]
```

**关键事实:SDK 写和 proxy recall 是同一个 DB**

`memory/easy.py` 和 `memory/mcp_server.py` 跟 proxy `server.py` 读的是同一个 `paths.memory_db`(`/data/hermes/headroom_memory.db`)。所以:
- 你在 Python 脚本里 `with_memory()` 写的偏好
- Claude Code 跑 proxy 时 recall 也能命中
- **两套机制可以互通**

#### 5.7.7 4 场景速查表

| 场景 | 用啥 | 怎么用 | 本部署能跑吗 | 工作量 |
|---|---|---|---|---|
| **A** Claude Code 跑任务,LLM 知道我的偏好 | memory | 自动(啥都不做) | ✅ 已配 | 0 |
| **B** 我想现在记一条事实给 LLM | memory CLI | `headroom-ctl memory add ...` | ✅ 装好 | 1 分钟 |
| **C** 多 agent 协作传大输出 | SharedContext | SDK 写协调器 | ⚠️ 需自己写 | 1-2 小时 |
| **D** 我自己 Python 脚本管 memory | `with_memory()` | SDK 包装 OpenAI 客户端 | ✅ SDK 可用 | 10 分钟 |

#### 5.7.8 官方文档 vs 本地知识库差异(2026-06-07 Jina Reader 对照)

| 项 | 官方 docs | 本地 §5.6 补充 | 备注 |
|---|---|---|---|
| `with_memory()` 包装器 | ✅ 主推入口 | ❌ 未提 | 官方主推,SDK 模式 |
| `supersede()` / `get_history()` 链 | ✅ 完整例子 | ❌ 未提 | 事实变化保留历史 |
| 3 个 embedder 后端 | ✅ LOCAL/OPENAI/OLLAMA | ❌ 只说 "LOCAL 默认" | ONNX 选项本地文档未提 |
| 默认 embedder 模型 | `all-MiniLM-L6-v2` ~80MB | "启 `--memory` 加载 embedder ~50MB" | 数字略不同(模型本身 vs 推理时) |
| Memory extraction 零延迟 | ✅ "inline" | ❌ 未强调 | 关键设计点 |
| 4 个 scope 层级 | ✅ USER/SESSION/AGENT/TURN | ✅ 一致 | — |
| 6 个 category 含义 | ✅ PREFERENCE/FACT/CONTEXT/ENTITY/DECISION/INSIGHT | ✅ 一致 | — |
| 3 个 SharedContext 框架集成 | ✅ CrewAI/LangGraph/OpenAI Agents SDK | ❌ 未提 | 官方独有 |
| SharedContext 压缩路由 | ✅ SmartCrusher/CodeCompressor/Kompress | ❌ 未提 | 官方独有 |
| CLI `headroom-ctl memory add -k <短名>` | (未提 CLI,主推 SDK) | ✅ 完整 CLI 用法 | 本地运维独有 |
| DB 空时 recall 零开销 | ❌ 未提 | ✅ 写在 §5.6 | 本地运维观察 |
| proxy 0.23.0 只 recall 不主动 add | ❌ 未提 | ✅ 写在 §5.6 | 本地源码验证 |
| SDK 与 proxy 写同一 DB | (未明说) | ✅ §5.6 "三写一读" 隐含 | 需明确"互通"事实(本节 5.7.6 末段) |

#### 5.7.9 日常节奏(基于本部署)

| 时机 | 操作 |
|---|---|
| **Sprint 开始** | 跑 1 次 `headroom-ctl memory add -c "Sprint X 主题:..." -k context` |
| **Sprint 决策** | 跑 1 次 `headroom-ctl memory add -c "决定..." -k decision` |
| **学到经验** | 跑 1 次 `headroom-ctl memory add -c "..." -k insight` |
| **巡检** | `headroom-ctl memory stats` 看大小、`list` 看内容 |
| **DB 太大** | `remove` 删旧条目 / 整体 `clear()` 重建 |
| **多 agent 协作** | 写自己协调器(用 `SharedContext`) |
| **自写 Python 脚本** | 用 `with_memory()` 包装 OpenAI 客户端 |

#### 5.7.10 1 分钟上手验证

```bash
# 1. 验证 A 在跑
headroom-ctl status | grep -E "memory|code_aware"
# 期望:memory=True,code_aware=True

# 2. 给 B 灌 3 条
headroom-ctl memory add -c "用户偏好中文回复,简洁直接" -k preference
headroom-ctl memory add -c "Hermes 是 wiki 知识库项目,PolyWiki 范式" -k context
headroom-ctl memory add -c "headroom proxy 走 8787 端口" -k fact

# 3. 跑 claude 验证
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude
# 问:"我偏好什么语言?这个项目是干啥的?"
# 期望:LLM 答"中文" + 提到"wiki 知识库项目"

# 4. 看 stats
headroom-ctl memory stats
# 期望:3 entries
```

---

## 6. 监控与运维

### 6.1 健康端点

| 端点 | 用途 | 成功 |
|---|---|---|
| `GET /livez` | 进程在 | 200 |
| `GET /readyz` | 能接流量 | 200 |
| `GET /health` | 完整健康(JSON) | 200 |
| `GET /stats` | 详细省钱/性能统计 | 200 |
| `GET /stats-history` | 历史趋势 | 200 |
| `GET /metrics` | Prometheus 格式 | 200 |

### 6.2 性能分析

```bash
headroom perf                  # 从 logs 分析延迟分布
headroom perf --top 10         # 慢的 10 个端点
```

### 6.3 进程管理

```bash
# 查
pgrep -af "headroom proxy"

# 实时 log
tail -f ~/log/headroom/proxy.log

# 实时连接
ss -tnp 2>/dev/null | grep 8787

# 优雅停(等 in-flight 完成)
pkill -TERM -f "headroom proxy"
sleep 3

# 强杀(有请求会断)
pkill -9 -f "headroom proxy"
```

### 6.4 memory DB 维护

```bash
# 位置(per-project 模式,跟着启动 cwd 走)
ls -la /data/hermes/headroom_memory.db
ls -la ~/.headroom/                      # 全局 deploy / logs

# 看大小
du -sh /data/hermes/headroom_memory.db

# 切 WAL(避免并发写锁)
sqlite3 /data/hermes/headroom_memory.db 'PRAGMA journal_mode=WAL;'

# 备份
cp /data/hermes/headroom_memory.db /data/hermes/headroom_memory.db.bak.$(date +%Y%m%d)

# 清空(谨慎!)
headroom memory clear  # 真的有这个子命令时再用
# 或手动
sqlite3 /data/hermes/headroom_memory.db 'DELETE FROM memories;'
```

---

## 7. 故障排查速查表

| 症状 | 原因 | 修法 |
|---|---|---|
| proxy 启动 4+ 分钟不 bind 端口 | HF `xet` 协议被 SOCKS 限速到 0 字节 | 加 `HF_HUB_DISABLE_XET=1` |
| 启动 4+ 分钟 0 字节下载 | 同上,SOCKS→HF 慢 | 加 `HF_ENDPOINT=https://hf-mirror.com` |
| 报 `ModuleNotFoundError: No module named 'fastapi'` | uv tool 没装全 | `uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai[all]"` |
| claude 报 401/403 | 找不到 `ANTHROPIC_AUTH_TOKEN` | `headroom-up` 前先 `source ~/.config/headroom/proxy.env` |
| claude 报连接拒绝 | proxy 没起 | `headroom-up`,等 `/readyz` 返回 200 |
| 端口 8787 冲突 | 上次没杀干净 | `pkill -9 -f "headroom proxy"; sleep 2` |
| DB 锁等 | `journal_mode=delete` | `sqlite3 headroom_memory.db 'PRAGMA journal_mode=WAL;'` |
| `--memory` 启动后 400 错 | gotoken relay 不支持 `memory_20250818` 工具 | 删 `--memory` 和 `HEADROOM_MEMORY=on`,改纯代理 |
| `claude plugin marketplace` git clone 超时 | 同根因:网络出口慢 | 不要用 `headroom init claude`,改手动 `ANTHROPIC_BASE_URL` 启动 |
| ONNX 模型持续重新下载 | 缓存被清 | 缓存位置 `~/.cache/huggingface/`,确保磁盘够(模型约 70MB) |

---

## 8. 关于 `/data/hermes/headroom_memory.db`

- **位置正确**:headroom v0.23 默认 per-project 模式,跟着启动 cwd 走,从 `/data/hermes/` 启就用这个文件
- **schema 正确**:headroom v0.23 长程 memory 表(20 列,带 TTL/importance/supersedes 链/embedding)
- **目前空**:`rows=0, user_version=0`,`journal_mode=delete`
- **要让它"有用"**:`headroom-up` 启时带 `--memory`(但**先确认你的 gotoken relay 兼容 Anthropic memory_20250818 工具**,不兼容就回退)
- **不打算用 memory 就删**:`rm /data/hermes/headroom_memory.db`(反正 0 数据,删了不影响 proxy 本身)

---

## 9. 启动流程图(决策树)

```
开始
  │
  ├─ 完全不用 → headroom-down
  │
  ├─ 只验证链路 → 模式 2(passthrough,无 --memory)
  │
  ├─ 想要压缩 + 缓存(主流) → headroom-up(默认配置)
  │     │
  │     ├─ 跑一段看 headroom-status
  │     └─ 觉得 savings 不好看 → 开 --code-aware
  │
  └─ 全开 → headroom-up + --memory --learn(注意 relay 兼容性)
```

---

## 10. 当前实际状态(2026-06-14,0.25.0 升级后)

| 项 | 值 |
|---|---|
| `headroom --version` | **0.25.0** |
| 仓库 | `/tmp/headroom` @ `26f325f5` (历史 clone,未再 sync) |
| Python 包装 | uv tool venv (`~/.local/share/uv/tools/headroom-ai/`) |
| Proxy PID | 1458870(本次会话) |
| 端口 | 127.0.0.1:8787 |
| 上游 | `https://api.gotoken.top`(Anthropic),`https://api.codexzh.com/v1`(OpenAI),Vertex AI 路由已上线但未配置 |
| Optimize/Cache/Rate-limit | ✅ on |
| Memory | ✅ **on**(0.25.0 多 provider 模式,Anthropic native `memory_20250818` 暴露,OpenAI/Gemini 走 function calling) |
| Code-Aware | ✅ on(`tree_sitter_language_pack` 0.25.0 收成默认依赖,workaround 不再需要) |
| Code-Graph | ✅ on |
| Telemetry | ❌ off |
| Rust core | ✅ loaded |
| 配置 | `~/.config/headroom/config.yaml`(2026-06-06 起替代 `proxy.env`) |
| 管理脚本 | `~/bin/headroom-ctl`(16 个子命令,2026-06-15 新增 5 个透传: agent-savings / perf / capture / evals / install) |
| Log | `/tmp/headroom.log` |
| Memory DB | `/data/hermes/headroom_memory.db` (空,2026-06-14 仍是 0 行) |
| 缓存(ONNX 模型) | `~/.cache/huggingface/hub/models--chopratejas--kompress-v2-base/`(首次请求触发下载,默认 261MB int8-wo,fallback 601MB fp32)|
| 升级前备份 | `~/backup/headroom-upgrade-20260614-201030/`(12 个文件,1.1MB) |

> **关于 §10 时点说明**:本节作为 0.25.0 升级后的快照。`docs/headroom-diagnosis-report-2026-06-06.md` 仍是 0.23.0 时点的诊断(详见 §0.0),**未重跑**。Phase 4 真流量对比 + 新诊断报告是后续工作。

---

## 11. 一键恢复(出问题时回到干净状态)

```bash
# 停 proxy
pkill -9 -f "headroom proxy"

# 清缓存(下次启动会重下)
rm -rf ~/.cache/huggingface/hub/models--chopratejas--kompress-v2-base

# 清 headroom 全局
rm -rf ~/.headroom/

# 清项目 memory DB
rm -f /data/hermes/headroom_memory.db

# 升级(0.25.0 后推荐用 upgrade 而非 uninstall/install)
uv tool upgrade headroom-ai

# 或彻底重装
uv tool uninstall headroom-ai
uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai[all]"
# 注:0.25.0 已自动包含 tree_sitter_language_pack,无需再补 [code] extra

# 重启
~/bin/headroom-ctl restart
```

> **0.25.0 升级回滚**(如需回到 0.23.0):
> ```bash
> pkill -9 -f "headroom proxy"
> uv tool uninstall headroom-ai
> uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai==0.23.0"
> ~/bin/headroom-ctl restart
> ```
> 备份的 `proxy_savings.json` / `toin.json` 在 `~/backup/headroom-upgrade-20260614-201030/` 可按需恢复。

---

## 12. 引用来源(全部 2026-06-06 抓取验证)

### Headroom 官方
- [Quickstart](https://headroom-docs.vercel.app/docs/quickstart) — 安装、proxy、alternative proxy mode
- [Installation](https://headroom-docs.vercel.app/docs/installation) — pip/npm/Docker、extras 表、env vars 表
- [Proxy Server](https://headroom-docs.vercel.app/docs/proxy) — `--host/--port/--no-optimize` 等所有 flag、endpoints、`headroom wrap codex`、`OPENAI_BASE_URL` 模式
- [MCP](https://headroom-docs.vercel.app/docs/mcp) — 提到 Codex 是 MCP 客户端之一

### Codex 官方
- [Config basics](https://developers.openai.com/codex/config-basic) — `~/.codex/config.toml` 位置、配置优先级、`[features]` 表(`hooks = true` canonical)
- [Config advanced](https://developers.openai.com/codex/config-advanced) — `model_provider` / `[model_providers.<id>]` schema、reserved IDs、项目级覆盖限制
- [Hooks](https://developers.openai.com/codex/hooks) — `~/.codex/hooks.json` 格式、事件列表、`hooks.json` 完整示例、`codex_hooks` deprecated alias 说明
- [Codex repo docs/config.md](https://github.com/openai/codex/blob/main/docs/config.md) — 指向上面三个页面
- [Codex README](https://github.com/openai/codex) — 安装方式

### Claude Code 官方
- [Environment variables](https://docs.claude.com/en/docs/claude-code/env-vars) — `ANTHROPIC_BASE_URL` 描述("Override the API endpoint to route requests through a proxy or gateway")、`ANTHROPIC_AUTH_TOKEN` 描述(`Authorization: Bearer` 前缀)、`API_TIMEOUT_MS` 默认 600000
- [Settings](https://docs.claude.com/en/docs/claude-code/settings) — `settings.json` 完整字段表
- [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) — 所有 hooks 事件列表和 schema
