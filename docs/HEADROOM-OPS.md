# Headroom 运维手册(本机)

> 本文档聚焦**当前部署状态**和**日常操作**。配置 / 安装 / 概念见姊妹文档 [`HEADROOM.md`](./HEADROOM.md)。
> 最后更新:2026-06-14(0.23.0 → 0.25.0 升级同步)

---

## 0. 当前运行状态总表(一眼看全)

> **一眼能看完的快照**——打开文档先看这张表,有疑问再往下翻。
> 自动化查询:`~/bin/headroom-ctl status`(见 §0.3)。数据来源:`/proc/$PID/environ` + `curl /health` + `curl /stats`。

### 0.1 进程 / 端口 / 版本

| 项 | 当前值 | 备注 |
|---|---|---|
| `headroom --version` | **`0.25.0`** | uv tool 安装 |
| **Proxy PID** | `1458870`(本次 0.25.0 升级后) | `pgrep -f "headroom proxy"` |
| **监听端口** | `127.0.0.1:8787` | `ss -tlnp \| grep 8787` |
| **启动方式** | 裸 `nohup env ... &` | 没装 `~/bin/headroom-up`(见 §0.3) |
| **Uptime** | `~119 min`(`uptime_seconds=7180`) | 随时间增长 |
| **RSS 内存** | `~150 MB` | |
| **Proxy 健康** | `status=healthy, ready=true` | `/health` |
| **Rust core** | `loaded` | onnxruntime 装上即生效 |
| **日志** | `/tmp/headroom-qs2.log` | 旧的 `headroom-proxy*.log` 是历史尝试 |

### 0.2 特性开关(Feature Matrix,真值来自 `/health.config` + cmdline)

| Feature | 当前 | 怎么生效的 | 怎么开 / 关 |
|---|---|---|---|
| **Optimize(压缩)** | ✅ **on** | `headroom proxy` 默认 | — |
| **Cache(语义缓存)** | ✅ on | 默认 | — |
| **Rate Limit** | ✅ on | 默认 | — |
| **Telemetry** | ❌ off | `HEADROOM_TELEMETRY=off` | 删 env 即开 |
| **Code-Aware(AST 压缩)** | ✅ **on** | `headroom-ctl` 默认传 `--code-aware`(2026-06-06 起默认开) | 关:`HEADROOM_CODE_AWARE_ENABLED=0` 写到 `proxy.env`,然后 `headroom-ctl restart`(见 §1.7) |
| **Code-Graph(代码图谱)** | ✅ **on**(默认) | 2026-06-06 起 yaml `features.code_graph: true` + 脚本默认 `1`(索引 cwd + watch files,需 codebase-memory-mcp) | 关:`features.code_graph: false` + restart。跟 Code-Aware 完全不同的 feature(2026-06-06 之前做错:听成 code_aware) |
| **Memory(长程记忆)** | ✅ **on**(默认) | 2026-06-06 起 yaml `features.memory: true` + 脚本默认 `1`(2026-06-06 起) | 关:`features.memory: false` + restart。三写一读模型 + 调用时机见 `HEADROOM.md` §5.6 |
| **`proxy --learn` / TOIN** | 🟢 **默认在用** | `toin_importance=0.25` 默认权重 | 不需要手动开关(见 §1.8) |
| **`headroom learn` CLI** | ❌ 未跑 | 离线分析,跟 proxy 独立 | `headroom learn --apply`(见 §1.8) |
| **HEADROOM_MODE** | `token`(默认) | `HEADROOM_MODE` env 未设,走 `token` | `export HEADROOM_MODE=cache` 切 cache 模式(见 `HEADROOM.md` §0.3) |
| **Subscription tracking** | ❌ off | relay 模式无效 | — |

> **2026-06-06 更新**:`headroom-ctl` 默认启用 Code-Aware(风险评估全 🟢,见 §1.7)。`code_graph` 和 `code_aware` 是 headroom 命名易混点——`code_aware`=AST 压缩,`code_graph`=代码图谱(完全不同的 feature)。

#### 0.2.1 ContentRouter 内部开关(不可配置)

> **重要**:`ContentRouterConfig` 18 个字段在 proxy 0.23.0 启动时**硬编码**,**不可通过 `config.yaml` 覆盖**。本节列出 8 个**最影响实际行为**的字段,供运维排错时查。完整 18 字段表见 `HEADROOM.md §3.1.1`。

| 字段 | 当前默认值 | 实际影响 |
|---|---|---|
| `enable_code_aware` | `False` | AST 压缩**永不被调用**。即便 proxy 启 `--code-aware` 也不调——是**双层 off**(proxy 启 + 内部 disable)。源码注释:`Disabled: use code graph MCP tools instead` |
| `enable_kompress` | `True` | 但因模型缺失(Kompress 148MB ONNX 没下)→ **静默 fallback passthrough** |
| `protect_recent_reads_fraction` | `0.0` | 0.0 = 保护 ALL tool 输出。**Claude 90% tool 不被压的第二重保险**(第一重是 tool 名在 `DEFAULT_EXCLUDE_TOOLS`) |
| `min_ratio_relaxed` / `min_ratio_aggressive` | `0.85` / `0.65` | 压缩比阈值。context 满时压到 65%,空时压到 85%,线性插值 |
| `compress_assistant_text_blocks` | `False` | assistant 自己产出的 text **不被压缩**。这是 prefix cache 0 bust 的**根因**(assistant text 是 cache key,改了会 bust) |
| `DEFAULT_EXCLUDE_TOOLS` | `{Read, Glob, Grep, Write, Edit, Bash}`(含大小写 12 个) | Claude Code 核心工具集**正好命中这 6 个** → ContentRouter 直接 reject,不压缩 |
| `skip_user_messages` | `True` | 用户消息不参与压缩(它们是"分析对象") |
| `enable_image_optimizer` / `enable_html_extractor` | `True` / `True` | 图片 + HTML 压缩默认启,只是 Codex WebSocket 流没碰到这两种 content_type |

**运维常见误判**:
- "为什么启了 `--code-aware` 但 /health.config.code_graph=False?" —— 因为是 `enable_code_aware`(另一个字段),而这个字段是**永 False 的**——见 §1.6.1 详细说明
- "为什么 cache 100% 命中?" —— `compress_assistant_text_blocks=False` 是关键(assistant text 原样 echo),不是"压缩策略没破坏缓存"
- "为什么 Kompress 没工作?" —— 模型没下,看 §4.2 或 proxy log 找 `_load_kompress` 异常

### 0.3 关键命令一行流(`headroom-ctl`)

| 用途 | 命令 | 状态 |
|---|---|---|
| **看状态(三态 + 4 后端槽位)** | `~/bin/headroom-ctl status` | ✅ **已装** |
| **启动**(fork 后立即返回) | `~/bin/headroom-ctl start` | ✅ |
| **阻塞等就绪** | `~/bin/headroom-ctl wait` | ✅ |
| **停止** | `~/bin/headroom-ctl stop` | ✅ |
| **重启** | `~/bin/headroom-ctl restart` | ✅ |
| **看客户端配置提示** | `~/bin/headroom-ctl show-config-hints` | ✅ |
| **看 yaml(脱敏)** | `~/bin/headroom-ctl config-show` | ✅ |
| **改 yaml** | `~/bin/headroom-ctl config-edit` | ✅ |
| **同步到 claude/codex** | `~/bin/headroom-ctl apply` | ✅ |
| **离线学习**(透传) | `~/bin/headroom-ctl learn [--apply] [--project <p>]` | ✅ |
| **长程记忆 CRUD**(透传) | `~/bin/headroom-ctl memory <stats\|list\|search\|add\|remove>` | ✅ |
| **help** | `~/bin/headroom-ctl help` | ✅ |
| 配置文件(唯一真相源) | `~/.config/headroom/config.yaml` | ✅ 已建,chmod 600 |
| ~~`proxy.env`~~ | ~~`~/.config/headroom/proxy.env`~~ | ❌ **已删除**(2026-06-06 决定) |
| `~/.bashrc` alias | `alias hr=~/bin/headroom-ctl` | ❌ 同上(可选) |

### 0.4 上游 / Auth / Env(从 `/proc/$PID/environ`)

| 变量 | 当前值 | 角色 |
|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | `sk-65d7da9c...082`(已脱敏) | proxy 转发给上游的 Bearer |
| `ANTHROPIC_TARGET_API_URL` | `https://api.gotoken.top` | **proxy 上游**(headroom 读) |
| `ANTHROPIC_BASE_URL` | `https://api.gotoken.top` | shell 继承(影响 claude client,**不**影响 proxy) |
| `HEADROOM_TELEMETRY` | `off` | 关匿名统计 |
| `HEADROOM_MODE` | **未设**(走默认 `token`) | 压缩策略: `token`(省) / `cache`(命中),详见 `HEADROOM.md` §0.3 |

> ⚠️ **2026-06-06 docs/源码差异**:官方 [`/docs/installation`](https://headroom-docs.vercel.app/docs/installation) page 列 `HEADROOM_MODE` 默认 = `optimize`(SDK 默认)。本 OPS 写默认 = `token`(proxy 默认)。**两套默认值是独立机制**——proxy 端 `token` / `cache` / legacy aliases,SDK 端 `audit` / `optimize` / `simulate`。docs 没区分清楚这俩,容易误读。详见 `HEADROOM.md §0.3.3` + 诊断报告 §6.3。
| `HF_HUB_DISABLE_XET` | `1` | 绕开 xet(防 SOCKS 慢) |
| `HF_ENDPOINT` | `https://hf-mirror.com` | HF 国内镜像 |
| `ANTHROPIC_MODEL` | `MiniMax-M3[1M]` | 模型名(shell 继承) |
| `http_proxy` / `https_proxy` | `http://192.168.3.74:7897/` | SOCKS 代理(shell 继承) |

> `ANTHROPIC_BASE_URL` vs `ANTHROPIC_TARGET_API_URL` 名字相近但角色不同——`BASE_URL` 给 **claude client** 看(决定它发请求去哪里),`TARGET_API_URL` 给 **headroom proxy** 看(决定 proxy 转发去哪里)。详见 `HEADROOM.md` §0.1。
>
> **`HEADROOM_MODE` 是 proxy 端"压缩策略"开关**。当前未设走默认 `token`(省 token 优先);如果想切 `cache` 优先 prefix 命中率,在 `proxy.env` 加 `export HEADROOM_MODE=cache` 然后 `headroom-ctl restart`。详见 `HEADROOM.md` §0.3。

### 0.5 最近流量(来源 `/stats`)

| 指标 | 当前值 | 备注 |
|---|---|---|
| `api_requests`(总) | `2` | 都是本地验证用 |
| `by_model` | `claude-haiku-4-5: 2` | 验证用模型 |
| `input tokens` | `264` | |
| `output tokens` | `0` | |
| `tokens_saved` | `0` | 内容太短(14/250 tokens),走 `router:protected:user_message` / `router:noop` |
| `latency.avg` | `~15 s` | 第 1 次冷启 27.9 s,第 2 次 0.9 s(参考) |
| `proxy_inbound.total` | `28` | 含 `/health` `×11` `/stats` `×9` `/livez` `×3` 等查询 |
| `cache.hits` / `entries` | `0 / 0` | 还没真流量 |
| `memory.entries` | `0` | memory 未启 |
| `toin.patterns_tracked` | `0` | 还没真流量 |

> **说明**:proxy 起着但**没有真实 LLM 工作流量**。等真正用 `ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude` 启动时,这些数字才会长。

### 0.6 文件 / 数据 / 持久化

| 位置 | 路径 | 状态 |
|---|---|---|
| headroom 二进制 | `/home/stark/.local/bin/headroom` | symlink → uv tool |
| uv venv | `/home/stark/.local/share/uv/tools/headroom-ai/` | ~1 GB |
| Memory DB | `/data/hermes/headroom_memory.db` | 57 KB,0 行(`journal_mode=delete`) |
| HF 模型缓存 | `~/.cache/huggingface/hub/models--chopratejas--kompress-base/` | ~70 MB,已下完 |
| Headroom 全局 | `~/.headroom/` | `deploy/` + `logs/` + `.beacon_lock_8787` |
| 备用 venv(未用) | `/tmp/headroom-env/` | ~3 GB |
| 仓库代码 | `/tmp/headroom/` | chopratejas/headroom @ 26f325f5 |
| 配置文件 | `~/.config/headroom/proxy.env` | ❌ **未创建** |
| 管理脚本 | `~/bin/headroom-ctl` | ❌ **未创建** |
| Claude Code 配置 | `~/.claude/settings.json` | ✅ **未改**(init 半失败时备份到 `~/.claude/settings.json.bak.20260606_152245`) |
| Codex 配置 | `~/.codex/config.toml` | ✅ **未改** |

### 0.7 端点速查

| URL | 用途 | 返回示例 |
|---|---|---|
| `http://127.0.0.1:8787/livez` | 进程在不在 | `{"status":"healthy","alive":true}` |
| `http://127.0.0.1:8787/readyz` | 能接流量 | `{"ready":true, ...checks...}` |
| `http://127.0.0.1:8787/health` | 完整健康 + runtime + config | 见 §1.6 |
| `http://127.0.0.1:8787/stats` | 省钱统计 + 流量 | 见 §1.6 |
| `http://127.0.0.1:8787/metrics` | Prometheus 格式 | — |

---

## 1. 当前实际状态(快照)

> **诚实声明**:`HEADROOM.md` 推荐的 `~/bin/headroom-up` 脚本、`~/.config/headroom/proxy.env`、`.bashrc` alias **目前都没装**。本次部署是直接 `nohup env ... headroom proxy --port 8787 &` 启的。运维命令里两套都给:**当前实际**(裸命令)和**文档推荐**(脚本)。

### 1.1 进程/端口/版本

| 项 | 值 |
|---|---|
| `headroom --version` | `headroom, version 0.23.0` |
| **Proxy PID** | `339355` |
| **监听** | `127.0.0.1:8787` |
| **Uptime** | 5859s ≈ 97 min(随时间增长) |
| **Memory** | ~150 MB RSS |
| **Proxy 健康** | `status=healthy, ready=true` |
| **Rust core** | loaded |
| **upstream** | `https://api.gotoken.top` |

### 1.2 启动方式(本次实际命令)

```bash
# 直接 nohup 启动,没有用脚本
nohup env \
  HF_HUB_DISABLE_XET=1 \
  HF_ENDPOINT=https://hf-mirror.com \
  ANTHROPIC_TARGET_API_URL=https://api.gotoken.top \
  ANTHROPIC_AUTH_TOKEN=sk-65d7da9c6fb7468bedea922e4f6832005f4acdef62681750cb4b8261e32ab082 \
  HEADROOM_TELEMETRY=off \
  headroom proxy --port 8787 \
  > /tmp/headroom-qs2.log 2>&1 &
```

### 1.3 进程 env 关键变量(从 `/proc/339355/environ` 抓取)

```text
ANTHROPIC_AUTH_TOKEN=sk-65d7da9c6fb7468bedea922e4f6832005f4acdef62681750cb4b8261e32ab082
ANTHROPIC_BASE_URL=https://api.gotoken.top                   ← shell 继承
ANTHROPIC_TARGET_API_URL=https://api.gotoken.top             ← headroom 用
ANTHROPIC_MODEL=MiniMax-M3[1M]                                ← shell 继承
ANTHROPIC_DEFAULT_HAIKU_MODEL=MiniMax-M3[1M]
ANTHROPIC_DEFAULT_OPUS_MODEL=MiniMax-M3[1M]
ANTHROPIC_DEFAULT_SONNET_MODEL=MiniMax-M3[1M]
ANTHROPIC_REASONING_MODEL=MiniMax-M3[1M]
HEADROOM_TELEMETRY=off                                       ← 显式传
HF_HUB_DISABLE_XET=1                                          ← 显式传
HF_ENDPOINT=https://hf-mirror.com                            ← 显式传
http_proxy=http://192.168.3.74:7897/                         ← shell 继承
https_proxy=http://192.168.3.74:7897/
```

### 1.4 文件位置

| 文件/目录 | 路径 | 大小 | 备注 |
|---|---|---|---|
| headroom 二进制 | `/home/stark/.local/bin/headroom` | symlink → uv tool | uv tool 安装 |
| uv venv | `/home/stark/.local/share/uv/tools/headroom-ai/` | ~1 GB(含 torch/transformers) | |
| **Proxy log** | `/tmp/headroom-qs2.log` | 2.8 KB | 旧的 `headroom-proxy*.log` 是历史尝试 |
| 备用 venv | `/tmp/headroom-env/` | ~3 GB | 第一次装的位置,目前未用 |
| 仓库代码 | `/tmp/headroom/` | git clone | chopratejas/headroom @ 26f325f5 |
| HF 模型缓存 | `~/.cache/huggingface/hub/models--chopratejas--kompress-base/` | ~70 MB | ONNX kompress-base,首次启时从 hf-mirror 下 |
| Headroom 全局 | `~/.headroom/` | 84 KB | `deploy/` + `logs/` + `.beacon_lock_8787` |
| **Memory DB** | `/data/hermes/headroom_memory.db` | 57 KB | 当前 0 行,`journal_mode=delete` |
| ~~`~/.config/headroom/proxy.env`~~ | — | — | **未创建** |
| ~~`~/bin/headroom-up` 等脚本~~ | — | — | **未创建** |
| ~~`~/.bashrc` alias~~ | — | — | **未配置** |
| **备份** | `~/.claude/settings.json.bak.20260606_152245` | 7.3 KB | init claude 半失败时留的 |

### 1.5 proxy 端点

| URL | 用途 |
|---|---|
| `http://127.0.0.1:8787/livez` | 进程在不在 |
| `http://127.0.0.1:8787/readyz` | 能接流量 |
| `http://127.0.0.1:8787/health` | 完整健康 JSON |
| `http://127.0.0.1:8787/stats` | 省钱统计 |
| `http://127.0.0.1:8787/stats-history` | 历史趋势 |
| `http://127.0.0.1:8787/metrics` | Prometheus 格式 |

### 1.6 配置状态(实际生效的)

> **诚实声明**:`HEADROOM.md` 推荐的"完整配置"(`proxy.env` + 脚本 + alias) **完全没装**。当前是用 **裸 `nohup` + 内联 env 启动** 的"极简配置"。两套的差别见 §3.4。

#### 1.6.1 Feature matrix(以 `/health` 为准)

| Feature | 实际状态 | 怎么生效的 | 来源 |
|---|---|---|---|
| **Optimize(压缩)** | ✅ on | `headroom proxy` 默认行为 | `/health.config.optimize=true` |
| **Cache(语义缓存)** | ✅ on | 默认 | `config.cache=true` |
| **Rate Limit** | ✅ on | 默认 | `config.rate_limit=true` |
| **Memory(长程记忆)** | ❌ **off** | 没传 `--memory` 也没传 `HEADROOM_MEMORY=on` | `/health.checks.memory.enabled=false` |
| **Code-Aware** | ❌ **off** | 没传 `--code-aware` 也没传 `HEADROOM_CODE_AWARE_ENABLED=1` | `/health.config.code_graph=false` |
| **Telemetry** | ❌ off | 显式传 `HEADROOM_TELEMETRY=off` | `/health` summary.telemetry.enabled=false |
| **Learn(失败学习)** | ❌ off | 没传 `--learn` | `config.learn=false` |
| **Subscription tracking** | ❌ off(走 relay 默认) | `config.optimize=true` 隐含;relay 模式下无效 | — |
| **Rust core** | ✅ loaded | `[all]` extra 装了 onnxruntime | `/health.rust_core=loaded` |

> 跟 `HEADROOM.md` §3 "完整配置(推荐)" 的差别:**Memory / Code-Aware 没启**。如果想开,见 §3.4 升级流程。

> **2026-06-06 补(代码层说明)**:上表里 **Code-Aware 写 "off"** 容易让运维误读——Code-Aware 实际上是**双层 off**:
>
> 1. **proxy 层面**(本节表格):`/health.config.code_graph=false` ← `headroom proxy` 没启 `--code-aware` 标志
> 2. **ContentRouter 内部**(更深层):`enable_code_aware: bool = False`(硬编码,见 §0.2.1 + `HEADROOM.md §3.1.1`)
>
> 源码注释明示意图:`Disabled: use code graph MCP tools instead`(意思是"AST 压缩没用,改用 code graph MCP 工具代替")。所以**用户既不需要(也不能)改 `enable_code_aware`**——这是 headroom 0.23.0 的设计选择,不是配置遗漏。
>
> 同样情况:`compress_assistant_text_blocks=False`(硬编码)解释了为什么 prefix cache 0 bust——assistant text 不被压缩,cache key 稳定,命中 100%。

#### 1.6.2 启动参数(实际传给 proxy 的)

```bash
# cat /proc/339355/cmdline 解析:
/home/stark/.local/share/uv/tools/headroom-ai/bin/python3 \
  /home/stark/.local/bin/headroom proxy \
  --port 8787        # ← 唯一显式参数
```

**所有其他能力靠 env 变量或默认行为**:
- `--memory` ❌ 没传 → memory 实际 off
- `--code-aware` ❌ 没传 → code_aware off
- `--no-telemetry` ❌ 没传 → 但 `HEADROOM_TELEMETRY=off` env 生效,行为等价
- `--no-optimize` ❌ 没传 → optimize on(默认)

#### 1.6.3 完整 env(从 `/proc/339355/environ`)

| 变量 | 值 | 角色 | 谁传的 |
|---|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | `sk-65d7da9c6fb7468bedea922e4f6832005f4acdef62681750cb4b8261e32ab082` | proxy 转发给上游的 Bearer | headroom-up nohup |
| `ANTHROPIC_BASE_URL` | `https://api.gotoken.top` | shell 继承(不影响 proxy,影响 claude 走哪) | shell rc |
| `ANTHROPIC_TARGET_API_URL` | `https://api.gotoken.top` | **proxy 上游** | headroom-up nohup |
| `ANTHROPIC_MODEL` | `MiniMax-M3[1M]` | 模型名(MiniMax 中转模型) | shell rc |
| `ANTHROPIC_DEFAULT_HAIKU/OPUS/SONNET_MODEL` | `MiniMax-M3[1M]` | 模型 fallback | shell rc |
| `ANTHROPIC_REASONING_MODEL` | `MiniMax-M3[1M]` | 推理模型 | shell rc |
| `HEADROOM_TELEMETRY` | `off` | 关匿名统计 | headroom-up nohup |
| `HF_HUB_DISABLE_XET` | `1` | 绕开 xet(防 SOCKS 慢) | headroom-up nohup |
| `HF_ENDPOINT` | `https://hf-mirror.com` | HF 国内镜像 | headroom-up nohup |
| `http_proxy` / `https_proxy` | `http://192.168.3.74:7897/` | SOCKS 代理(出网用) | shell rc |

**注意 `ANTHROPIC_BASE_URL` 跟 `ANTHROPIC_TARGET_API_URL` 名字相近但角色不同**:
- `ANTHROPIC_BASE_URL` 是给 **claude client** 看的(写进 settings.json 或启动 env,告诉它往哪发请求)
- `ANTHROPIC_TARGET_API_URL` 是给 **headroom proxy** 看的(告诉 proxy 转发给谁)

详见 `HEADROOM.md` §0.1。

#### 1.6.4 数据流图

```
                          ┌──────────────────┐
   shell 继承的 env       │   HEADROOM PROXY │
   ┌────────────────┐     │   PID 339355     │
   │ ANTHROPIC_*    │     │   port 127.0.0.1:│
   │ (MODEL, BASE_URL│    │   8787           │
   │  等)            │     │                  │
   │ http_proxy →   │     │  optimize=ON     │
   │  192.168.3.74:7897     │  cache=ON     │
   └────────┬───────┘     │  rate_limit=ON  │
            │             │  memory=OFF     │
            │             │  code_aware=OFF │
            │             │  telemetry=OFF   │
            ▼             └────────┬─────────┘
   ┌─────────────────┐            │ ANTHROPIC_TARGET_API_URL
   │ claude client   │            │ + ANTHROPIC_AUTH_TOKEN
   │ (未来)          │────────────┤
   │ ANTHROPIC_BASE_URL=         │
   │ http://127.0.0.1:8787       │
   │   claude 启动时设            │
   └─────────────────┘            │
                                  ▼
                          ┌──────────────────┐
                          │ gotoken.top      │
                          │ https://api.gotoken.top
                          │ (Bearer sk-65d7da...)
                          └──────────────────┘
                                  │
                                  │ 出网走
                                  ▼
                          ┌──────────────────┐
                          │ MiniMax M3 模型  │
                          │ (Anthropic 兼容) │
                          └──────────────────┘
```

**当前没有 `claude client` 主动连 proxy**——proxy 起着但**没有流量**(api_requests=0)。这是部署**就绪**状态,等真正用 `ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude` 时才有流量。

#### 1.6.5 配置文件 & 持久化设置

| 位置 | 是否有 | 备注 |
|---|---|---|
| `~/.config/headroom/proxy.env` | ❌ 没有 | 文档推荐但未装,见 §3.4 |
| `~/bin/headroom-up` | ❌ 没有 | 同上 |
| `~/bin/headroom-down` | ❌ 没有 | 同上 |
| `~/bin/headroom-status` | ❌ 没有 | 同上 |
| `~/.bashrc` headroom alias | ❌ 没有 | 同上 |
| `~/.claude/settings.json` | ✅ **未改** | 头room init 没成功,备份在 `~/.claude/settings.json.bak.20260606_152245` |
| `~/.codex/config.toml` | ✅ **未改** | 从未跑过 `headroom init codex` |
| `~/.headroom/` 全局目录 | ✅ 有 | `deploy/` + `logs/` + `.beacon_lock_8787` |
| `~/.cache/huggingface/` | ✅ 有 | kompress-base 模型已下完 |
| `/data/hermes/headroom_memory.db` | ✅ 有,空 | memory 未启用所以 0 行 |

**配置管理方式**:本部署是**纯 env + 启动命令**,没有文件化配置。要改 token / 上游 / 端口,见 §3。

#### 1.6.6 升级到"完整配置"的影响范围

走 §3.4 升级流程会:
- 创建 3 个新文件(`proxy.env` + 3 个脚本)
- 在 `.bashrc` 加 7 行 alias
- 不影响:`~/.claude/settings.json`、`~/.codex/config.toml`、memory DB、HF 缓存
- **会停掉当前 PID 339355**(`headroom-up` 会 `pkill` 旧进程)然后用脚本重启

**降级**回裸 nohup:把脚本删了,直接 `nohup env ... &`。

---

### 1.7 Code-Aware 选型说明

> **状态**:**未启用**(`config.code_graph=false`),但**不是技术阻碍**,详见下文。

#### 1.7.1 为什么没启用(诚实回答)

| 检查项 | 结果 |
|---|---|
| 依赖 `tree_sitter` | ✅ 已装(`/home/stark/.local/share/uv/tools/headroom-ai/lib/python3.13/site-packages/tree_sitter/`) |
| 依赖 `tree_sitter_language_pack` | ✅ 已装 |
| 启动命令含 `--code-aware` 标志 | ❌ 没传 |
| env 含 `HEADROOM_CODE_AWARE_ENABLED=1` | ❌ 没设 |
| proxy `/health.config.code_graph` | `false` |

**真相**:Code-Aware 是**纯本地**的 tree-sitter AST 解析,只动压缩,不影响 API 调用。**没有任何 gotoken 兼容性、性能、依赖问题**。纯粹是初次 nohup 启动时**我忘了加这个 flag**(`HEADROOM.md` §3 的"完整配置"里有,但裸 nohup 命令里没传)。

#### 1.7.2 官方对 Code-Aware 的描述

来源:[Headroom Installation docs](https://headroom-docs.vercel.app/docs/installation) (2026-06-06 抓取):

> | `code` | CodeCompressor (tree-sitter AST parsing) | `pip install "headroom-ai[code]"` |

来源:[Headroom Quickstart docs](https://headroom-docs.vercel.app/docs/quickstart):

> | Source code | CodeCompressor | 40-70% |

#### 1.7.3 开了能多省什么(典型值)

| Content type | 压缩器 | 典型节省 |
|---|---|---|
| 源码 | **CodeCompressor**(tree-sitter AST) | 40-70% |
| JSON 数组 | SmartCrusher | 70-90% |
| Build/test 日志 | LogCompressor | 80-95% |
| 搜索结果 | SearchCompressor | 60-80% |
| 普通文本 | Kompress | 30-50% |

**判断**:工具结果多含源码/JSON/堆栈跟踪(典型 LLM agent 工作流) → **开**;工具结果都是短文本 → **无所谓**。

#### 1.7.4 怎么开

```bash
# 选 1:加 env
pkill -f "headroom proxy" && sleep 2
nohup env ...(其他 env)... HEADROOM_CODE_AWARE_ENABLED=1 \
  headroom proxy --port 8787 > /tmp/headroom.log 2>&1 &

# 选 2:加 CLI 标志(等价)
pkill -f "headroom proxy" && sleep 2
nohup env ...(其他 env)... \
  headroom proxy --port 8787 --code-aware > /tmp/headroom.log 2>&1 &

# 验
curl -sS http://127.0.0.1:8787/health | python3 -c "
import json, sys
print('code_graph =', json.load(sys.stdin)['config']['code_graph'])
"
# 期望:code_graph = True
```

#### 1.7.5 风险评估

| 风险 | 评估 | 备注 |
|---|---|---|
| 性能开销 | 🟢 极低 | tree-sitter 是 C 写的,几毫秒级,不可感知 |
| gotoken 兼容 | 🟢 无影响 | 压缩在 proxy 内部完成,API 协议不变 |
| 压缩质量 | 🟡 偶尔过度 | 罕见:某些 JSON 套娃被压掉后大模型理解错(可回退单次请求用 `x-headroom-bypass: true`) |
| 启动时间 | 🟢 无影响 | 不像 LLMLingua 要装 torch(2 GB),`[code]` extra 体积小 |
| 内存 | 🟢 低 | tree-sitter 几个 MB,不影响 RSS |

**结论**:**纯收益 feature,开它没成本**。本手册推荐 `HEADROOM.md` §3 的完整配置里就是默认开的。

---

### 1.7a Code-Graph(代码图谱 intelligence)选型说明

> **2026-06-06 修正**:之前混淆了 `code_aware` 和 `code_graph`——用户原话是"启动脚本默认要开启 code_graph",我**听错**做成了 `code_aware`。本节澄清两个 feature 的根本区别。

#### 1.7a.1 本质区别(关键)

| 维度 | **Code-Aware**(AST 压缩) | **Code-Graph**(代码图谱) |
|---|---|---|
| **做什么** | 解析 tool result 里的代码,压成 AST 摘要 | 索引**整个项目**,建图谱,持续 watch 文件变化 |
| **作用对象** | 单条 tool result | **整个 cwd** |
| **运行模式** | 请求时按需解析(轻) | **启动时索引 + 持续 watch**(重) |
| **依赖** | `headroom-ai[code]`(tree-sitter) | `codebase-memory-mcp`(MCP server) |
| **CLI 标志** | `--code-aware` | `--code-graph` |
| **健康字段** | `config.code_aware`(间接,cmdline 标志) | `config.code_graph` |
| **副作用** | 几乎无 | 启动慢 + 持续 I/O + 占内存(索引整个项目) |
| **官方默认** | ❌ off | ❌ off |
| **本部署默认** | ✅ on(2026-06-06 起) | ✅ on(2026-06-06 起,用户原话) |

#### 1.7a.2 Code-Graph 启用条件(官方要求)

来源:`headroom proxy --help` (2026-06-06 抓取):

> `--code-graph   Enable code graph intelligence: indexes the current working
>                 directory and watches files for live reindex via
>                 codebase-memory-mcp. **Only useful when the proxy is launched
>                 from a project root.**`

3 个条件缺一不可:
1. `codebase-memory-mcp` 装上(本部署 ✅ 在 uv tool venv)
2. proxy 启的 cwd 是**项目根**(本部署 ✅ cwd=/data/hermes)
3. `features.code_graph: true`(本部署 ✅)

#### 1.7a.3 当前实际状态(本机)

| 检查项 | 结果 |
|---|---|
| `codebase-memory-mcp` 可执行 | ✅ `/home/stark/.local/share/uv/tools/headroom-ai/bin/codebase-memory-mcp` |
| 启动 cmdline 含 `--code-graph` | ❌ **没传** ← 之前是 `code_aware` 不是 `code_graph` |
| `/health.config.code_graph` | `false` |
| yaml `features.code_graph` | `true`(2026-06-06 改完) |
| 脚本默认 `ENABLE_CODE_GRAPH` | `1`(2026-06-06 改完) |

**所以下次 `headroom-ctl restart` 才会真的启** code_graph。

#### 1.7a.4 风险评估(2026-06-06 拍板默认开)

| 风险 | 评估 | 备注 |
|---|---|---|
| 性能开销(启动) | 🟡 中 | 首次启要索引整个 `/data/hermes`,大项目可能 +10-30s 启动延迟 |
| 持续 CPU/IO | 🟡 中 | watch files 会持续消耗磁盘 I/O |
| 内存 | 🟡 中 | 索引整个项目,大项目可能 +100-500MB |
| gotoken 兼容 | 🟢 无影响 | code_graph 是本地操作,不动 API 协议 |
| 行为变化 | 🟢 无 | 跟 `code_aware` 不同,启了不会改压缩行为;只让 MCP 客户端能 query 项目结构 |
| 误启 cost | 🟡 中 | cwd 不是项目根时启 = 索引杂目录 + 持续 watch 杂文件 = 浪费 |

**结论**:**本部署 cwd 是项目根(满足条件),副作用可接受**。但用户应该知道"启了会持续 watch"这件事,出问题关。

#### 1.7a.5 想关?

```bash
# 临时
HEADROOM_CODE_GRAPH=0 headroom-ctl restart

# 持久
headroom-ctl config-edit   # features.code_graph: false
headroom-ctl restart
```

#### 1.7a.6 跟 Code-Aware 不冲突(可同时开)

- `code_aware` = 改"压缩 tool result" 的行为
- `code_graph` = 让 MCP 客户端能 query 项目结构
- 两者作用**完全独立**,可同时开
- 本部署 2026-06-06 起**两个都默认开**

---

### 1.8 Learn(失败学习)选型说明

> **状态**:本节**修正 §1.8 初稿的误解**——Learn **不是** proxy 的运行时 feature,而是**独立的 CLI 子命令**。官方原文已抓取确认(2026-06-06)。

#### 1.8.1 重要:Learn 是什么(官方原文)

来源:[Headroom Failure Learning 官方页](https://headroom-docs.vercel.app/docs/failure-learning) (2026-06-06 抓取):

> "**Offline failure analysis for coding agents.** Analyzes past sessions, finds what went wrong, correlates with what fixed it, and writes project-level learnings."
>
> ```bash
> # See recommendations for current project (dry-run, no changes)
> headroom learn
>
> # Write recommendations to CLAUDE.md and MEMORY.md
> headroom learn --apply
>
> headroom learn --project ~/my-project --apply
> headroom learn --all --apply
> ```

**Learn 是 `headroom learn` CLI 子命令**,跟 `headroom proxy` 是两套独立机制:
1. **离线**分析 coding agent 过去的 session
2. 找到"什么失败过 + 最后怎么修好的"
3. 写**项目级**学习建议到 `CLAUDE.md` 和 `MEMORY.md`

**官方例子**(原文):模型老猜错文件路径,learn 会发现"A 路径找不到,但 B 路径可以"并写下来。

#### 1.8.2 跟 proxy 完全无关(常见误解)

| 误解 | 真相 |
|---|---|
| "Learn = `headroom proxy --learn` 标志" | ❌ **不对**。`headroom proxy --learn` 是另一回事(下文 1.8.7) |
| "Learn 让 proxy 自动避错" | ❌ Learn 跟 proxy 是**两套独立机制**。Learn 改的是 agent 行为(写 CLAUDE.md),proxy 改的是 API 调用 |
| "开了 Learn 就不用 TOIN" | ❌ TOIN 是 proxy 内部的 scoring 机制(默认在用),跟 Learn 是两回事 |

#### 1.8.3 当前实际状态

| 检查项 | 结果 |
|---|---|
| proxy `/health.config.learn` | `false`(没传 `--learn`) |
| proxy `/stats.summary.toin` | `{}` 空 |
| 跑过 `headroom learn` | ❌ **从未跑过** |
| `CLAUDE.md` / `MEMORY.md` 里的 learn 小节 | ❌ 没有(learn 写的话会有 `## File Path Corrections` / `## Command Patterns` / `## Environment Facts` 等小节) |
| 本项目 `CLAUDE.md` | 是项目用文档,**不是** agent memory 文件。learn 默认找 `CLAUDE.md`,可能因为本项目结构不标准(用 `AGENTS.md` 不用 `CLAUDE.md`?)而不识别 |

#### 1.8.4 什么时候用 Learn

✅ **适合**:
- 同一个项目跑了一周以上,积累了多次失败
- 想要"沉淀到 CLAUDE.md,下次 session 自动用"
- 离线分析(不打断当前工作)

❌ **不适合**:
- 短跑 / 新项目 / 没失败历史
- 想"立刻生效"——Learn 是**写文件**而不是实时干预

#### 1.8.5 怎么用(决策后再用)

```bash
# 1. 看建议(dry-run,不写文件)
cd /data/hermes
headroom learn

# 2. 应用:写 CLAUDE.md 和 MEMORY.md
headroom learn --apply

# 3. 指定项目
headroom learn --project /path/to/project --apply

# 4. 所有项目
headroom learn --all --apply

# 5. 验证(看 CLAUDE.md 是否多出 learn 写入的小节)
grep -A5 "## File Path Corrections\|## Command Patterns\|## Environment Facts" CLAUDE.md MEMORY.md 2>/dev/null
```

#### 1.8.6 Learn 写到哪里(官方示例)

Learn 会**追加**而不是覆盖到 `CLAUDE.md`:

```markdown
### Environment
- **Python**: use `uv run python` (not `python3` -- modules not available outside venv)

### File Path Corrections
- `axion-common/src/.../AxionSparkConstants.scala`
  -> actually at `axion-spark-common/src/.../AxionSparkConstants.scala`

### Search Scope
- Don't search `axion-model/` -> use `axion/` (the repo root)
```

> **注意**:本部署的 `docs/HEADROOM.md` 和 `docs/HEADROOM-OPS.md` 是**用户写的文档**,**不会**被 learn 改写。learn 目标文件是项目根的 `CLAUDE.md` 和 `MEMORY.md`,跟本手册的 `docs/` 子目录无关。

#### 1.8.7 跟 TOIN / proxy `--learn` 的关系(防止再次混淆)

| 名字 | 类型 | 做什么 | 当前状态 |
|---|---|---|---|
| **`headroom learn`** | CLI 子命令 | 离线分析 → 写 CLAUDE.md | ❌ 未跑过 |
| **`headroom proxy --learn`** | proxy 启动标志 | 启用 TOIN scoring(用过去 pattern 调 compression) | ❌ 未传 |
| **TOIN**(Tool Optimization through Inference Networks) | proxy 内部的 scoring 机制 | 每次请求时根据历史 pattern 调重要度评分 | ✅ **默认在用**(IntelligentContext 的一部分) |
| **proxy `/stats.summary.toin`** | 状态查询字段 | 看 TOIN 收集了多少 pattern | `{}` 空(没数据) |

`★ Insight ─────────────────────────────────────`
**三套机制的对比**:
- `proxy --learn` = 启用 TOIN scoring(proxy 决策,运行中)
- `headroom learn` = 写 CLAUDE.md(agent 决策,离线)
- `IntelligentContext` 里的 `toin_importance=0.25` 权重 = TOIN 已经在默认评分公式里
- 它们**名字都带 learn** 但**作用域完全不同**,我之前 §1.8 初稿把它们全混在一起了
`─────────────────────────────────────────────────`

#### 1.8.8 决策

| 选型 | 结论 |
|---|---|
| **要不要跑 `headroom learn`?** | ⚠️ 视项目:长期/有失败案例 → 跑一次;新项目/没失败 → 不急 |
| **要不要启 `headroom proxy --learn`?** | 🟢 跟 Learn CLI 不是一个东西。`--learn` 是启用 TOIN scoring,**默认已经在用**(toin_importance=0.25),不需要单独开关 |
| **本部署建议** | **不跑** `headroom learn`(项目新、数据不够);**不传** `proxy --learn`(TOIN 默认在) |

---

### 1.9 完整 feature 决策矩阵

把 §1.6 / §1.7 / §1.8 汇总成决策表(**修正后版本,区分三套 Learn 机制**):

| Feature | 当前 | 推荐 | 风险 | 何时开 |
|---|---|---|---|---|
| **Optimize** | ✅ on | ✅ on | 🟢 极低 | 始终 |
| **Cache** | ✅ on | ✅ on | 🟢 低 | 始终 |
| **Rate Limit** | ✅ on | ✅ on | 🟢 低 | 始终 |
| **Telemetry** | ❌ off | ❌ off | 🟢 无 | 默认关(隐私) |
| **Code-Aware** | ❌ off | ✅ **建议开** | 🟢 极低 | 工具结果多源码/JSON 时(§1.7) |
| **Code-Graph** | ❌ off | ✅ on(默认) | 🟡 中 | 索引项目 + watch files,需从项目根启 + mcp 装上(§1.7a) |
| **Memory** | ✅ on(默认) | ✅ on(默认) | 🟢 极低 | 跨 session 复用 facts;DB 空时零开销。三写一读 + 调用时机见 `HEADROOM.md` §5.6 |
| **HEADROOM_MODE** | `token` | `token` | 🟢 无 | 默认即可;想 prefix cache 命中最大化时改 `cache`(见 `HEADROOM.md` §0.3) |
| **`headroom learn` CLI** | ❌ 未跑 | ⚠️ 视项目 | 🟡 中 | 长期项目 + 有失败历史(§1.8) |
| **`proxy --learn` / TOIN** | 🟢 **默认在用** | 🟢 默认即可 | 🟢 无 | 不需要手动开关 |
| **Subscription tracking** | ❌ off | ❌ off | 🟢 无 | relay 模式无效 |

**一键"对齐 HEADROOM.md 推荐"**(开 Code-Aware,其余不动):

```bash
pkill -f "headroom proxy" && sleep 2
nohup env \
  HF_HUB_DISABLE_XET=1 HF_ENDPOINT=https://hf-mirror.com \
  ANTHROPIC_TARGET_API_URL=https://api.gotoken.top \
  ANTHROPIC_AUTH_TOKEN=<token> \
  HEADROOM_TELEMETRY=off \
  HEADROOM_CODE_AWARE_ENABLED=1 \
  headroom proxy --port 8787 --code-aware > /tmp/headroom.log 2>&1 &

# 验
curl -sS http://127.0.0.1:8787/health | python3 -c "
import json, sys
c = json.load(sys.stdin)['config']
print(f'optimize={c[\"optimize\"]} cache={c[\"cache\"]} code_graph={c[\"code_graph\"]} memory={c[\"memory\"]} learn={c[\"learn\"]}')
"
# 期望:optimize=True cache=True code_graph=True memory=False learn=False
#  (learn 在 config 里是 proxy 启用 TOIN scoring 标志,不影响 headroom learn CLI)
```

**额外:跑一次 learn CLI 离线分析**(可选,本项目评估后决定):

```bash
cd /data/hermes
headroom learn                 # dry-run
headroom learn --apply         # 满意就 apply(写 CLAUDE.md)
```

---

### 1.10 Claude Code + Codex 多上游路由(同时支持)

> **2026-06-06 补**:用户问"headroom 是否同时支持 claude code 和 codex(因为他们用不同上游)"。答案:**支持,而且是设计目的**——headroom proxy 是**单端口多后端**架构,按请求路径路由到不同 upstream。

#### 1.10.1 路径 → 后端路由表(从启动 banner + 源码 `proxy/server.py` 验证)

| 请求路径 | 对应后端 | env 变量(本 proxy 读) | 客户端 |
|---|---|---|---|
| `/v1/messages` | **Anthropic** | `ANTHROPIC_TARGET_API_URL` | **Claude Code** |
| `/v1/chat/completions` | **OpenAI** | `OPENAI_TARGET_API_URL` | Codex / Cursor / 任何 OpenAI SDK |
| `/v1/responses` | **OpenAI** | `OPENAI_TARGET_API_URL` | Codex(OpenAI Responses API) |
| `/v1internal:streamGenerateContent` | **Cloud Code Assist** | `CLOUDCODE_TARGET_API_URL` | Gemini CLI(走 Cloud Code 兼容层) |
| (Gemini 直连) | **Gemini** | `GEMINI_TARGET_API_URL` | Google AI Studio / Vertex |

**当前 proxy 启动 banner 截取**(2026-06-06 18:34):

```
Routing:
  /v1/messages                    → https://api.gotoken.top
  /v1/chat/completions            → https://api.openai.com
  /v1/responses                   → https://api.openai.com  (HTTP + WebSocket)
  /v1internal:streamGenerateContent → https://cloudcode-pa.googleapis.com
```

> **看出啥**:只设了 `ANTHROPIC_TARGET_API_URL=gotoken.top`,其他 3 个走**官方默认**(`api.openai.com` / `cloudcode-pa.googleapis.com`)。**这就是最常见的"只用 gotoken 跑 claude,codex 默认走 openai" 配置**。

#### 1.10.2 4 个后端 URL 详解(从 `/health.config` 验证)

```bash
$ curl -sS http://127.0.0.1:8787/health | python3 -c "import json,sys; print(json.load(sys.stdin)['config'])"
{
  "backend": "anthropic",
  "anthropic_api_url": "https://api.gotoken.top",  ← 设了
  "openai_api_url": null,                          ← 未设
  "gemini_api_url": null,                          ← 未设
  "cloudcode_api_url": null,                       ← 未设
  ...
}
```

**注意 `backend: "anthropic"`**——这是 `--backend` 参数(proxy 主后端),不是 upstream URL。`backend` 决定**协议族**(`anthropic`/`bedrock`/`openrouter`/`anyllm`/`litellm-*`),upstream URL 决定**目标地址**。两件事独立。

#### 1.10.3 3 种常见配置场景

##### 场景 A:只跑 Claude Code(当前部署)

```bash
# proxy.env
export ANTHROPIC_TARGET_API_URL=https://api.gotoken.top
export ANTHROPIC_AUTH_TOKEN=sk-...
# 其他 3 个不设 → 走官方默认(本部署 codex 即使能跑,也会被路由到 api.openai.com,需要真 OpenAI key)
```

启动 claude:
```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude
```

codex 如果不小心启动:
```bash
OPENAI_BASE_URL=http://127.0.0.1:8787/v1 codex
# 会请求 /v1/responses → OPENAI_TARGET_API_URL(=None)→ fallback 到 https://api.openai.com
# 需要 OPENAI_API_KEY=sk-... (真 OpenAI key,不是 gotoken 的)
```

##### 场景 B:Claude Code + Codex 都用同一个 relay(gotoken 兼容 OpenAI)

```bash
# proxy.env
export ANTHROPIC_TARGET_API_URL=https://api.gotoken.top
export ANTHROPIC_AUTH_TOKEN=sk-gotoken-...
export OPENAI_TARGET_API_URL=https://api.gotoken.top    # ← 关键:codex 也指 gotoken
export OPENAI_API_KEY=sk-gotoken-...                     # 同一个 token 或 codex 专用 token
```

启动:
```bash
# Claude Code
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ANTHROPIC_AUTH_TOKEN=sk-gotoken-... claude

# Codex
OPENAI_BASE_URL=http://127.0.0.1:8787/v1 OPENAI_API_KEY=sk-gotoken-... codex
```

> **前提**:gotoken 必须是 **Anthropic + OpenAI 双协议**兼容的 relay。可以先 `curl https://api.gotoken.top/v1/models -H "Authorization: Bearer sk-..."` 测试。

##### 场景 C:Claude Code 用 gotoken,Codex 用真 OpenAI(完全隔离)

```bash
# proxy.env
export ANTHROPIC_TARGET_API_URL=https://api.gotoken.top
export ANTHROPIC_AUTH_TOKEN=sk-gotoken-...
# openai 故意不设
export OPENAI_API_KEY=sk-openai-...   # 客户端带真 OpenAI key,proxy 原样转发
```

启动 codex(带真 OpenAI key):
```bash
OPENAI_BASE_URL=http://127.0.0.1:8787/v1 OPENAI_API_KEY=sk-openai-... codex
# 请求路径:/v1/responses → https://api.openai.com(默认)+ Bearer sk-openai-...
```

> **安全考虑**:Codex 流量会**真打到 OpenAI 官方**,不是 gotoken。需要:
> - 客户端有真 OpenAI 账号
> - 接受"codex 不省钱、走 OpenAI 原价"
> - **Tool 结果被 headroom 压缩**(省钱仍在,只是付 OpenAI 原价)

#### 1.10.4 token 传递规则(关键!)

> 跟 §0.1 强调的"token 角色"是同一套:

| 变量 | 谁读 | 何时传给 proxy |
|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | proxy(转发到 `ANTHROPIC_TARGET_API_URL`) | **Claude Code 启动时设**(`ANTHROPIC_AUTH_TOKEN=...`) |
| `OPENAI_API_KEY` | proxy(转发到 `OPENAI_TARGET_API_URL`) | **Codex 启动时设**(`OPENAI_API_KEY=...`) |
| `GOOGLE_API_KEY` | proxy(转发到 `GEMINI_TARGET_API_URL` / `CLOUDCODE_TARGET_API_URL`) | **Gemini CLI 启动时设** |

> **关键**:proxy **不存**这些 token,只是**原样转发** client 发来的 `Authorization` header。所以**改 token 不用重启 proxy**——client 端换新 token 重连即可。
>
> 例外:**proxy 自己启动时如果 `ANTHROPIC_AUTH_TOKEN` 在 env 里,proxy 会用作"fallback"**(某些场景下 proxy 自己调 upstream)。这是 gotoken 这种 relay 模式才需要——proxy 用同一个 token 转发到 relay。

#### 1.10.5 当前部署状态

| 后端 | URL | 怎么设的 | 当前行为 |
|---|---|---|---|
| Anthropic | `https://api.gotoken.top` | `ANTHROPIC_TARGET_API_URL` env | ✅ Claude Code 流量走这 |
| OpenAI | `(未设)` | 无 env | ⚠️ Codex 即使能启动,会走 `https://api.openai.com` + 需真 OpenAI key |
| Gemini | `(未设)` | 无 env | ❌ Gemini CLI 流量会走默认 `cloudcode-pa.googleapis.com` |
| Cloud Code | `(未设)` | 无 env | 同上,跟 Gemini 共享 cloudcode 后端 |

**当前能跑什么**:
- ✅ **Claude Code**(已验证)→ gotoken.top
- ⚠️ **Codex** 理论上能跑(路径 `/v1/responses` 在路由表),但需要:
  1. `OPENAI_TARGET_API_URL` 指向你想要的(或不设走默认)
  2. 客户端带合适的 `OPENAI_API_KEY`
- ❌ **Gemini** 未测,需要单独设 `GEMINI_TARGET_API_URL` 或 `CLOUDCODE_TARGET_API_URL`

**想 3 个全跑起来?** 在 `proxy.env` 加上:
```bash
export ANTHROPIC_TARGET_API_URL=https://api.gotoken.top
export ANTHROPIC_AUTH_TOKEN=sk-gotoken-...
export OPENAI_TARGET_API_URL=https://api.openai.top    # 或其他 OpenAI 兼容
export OPENAI_API_KEY=sk-...
export GEMINI_TARGET_API_URL=https://generativelanguage.googleapis.com
export GOOGLE_API_KEY=AIza-...
```

#### 1.10.6 验证同时跑通(本部署可做)

```bash
# 同时启两个 client
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN \
  claude -p "ping from claude" &

OPENAI_BASE_URL=http://127.0.0.1:8787/v1 OPENAI_API_KEY=$OPENAI_API_KEY \
  codex -p "ping from codex" &

# 看 stats
curl -sS http://127.0.0.1:8787/stats | python3 -c "
import json, sys
d = json.load(sys.stdin)
rq = d['requests']
print('by_model:', rq.get('by_model'))
print('by_provider:', rq.get('by_provider'))
"
# 期望:by_provider={'anthropic': N, 'openai': M}
```

#### 1.10.7 跟 gotoken 兼容性的注脚

> **gotoken(top) 文档**(如果可查)会列出支持的协议。当前 setup 只走 Anthropic 协议——**`/v1/messages` 路径**。如果 gotoken 也支持 OpenAI 协议(很多 relay 都支持),设 `OPENAI_TARGET_API_URL=https://api.gotoken.top` + 同一个 token 即可。
>
> 本部署**未测** gotoken 的 OpenAI 协议兼容性——如果要走场景 B,**先 curl 测试**:
> ```bash
> curl -sS https://api.gotoken.top/v1/models -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" | head -5
> # 期望:返回 models 列表(OpenAI 协议)或 404(只支持 Anthropic)
> ```

---

## 2. 日常操作(主:`headroom-ctl`,备:裸命令)

> **2026-06-06 已装** `/home/stark/bin/headroom-ctl`(15.9 KB,11 个子命令:9 个本地 + 2 个透传到 `headroom learn` / `headroom memory`)。本节以脚本为主,裸命令作为对照参考。

### 2.1 看状态

**推荐**(`headroom-ctl status`):
```bash
~/bin/headroom-ctl status
# 输出三态(根据 PID 和 /health 自动判断):
#   ✘ 未运行  — 没 PID
#   ⏳ 启动中 — PID 在但 /health 暂不可达(模型/ONNX 加载中,通常 5-15s)
#   ✓ 运行中 — PID 在 + /health.ready=true
# 还显示:4 个后端槽位(anthropic/openai/gemini/cloudcode)+ 特性/流量/其它 env
```

**备选**(裸命令,排查时用):
```bash
# 1. 进程在不在
pgrep -f "headroom proxy" && pgrep -af "headroom proxy"

# 2. 端口在不在
ss -tlnp | grep 8787

# 3. 一行综合(quick status)
curl -sS http://127.0.0.1:8787/health | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'status={d[\"status\"]} uptime={d[\"uptime_seconds\"]:.0f}s upstream={d[\"config\"][\"anthropic_api_url\"]}')
print(f'features: optimize={d[\"config\"][\"optimize\"]} cache={d[\"config\"][\"cache\"]} memory={d[\"config\"][\"memory\"]} code_aware={d[\"config\"][\"code_graph\"]}')
"
```

### 2.2 启 / 停 / 重启

**推荐**(`headroom-ctl`):
```bash
# 启(脚本读 shell env 的 ANTHROPIC_AUTH_TOKEN,启动后立即返回)
export ANTHROPIC_AUTH_TOKEN=sk-...   # 一次
~/bin/headroom-ctl start

# 想等就绪?start 不会等(避免日志在终端蹦),用 wait 阻塞
~/bin/headroom-ctl wait
# → 阻塞等 /readyz=true,5s 报一次进度,最久 120s

# 停(优雅 TERM,5s 后 KILL)
~/bin/headroom-ctl stop

# 重启(stop + start)
~/bin/headroom-ctl restart
```

**备选**(裸命令,排查 / 特殊场景):
```bash
# 启
nohup env \
  HF_HUB_DISABLE_XET=1 HF_ENDPOINT=https://hf-mirror.com \
  ANTHROPIC_TARGET_API_URL=https://api.gotoken.top \
  ANTHROPIC_AUTH_TOKEN=<your-token> \
  HEADROOM_TELEMETRY=off \
  headroom proxy --port 8787 \
  > /tmp/headroom.log 2>&1 &

# 停
pkill -f "headroom proxy"

# 强杀(有 in-flight 请求会断)
pkill -9 -f "headroom proxy"

# 重启
pkill -f "headroom proxy" && sleep 2 && <用上面的启命令>
```

### 2.3 看 log

```bash
# 实时
tail -f /tmp/headroom-qs2.log

# 最近 50 行
tail -50 /tmp/headroom-qs2.log

# 看错误(过滤 WARNING/ERROR)
grep -E "WARN|ERROR|Exception|Traceback" /tmp/headroom-qs2.log | tail -20
```

### 2.4 看省钱 / 性能

```bash
# 一句话
curl -sS http://127.0.0.1:8787/stats | python3 -c "
import json, sys
d = json.load(sys.stdin)['summary']
r = d['requests']; t = d['tokens']; c = d['cost']
print(f'requests: {r[\"total\"]}  failed: {r[\"failed\"]}  cached: {r[\"cached\"]}')
print(f'tokens:   {t[\"input\"]:,} in + {t[\"output\"]:,} out')
print(f'saved:    {t[\"saved\"]:,} tokens ({t[\"savings_percent\"]:.1f}%)')
print(f'cost:     \${c[\"without_headroom_usd\"]:.4f} → \${c[\"with_headroom_usd\"]:.4f}  (saved \${c[\"total_saved_usd\"]:.4f})')
"

# 详细
curl -sS http://127.0.0.1:8787/stats | python3 -m json.tool | head -100

# Prometheus
curl -sS http://127.0.0.1:8787/metrics | head -30
```

### 2.5 看 memory

```bash
# 摘要
headroom memory stats

# 列出来
headroom memory list

# 搜
headroom memory search "<query>"

# 加
headroom memory add --content "<text>" --category <category>

# 删
headroom memory remove <id>
```

> ⚠️ 当前 proxy **没启** `--memory`,所以这些命令读的是**空 DB**(`/data/hermes/headroom_memory.db`,0 rows)。开了 `--memory` 才会写入。

### 2.6 用 claude/codex 走 headroom

**详细接入提示**:
```bash
~/bin/headroom-ctl show-config-hints
# 打印 claude code / codex 的 3 种接入方法(env 临时 / 改配置文件 / headroom init)+ 验证步骤 + 如何关掉
```

**最简一行**:
```bash
# Claude Code(走 anthropic 协议)
ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude

# Codex / Cursor(走 openai 协议)
OPENAI_BASE_URL=http://127.0.0.1:8787/v1 codex
```

### 2.7 离线工具(`learn` + `memory`,透传 headroom 子命令)

> **2026-06-06 新增**:这 2 个子命令**透传**到 headroom 自带 CLI,**不**进 `config.yaml`——因为它们是**命令式数据操作**(非幂等),不是**声明式启动参数**。

#### 2.7.1 `learn` —— 离线失败学习

```bash
# dry-run(看建议不写文件)
~/bin/headroom-ctl learn

# 写 CLAUDE.md / MEMORY.md
~/bin/headroom-ctl learn --apply

# 指定项目 / 所有项目
~/bin/headroom-ctl learn --project ~/my-project --apply
~/bin/headroom-ctl learn --all --apply
```

详见 `HEADROOM.md` §1.8(Learn 是什么 + 决策表 + 跟 TOIN / `proxy --learn` 的区别)。

#### 2.7.2 `memory` —— 长程记忆 CRUD

```bash
~/bin/headroom-ctl memory stats                # 摘要
~/bin/headroom-ctl memory list                 # 列出
~/bin/headroom-ctl memory search "<query>"     # 搜索
~/bin/headroom-ctl memory add -c "..." -k preference  # 加(category: preference|fact|context|entity|decision|insight)
~/bin/headroom-ctl memory remove <id>          # 删
```

> ⚠️ 当前 proxy **没启** `--memory`,所以这些命令读的是**空 DB**(`/data/hermes/headroom_memory.db`,0 rows)。开了 `--memory` 才会写入。详见 `HEADROOM.md` §5.3。

#### 2.7.3 为什么 `learn` / `memory` **不**进 `config.yaml`?

| 命令 | 进 yaml 后会发生什么 | 问题 |
|---|---|---|
| `memory add` | 每次启 proxy 都加一条 | 数据污染(DB 重复行) |
| `learn --apply` | 每次启 proxy 都跑一次离线分析 | 性能浪费 + 文件被反复重写 |
| `memory list` | 没法塞进 yaml(查询无参数化) | 配置文件装不下查询 |

**config.yaml 是"声明状态"**——`proxy: {port, features, upstreams}` 说"启就要这个";**CLI 是"操作数据"**——`memory add/list/...` 说"现在做这件事"。

### 2.8 Memory 默认启用了(2026-06-06 变更)

> **变更**:`proxy.features.memory` 默认 `true`(`config.yaml` 已改成 `true`,`headroom-ctl` 脚本默认也走 `1`)。DB 暂时是空的,不会影响 proxy 启动;但每次请求 proxy 会自动 recall(查 DB → 注入 system msg),空 DB 时零开销。

#### 2.8.1 三写一读架构(已 `HEADROOM.md` §5.6 详讲)

| 路径 | 谁 | 何时 |
|---|---|---|
| **SDK 工具** `HeadroomClient.memory.add()` | LLM agent | LLM 自决(对话中) |
| **CLI** `headroom-ctl memory add/list/...` | 开发者 | 显式 |
| **Proxy auto-capture** | proxy | 当前**没启**(0.23.0 无此机制) |

**3 个写入口写到同一个 DB**,**1 个读出口**(proxy recall + 显式 query)。

#### 2.8.2 典型调用时机(本机)

| 场景 | 调什么 | 频率 |
|---|---|---|
| 启 headroom 跑 Claude Code / Codex | yaml `features.memory: true` + restart | 一次性 |
| 加用户偏好 | `headroom-ctl memory add "用户偏好中文" -k preference` | 一次性 |
| 查 DB 当前有什么 | `headroom-ctl memory list` 或 `search "..."` | 偶尔 |
| DB 太大要清理 | `headroom-ctl memory list` → `memory remove <id>` | 半年/季度 |
| LLM agent 决定存什么 | SDK `memory.add()`(LLM 工具调用) | LLM 自决 |

#### 2.8.3 验证当前状态(本机)

```bash
# 1. 启 proxy(下次你启时,memory 会默认开)
headroom-ctl restart

# 2. 看 status
headroom-ctl status | grep -i memory
# 期望:memory: True(到 /health.config.memory=true)

# 3. 看 DB
headroom-ctl memory stats
# 期望:Total Memories: 0(暂时空)

# 4. 加一条测试
headroom-ctl memory add -c "测试:headroom-ctl 跑通了" -k fact
headroom-ctl memory list
# 看到 1 条
```

#### 2.8.4 想关?

```bash
# 临时
HEADROOM_MEMORY=0 headroom-ctl restart

# 持久
headroom-ctl config-edit   # features.memory: false
headroom-ctl restart
```

#### 2.8.5 风险评估(变更前文档说"relay 慎用",2026-06-06 评估)

| 风险 | 评估 | 备注 |
|---|---|---|
| 启后 400 错 | 🟢 极低 | headroom 0.23.0 proxy 只在 recall 阶段查 DB,不主动 add。LLM 看不到 `memory_20250818` 工具(SDK 模式才暴露) |
| 启动延迟 | 🟢 +1-2s | embedder 模型小(几十 MB) |
| 内存 | 🟢 +50MB | embedder 加载 |
| 隐私 | 🟡 中 | 你的 preferences/facts 落 sqlite DB,文件权限 600 才安全 |
| DB 体积 | 🟢 低 | 1000 条 ~56KB,跑一年不爆 |

**结论**:**默认开,DB 空时无害**。出问题一秒回滚(`features.memory: false` + restart)。

---

---

## 3. 配置管理(改 token、改上游、改特性)— **2026-06-06 改用 config.yaml**

> **重要变更**:旧的 `proxy.env`(key=value 列表)已被 **`config.yaml`** 替代。理由:
> - 唯一真相源(不分散在 5 个文件)
> - `headroom-ctl apply` 一条命令同步到 Claude Code / Codex / auth.json
> - 跟官方 `headroom install apply` 的 manifest 模式对齐(JSON manifest)
> - 跟"yaml 是头room docs 推荐的"惯例一致
>
> **proxy.env 已删除**。脚本里 `CONFIG_FILE` 路径名保留仅为向后兼容,不再 source。

### 3.1 配置驱动模式(推荐工作流)

```bash
# 1. 创建配置目录(首次,如有跳过)
mkdir -p ~/.config/headroom

# 2. 写 config.yaml(单文件统一管理,见 §3.1 schema)
# 模板见 §3.1.1,或:
headroom-ctl config-show   # 看你现在的 yaml
headroom-ctl config-edit   # 用 $EDITOR 打开改

# 3. 重启 proxy 让 yaml 生效
~/bin/headroom-ctl restart

# 4. 验证
~/bin/headroom-ctl status   # 看 code_graph / memory / learn 是否符合预期
```

#### 3.1.1 config.yaml schema 速查

完整 schema 见 [`HEADROOM.md` §3.1](./HEADROOM.md#31-配置文件-configyaml)。**最小可用配置**:

```yaml
proxy:
  port: 8787
  upstreams:
    anthropic:
      url: https://api.minimaxi.com/anthropic   # 你的 upstream
      token: sk-cp-xxxx...
  features:
    code_aware: true
    telemetry: "off"
  hf:
    disable_xet: true
    endpoint: https://hf-mirror.com

claude_code:
  enabled: true
  base_url: http://127.0.0.1:8787
  model: MiniMax-M3[1M]

codex:
  enabled: true
  model_provider: headroom
  providers:
    headroom:
      base_url: http://127.0.0.1:8787/v1
      wire_api: responses
      requires_openai_auth: true
```

#### 3.1.2 改 client 端配置(让 claude/codex 默认走 headroom)

```bash
# 改 yaml 后,一条命令同步 3 个 client 文件(自动备份 .bak.时间戳)
headroom-ctl apply
# → 改 ~/.claude/settings.json: env.ANTHROPIC_BASE_URL = http://127.0.0.1:8787
# → 改 ~/.codex/config.toml:   model_provider = "headroom" + 注入 [model_providers.headroom]
# → 改 ~/.codex/auth.json:     OPENAI_API_KEY = yaml 里 openai.token
```

> **不 apply 也行**:client 端每次启动时手动设 `ANTHROPIC_BASE_URL=http://127.0.0.1:8787` 即可。apply 是**持久化**默认配置,二选一。

### 3.2 Token 轮换

Proxy 启动时读 `ANTHROPIC_AUTH_TOKEN`,**不读后续修改**。改 token 必须重启:

**推荐**:
```bash
# 1. 改 yaml
headroom-ctl config-edit
# 找到 proxy.upstreams.anthropic.token: sk-旧... 改成 sk-新...

# 2. 重启
~/bin/headroom-ctl restart

# 3. 验
~/bin/headroom-ctl status | head -10
```

**备选**(裸命令):
```bash
# 1. 停
pkill -f "headroom proxy" && sleep 2

# 2. 启时换 token
nohup env ... ANTHROPIC_AUTH_TOKEN=<新 token> headroom proxy --port 8787 > /tmp/headroom.log 2>&1 &

# 3. 验
curl -sS http://127.0.0.1:8787/livez
```

### 3.3 切上游(从 gotoken 切到真 Anthropic)

**推荐**(改 yaml):
```bash
headroom-ctl config-edit
# 改 proxy.upstreams.anthropic.url: https://api.anthropic.com
# 改 proxy.upstreams.anthropic.token: sk-ant-...  (真 Anthropic token,不是 gotoken 的)
~/bin/headroom-ctl restart
```

**备选**(裸命令):
```bash
pkill -f "headroom proxy"
nohup env \
  HF_HUB_DISABLE_XET=1 HF_ENDPOINT=https://hf-mirror.com \
  ANTHROPIC_TARGET_API_URL=https://api.anthropic.com \
  ANTHROPIC_API_KEY=sk-ant-... \
  HEADROOM_TELEMETRY=off \
  headroom proxy --port 8787 \
  > /tmp/headroom.log 2>&1 &
```

### 3.4 切 HF 镜像(从 hf-mirror 切到直连)

**推荐**(改 yaml):
```bash
headroom-ctl config-edit
# 注释掉或删掉 proxy.hf.endpoint 行
# 保留 proxy.hf.disable_xet: true  (在 SOCKS 代理下仍需要)
~/bin/headroom-ctl restart
```

### 3.5 启 Code-Aware(`headroom-ctl` 默认已开,见 §1.7)

**确认状态**:
```bash
headroom-ctl status | grep -E "code_aware|code_graph"
# 期望:
#   code_graph:   False    (config 字段,code graph intelligence,另一个 feature)
#   code_aware:   True     (AST 压缩,我们启的,跟 HEADROOM.md §1.7 推荐一致)
```

**手动关**:
```bash
headroom-ctl config-edit
# 改 features.code_aware: false
~/bin/headroom-ctl restart
```

**裸命令等价**:
```bash
pkill -f "headroom proxy" && sleep 2
nohup env ... \
  headroom proxy --port 8787 --no-code-aware > /tmp/headroom.log 2>&1 &
```

> 详细收益 / 风险见 §1.7。本操作会**短暂中断**(5-30s)正在使用 headroom 的 client 流量。

### 3.6 装 ~/.bashrc alias(可选,一行版)

```bash
# 装短名 alias(2026-06-06 版)
cat >> ~/.bashrc <<'EOF'

# Headroom
alias hr='~/bin/headroom-ctl'
alias hr-claude='ANTHROPIC_BASE_URL=http://127.0.0.1:8787 claude'
alias hr-codex='OPENAI_BASE_URL=http://127.0.0.1:8787/v1 codex'
alias hr-apply='~/bin/headroom-ctl apply'
alias hr-edit='~/bin/headroom-ctl config-edit'
EOF

# 立即生效
source ~/.bashrc

# 之后可以这样用
hr status
hr restart
hr-claude
hr-codex
hr-apply    # 同步 yaml 到 3 个 client
hr-edit     # 打开 yaml
```

### 3.7 上 systemd(常驻推荐,代替 nohup)

```bash
# headroom 自带 install(CLI 实验性功能)
headroom install apply        # 装 systemd/launchd 服务
headroom install status       # 看状态
headroom install restart      # 重启服务
headroom install stop         # 停
headroom install remove       # 卸载服务
```

> ⚠️ 这会**接管**进程管理,用 `pkill` / `headroom-ctl stop` 之后 systemd 会拉回来。要彻底裸 nohup 要先 `headroom install remove`。

---

## 4. 故障排查(本机实际遇到的案例)

### 4.1 端口 8787 冲突

```bash
ss -tlnp | grep 8787
# 输出:
# LISTEN ... 127.0.0.1:8787 ... users:(("headroom",pid=339355,fd=10))

# 强制清掉
pkill -9 -f "headroom proxy"
sleep 2
ss -tlnp | grep 8787 || echo "已空"
```

### 4.2 Proxy 启动卡死(4+ 分钟不 bind)

**症状**:log 里看到 `huggingface_hub.utils._http` 但端口没起。

**根因**:HF `xet` 协议被 SOCKS 代理限速(本机走 `192.168.3.74:7897` 到 HF)。

**修法**:
```bash
# 必加 env
HF_HUB_DISABLE_XET=1 \         # 改用普通 HTTP 下载
HF_ENDPOINT=https://hf-mirror.com \   # 切到国内镜像
  headroom proxy --port 8787

# 验:看 cache 是不是 0 字节
ls -la ~/.cache/huggingface/hub/models--chopratejas--kompress-base/blobs/
# 0 字节 .incomplete 文件 = 又卡了,清掉重下
rm -f ~/.cache/huggingface/hub/models--chopratejas--kompress-base/blobs/*.incomplete
```

### 4.3 Claude 报 401/403 / 401 Unauthorized

```bash
# 快速诊断(用 headroom-ctl)
~/bin/headroom-ctl status
# 看 "ANTHROPIC_AUTH_TOKEN:  sk-...b082(已脱敏)"
# 出现 "N/A" 或空 = 漏配

# 备选(裸命令)
PID=$(pgrep -f "headroom proxy" | head -1)
cat /proc/$PID/environ | tr '\0' '\n' | grep ANTHROPIC_AUTH_TOKEN
# 空 = 漏配

# 修法:停 + 重启时带 token
# 推荐
$EDITOR ~/.config/headroom/proxy.env   # 改 ANTHROPIC_AUTH_TOKEN
~/bin/headroom-ctl restart

# 备选(裸命令)
pkill -f "headroom proxy"
nohup env ... ANTHROPIC_AUTH_TOKEN=<新 token> ... headroom proxy --port 8787 > /tmp/headroom.log 2>&1 &
```

### 4.4 Claude 报连接拒绝

```bash
# 1. proxy 没起?
~/bin/headroom-ctl status | head -3
# 看到 "端口 8787: down" = 没起
# → ~/bin/headroom-ctl start

# 备选(裸命令)
pgrep -f "headroom proxy" || echo "proxy 未运行,启一下"

# 2. 端口换过?用户设的 ANTHROPIC_BASE_URL 跟实际端口不一致
ss -tlnp | grep 8787
# 用户应设 ANTHROPIC_BASE_URL=http://127.0.0.1:8787
```

### 4.5 Memory DB 写不进 / lock 等

```bash
# 切 WAL 模式
sqlite3 /data/hermes/headroom_memory.db 'PRAGMA journal_mode=WAL;'
# 输出:wal
```

### 4.6 `claude plugin marketplace add` 卡死(Git clone 超时 120s)

**根因**:同 4.2,网络出口到 GitHub 慢。**别用 `headroom init claude --global`**——本部署不依赖 init,直接 `ANTHROPIC_BASE_URL` 启动就好(见 `HEADROOM.md` §0.2)。

### 4.7 `ModuleNotFoundError: No module named 'fastapi'`

**症状**:`headroom install status` 等命令炸。

**根因**:`uv tool install` 默认没装 fastapi。

**修法**:
```bash
uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai[all]"
# 之后 which headroom 必须指向新 venv
which headroom
# 期望: /home/stark/.local/bin/headroom
```

### 4.8 ONNX 模型持续重下

```bash
# 看 cache 大小(应该 ~70 MB)
du -sh ~/.cache/huggingface/hub/models--chopratejas--kompress-base

# 0 字节 = 又卡了
ls -la ~/.cache/huggingface/hub/models--chopratejas--kompress-base/blobs/

# 清掉重下(只清残骸,保留已下载)
rm -f ~/.cache/huggingface/hub/models--chopratejas--kompress-base/blobs/*.incomplete
```

---

## 5. 备份与恢复

### 5.1 备份当前配置

```bash
# 一次性
BACKUP_DIR=~/backup/headroom-$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# 关键文件
cp -a /data/hermes/headroom_memory.db $BACKUP_DIR/ 2>/dev/null
cp -a ~/.headroom $BACKUP_DIR/                      # deploy/ + logs/
cp -a ~/.config/headroom $BACKUP_DIR/ 2>/dev/null   # 若已装
cp -a ~/bin/headroom-* $BACKUP_DIR/ 2>/dev/null     # 若已装

# log
cp /tmp/headroom-qs2.log $BACKUP_DIR/

echo "backed up to $BACKUP_DIR"
du -sh $BACKUP_DIR
```

### 5.2 恢复

```bash
# 反向操作
cp -a $BACKUP_DIR/headroom_memory.db /data/hermes/
cp -a $BACKUP_DIR/.headroom ~/
# 其他按需
```

### 5.3 settings.json 回滚(本次部署产生的备份)

```bash
# 看备份
ls -la ~/.claude/settings.json.bak.*

# 回滚(谨慎!覆盖前确认)
cp ~/.claude/settings.json.bak.20260606_152245 ~/.claude/settings.json

# 验证
grep -c "headroom" ~/.claude/settings.json   # 应该是 0
```

---

## 6. 完全清理(彻底卸载)

```bash
# 1. 停 proxy
pkill -9 -f "headroom proxy"

# 2. 删 uv tool 装的
uv tool uninstall headroom-ai

# 3. 删备用 venv
rm -rf /tmp/headroom-env

# 4. 删 headroom 全局数据
rm -rf ~/.headroom

# 5. 删 HF 模型缓存(省 70 MB)
rm -rf ~/.cache/huggingface/hub/models--chopratejas--kompress-base

# 6. 删项目 memory DB(本部署是 0 数据,无影响)
rm -f /data/hermes/headroom_memory.db

# 7. 删 headroom 仓库代码(140 MB+)
rm -rf /tmp/headroom

# 8. 删自己的配置(若已装)
rm -rf ~/.config/headroom
rm -rf ~/log/headroom
rm -f ~/bin/headroom-up ~/bin/headroom-down ~/bin/headroom-status

# 9. 删 bashrc alias
sed -i '/headroom-up\|headroom-down\|headroom-status\|headroom-stats\|headroom-log\|headroom-claude\|headroom-codex/d' ~/.bashrc

# 10. 验证:which headroom 应该找不到
which headroom || echo "✓ 卸载干净"
ss -tlnp | grep 8787 || echo "✓ 8787 端口空"
```

---

## 7. 关键事实速记

| 项 | 值 | 来源 |
|---|---|---|
| Headroom 版本 | 0.23.0 | `headroom --version` |
| 当前 proxy PID | 339355 | `pgrep -f "headroom proxy"` |
| 上游 | `https://api.gotoken.top` | `ANTHROPIC_TARGET_API_URL` in env |
| 端口 | 127.0.0.1:8787 | `ss -tlnp` |
| Token | sk-65d7da9c... | `cat /proc/339355/environ` |
| HF 镜像 | `https://hf-mirror.com` | `HF_ENDPOINT` in env |
| 启动时间 | 2026-06-06 ~15:55(进程已跑 ~97 min) | `/proc/339355` 启动时间 |
| 启动方式 | 裸 nohup,**未用脚本** | `cat /proc/339355/cmdline` |
| Memory 状态 | 启用标志未传(proxy 实际 memory=disabled) | `/health.checks.memory.enabled=false` |
| Memory DB | `/data/hermes/headroom_memory.db`, 0 rows, journal=delete | sqlite3 |
| settings.json | 未被 headroom 修改(有 init 半失败前的备份) | backup file 仍在 |
| 推荐配置是否实施 | **否**(脚本/env/alias 全未装) | `ls` 都找不到 |

---

## 8. 日常巡检清单(可加 cron)

```bash
#!/bin/bash
# ~/bin/headroom-healthcheck.sh
set -e
HOST="http://127.0.0.1:8787"

# 1. 进程在
PID=$(pgrep -f "headroom proxy" | head -1)
[ -z "$PID" ] && { echo "CRITICAL: headroom proxy not running"; exit 2; }

# 2. 端口在
ss -tlnp | grep -q :8787 || { echo "CRITICAL: 8787 not listening"; exit 2; }

# 3. /readyz 200
HTTP=$(curl -sS -o /dev/null -w "%{http_code}" $HOST/readyz)
[ "$HTTP" = "200" ] || { echo "CRITICAL: /readyz=$HTTP"; exit 2; }

# 4. /health status=healthy
STATUS=$(curl -sS $HOST/health | python3 -c "import json,sys;print(json.load(sys.stdin)['status'])")
[ "$STATUS" = "healthy" ] || { echo "CRITICAL: status=$STATUS"; exit 1; }

# 5. 内存不过分
MEM_KB=$(ps -p $PID -o rss= 2>/dev/null | tr -d ' ')
[ "$MEM_KB" -gt 2000000 ] && { echo "WARN: PID $PID RSS=${MEM_KB}KB > 2GB"; exit 1; }

echo "OK: pid=$PID mem=${MEM_KB}KB status=$STATUS"
exit 0
```

```bash
chmod +x ~/bin/headroom-healthcheck.sh

# 加 cron(每 5 分钟)
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/bin/headroom-healthcheck.sh || echo 'headroom degraded' | mail -s 'headroom alert' root") | crontab -
```
