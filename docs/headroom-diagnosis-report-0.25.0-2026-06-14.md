# Headroom Proxy 诊断报告(0.25.0 升级后初快照)

> **生成时间**: 2026-06-14 20:14 UTC(升级完成后即时)
> **Proxy 版本**: 0.25.0
> **Proxy PID**: 1458870
> **运行模式**: token
> **配置源**: `~/.config/headroom/config.yaml`
> **状态**: **升级验收快照**,**未跑真流量**——`/stats` 全 0,因升级后尚无 Claude/Codex 请求

---

## 一、执行摘要

本次是 **0.23.0 → 0.25.0 升级验收快照**(无真实流量)。核心发现:

| 维度 | 状态 | 关键发现 |
|------|------|---------|
| **升级路径** | ✅ 成功 | `uv tool upgrade headroom-ai`:0.23.0 → 0.25.0,无破坏性迁移 |
| **Proxy 健康** | ✅ 全部 healthy | 6 个 /health check 全 healthy(新增 `upstream` #744) |
| **Kompress v2 模型** | ⚠️ 未下载 | HF cache 空,首次实质请求才触发 `kompress-v2-base` int8-wo(261MB) |
| **tree_sitter_language_pack** | ✅ 0.25.0 收成默认依赖 | `uv tool upgrade` 自动装 v1.8.1,**不再需要 `[code]` extra workaround** |
| **新增路由** | ✅ Vertex AI 上线 | `/v1/projects/.../publishers/...` → `us-central1-aiplatform.googleapis.com`(#793) |
| **Multi-provider memory** | ✅ Anthropic native `memory_20250818` 暴露 + OpenAI function calling | 启动 banner 显示 |
| **配置文件兼容** | ✅ | `config.yaml` 沿用,无需改 |
| **持久化数据兼容** | ✅ | `proxy_savings.json` / `toin.json` / `headroom_memory.db` 旧文件可继续用 |

---

## 二、0.23.0 → 0.25.0 升级变更对照

### 2.1 升级命令

```bash
pkill -9 -f "headroom proxy"   # 停 proxy
uv tool upgrade headroom-ai     # 升级(自动升级 13 个依赖)
# 注:0.25.0 自动包含 tree_sitter_language_pack,无需再 uv pip install [code]
~/bin/headroom-ctl restart      # 重启
```

### 2.2 依赖变化(uv tool upgrade 自动应用)

| 依赖 | 0.23.0 | 0.25.0 | 备注 |
|------|--------|--------|------|
| `transformers` | 5.10.2 | 5.12.0 | minor |
| `huggingface-hub` | 1.18.0 | 1.19.0 | minor |
| `safetensors` | 0.7.0 | 0.8.0 | minor |
| `litellm` | 1.82.3 | 1.89.0 | minor |
| `onnxruntime` | (未列) | 1.26.0 | 仍是同一大版本 |
| `hf-xet` | 1.5.0 | 1.5.1 | patch |
| **tree-sitter-language-pack** | **缺失(需手动装)** | **1.8.1(默认依赖)** | **0.23.0 隐患修复** |
| `tree-sitter-c-sharp` | (含) | 移除 | 用统一 pack 替代 |
| `tree-sitter-embedded-template` | (含) | 移除 | 用统一 pack 替代 |
| `tree-sitter-yaml` | (含) | 移除 | 用统一 pack 替代 |

### 2.3 配置 / 持久化兼容矩阵

| 资产 | 升级前 | 升级后 | 兼容? | 备注 |
|------|--------|--------|------|------|
| `~/.config/headroom/config.yaml` | 80 行 | 80 行 | ✅ | 0.25.0 增量加新键,旧键保留 |
| `~/bin/headroom-ctl` | 1210 行 | 1210 行 | ✅ | 但 `model_path` 字段提取失效(0.25.0 stats schema 变化) |
| `~/.claude/settings.json` | 未改 | 未改 | ✅ | headroom 一直没动过 |
| `~/.codex/config.toml` | 未改 | 未改 | ✅ | 同上 |
| `/data/hermes/headroom_memory.db` | 57KB 空 | 57KB 空 | ✅ | SQLite schema 向后兼容 |
| `~/.headroom/proxy_savings.json` | 240KB | 240KB | ✅ | 0.25.0 增量字段,旧字段保留 |
| `~/.headroom/toin.json` | 112KB | 112KB | ✅ | TOIN self-healing,自动重新积累 |
| `~/.cache/huggingface/hub/models--chopratejas--kompress-base/` | ~70MB | **已失效** | ❌ | v1 模型,0.25.0 默认 v2 |
| 升级前备份 | — | `~/backup/headroom-upgrade-20260614-201030/` | ✅ | 1.1MB,12 文件 |

---

## 三、/health 实测(2026-06-14 20:14 UTC)

```json
{
  "service": "headroom-proxy",
  "status": "healthy",
  "ready": true,
  "version": "0.25.0",
  "uptime_seconds": 34.664,
  "checks": {
    "startup":     {"enabled": true, "ready": true, "status": "healthy"},
    "http_client": {"enabled": true, "ready": true, "status": "healthy"},
    "cache":       {"enabled": true, "ready": true, "status": "healthy"},
    "rate_limiter":{"enabled": true, "ready": true, "status": "healthy"},
    "memory":      {"enabled": true, "ready": true, "status": "healthy",
                    "backend": "local", "initialized": true,
                    "native_tool": false, "bridge_enabled": false},
    "upstream":    {"enabled": true, "ready": true, "status": "healthy",
                    "url": "https://api.gotoken.top", "error": null}
  }
}
```

**对比 0.23.0**:新增 `upstream` check(#744),其余 5 个结构不变。`memory.backend=local` 仍是 SQLite 向量库。

---

## 四、/stats 实测(空状态)

```json
{
  "summary": {
    "mode": "token",
    "api_requests": 0,
    "primary_model": "unknown",
    "compression": {"requests_compressed": 0, ...},
    "cost": {"without_headroom_usd": 0.0, ...},
    "mcp": {"compressions": 0, "tokens_removed": 0, "retrievals": 0}
  },
  "savings": {"total_tokens": 0, "per_project": {}, "by_layer": {...}}
}
```

**对比 0.23.0 stats schema**:
- 旧 `summary.requests.total` 字段 → **已删除**(0.25.0 改为 `summary.api_requests`)
- 新增 `summary.compression.{requests_compressed,avg_compression_pct,best_compression_pct,...}`
- 新增 `summary.mcp.{compressions,tokens_removed,retrievals}`(#824 `headroom_retrieve` 插件)
- 新增 `savings.per_project`(#803)
- 新增 `savings.by_layer.{cli_filtering,compression,...}`(#807)

**对 headroom-ctl 脚本的影响**:脚本中 `python3 -c "import json,sys; d=json.load(sys.stdin)['summary']; print(d['requests']['total'])"` 之类的 KeyError 会触发——**需要脚本更新**(详见 §6 待办)。

---

## 五、启动 Banner 实测(2026-06-14 20:14 UTC)

```
╔═══════════════════════════════════════════════════════════════════════╗
║                         HEADROOM PROXY                                 ║
║           The Context Optimization Layer for LLM Applications          ║
╚═══════════════════════════════════════════════════════════════════════╝

Starting proxy server...

  URL:          http://127.0.0.1:8787
  Mode:         token
  Optimization: ENABLED
  Caching:      ENABLED
  Rate Limit:   ENABLED
  Memory:       ENABLED (multi-provider)
  License:      OSS (no license key)
  Code-Aware:   ENABLED  (AST-based)
  Context Tool: rtk
  Extensions:   (none discovered)
  Telemetry:    DISABLED

Routing:
  /v1/messages                    → https://api.gotoken.top
  /v1/chat/completions            → https://api.codexzh.com
  /v1/responses                   → https://api.codexzh.com  (HTTP + WebSocket)
  /v1internal:streamGenerateContent → https://cloudcode-pa.googleapis.com
  /v1/projects/.../publishers/... → https://us-central1-aiplatform.googleapis.com   ← 0.25.0 新增
```

**对比 0.23.0 banner**:
- 新增第 5 行路由(`/v1/projects/.../publishers/...` → Vertex AI)
- `Memory: ENABLED (multi-provider)` 取代 0.23.0 的 `Memory: ENABLED`
- 新增 `Memory (Multi-Provider)` 块(显示 Anthropic 用 native memory_20250818、其他用 function calling)

---

## 六、待办(后续 Phase 4 跑真流量后填)

| 项 | 状态 | 说明 |
|------|------|------|
| **真流量 savings 对比** | ⏳ 待跑 | 当前 `/stats` 全 0,需跑 30 分钟 Claude/Codex 任务后对比 0.23.0 时期数据(Codex 5.9% / Claude 0.7%) |
| **Kompress v2 实际节省率** | ⏳ 待跑 | `kompress-v2-base` int8-wo vs `kompress-base`(0.23.0 没工作)——首次请求触发下载后才能测 |
| **headroom-ctl stats 解析修复** | ✅ **已修(2026-06-14 23:13)** | `_kompress_health()` 改用 v2-base 路径 + 3 文件 fallback 链(int8-wo > fp32 > int8)。空 cache 仍报"未找到"是正常的(等首次请求触发下载)。其他 stats 字段在 0.25.0 仍兼容。`~/bin/headroom-ctl` 备份到 `~/backup/headroom-upgrade-20260614-201030/headroom-ctl.post` |
| **headroom-ctl model_loaded 自相矛盾** | ✅ **已修(2026-06-14 23:38)** | `is_kompress_available()` 是骗术——只查 onnxruntime+transformers 包能否 import,不验文件存在。改用文件+大小 sanity check(三态:True/Partial/False),并加 `headroom-ctl warmup-kompress` 主动预热命令。详见本节"§6.1 二次 fix" |
| **§6.1 二次 fix:`is_kompress_available()` 骗局** | ⚠️ **部分修复** | headroom-ctl 修对了(`status` 自洽,`warmup-kompress` 命令就位);但实际下载**仍被网络层阻**:xet 协议在 hf-mirror.com + Clash 代理下 hang 在 67MB 处 7+ 分钟;关掉 xet (`HF_HUB_DISABLE_XET=1`) 后走经典 HTTP 立即报 `OSError: We couldn't connect to 'https://hf-mirror.com'`(同 0.23.0 P0 网络 bug,308 redirect → huggingface.co 断)。需要**VPN 直连 huggingface.co** 或手动放模型到 `~/.cache/huggingface/hub/models--chopratejas--kompress-v2-base/snapshots/<hash>/onnx/kompress-int8-wo.onnx` |
| **HEADROOM.md docs 完整对齐** | ✅ 大部分完成 | §0.0 / §3.1.1 / §10 已更新 |
| **HEADROOM-OPS.md docs 完整对齐** | ✅ 大部分完成 | §0.6 / §1.7 / §1.10 / §7 已更新 |
| **2026-06-06 诊断报告归档** | ✅ 完成 | 改名 + header 标注 |

---

## 七、当前已知风险(0.25.0 升级后)

1. **`memory_20250818` 在 relay 兼容性**——0.25.0 默认会把 native memory tool 暴露给 LLM,gotoken.relay **可能不识别**导致 400 错。`features.memory: false` 一秒回滚
2. **`kompress-v2-base` 下载链路有 2 个网络变体都坏** —— 实测(2026-06-14 23:35):
   - **xet 协议**(huggingface_hub 1.19.0 默认):hf-mirror.com + Clash 本地代理 7897,下载到 67MB 卡 7+ 分钟,日志显示 "Decreased concurrency from 1 to 1" 但不报错,xet client 静默断流
   - **经典 HTTP**(`HF_HUB_DISABLE_XET=1`):立即报 `OSError: We couldn't connect to 'https://hf-mirror.com'`(同 0.23.0 P0 网络 bug,308 redirect → huggingface.co 断)
   - **实际可工作路径**:VPN 直连 `huggingface.co` 下载到本地后,**手动** symlink 到 `~/.cache/huggingface/hub/models--chopratejas--kompress-v2-base/snapshots/<hash>/onnx/kompress-int8-wo.onnx`;或首次真流量触发自动下载(走同链路,可能仍 hang)
3. **`ccr_enabled=True` 默认开启**——CCR marker 注入现在是默认行为,对 prefix cache 行为有微小影响(已通过 `compress_assistant_text_blocks=False` 缓解)
4. **TOIN 状态需重新积累**——升级后 `toin.json` 旧模式可能不匹配新格式,proxy 会自动重新学习

---

## 八、回滚路径(若需)

```bash
# 1. 停 0.25.0 proxy
~/bin/headroom-ctl stop

# 2. 装回 0.23.0
uv tool uninstall headroom-ai
uv tool install --force --with fastapi --with uvicorn --with httpx "headroom-ai==0.23.0"

# 3. (可选)恢复备份的持久化文件
cp ~/backup/headroom-upgrade-20260614-201030/proxy_savings.json ~/.headroom/
cp ~/backup/headroom-upgrade-20260614-201030/toin.json ~/.headroom/
cp ~/backup/headroom-upgrade-20260614-201030/subscription_state.json ~/.headroom/
cp ~/backup/headroom-upgrade-20260614-201030/headroom_memory.db /data/hermes/

# 4. 重启
~/bin/headroom-ctl restart
```

---

*报告生成时间:2026-06-14 20:14 UTC,基于 0.25.0 升级后即时快照*
*升级前对照:见 [headroom-diagnosis-report-0.23.0-2026-06-06.md](./headroom-diagnosis-report-0.23.0-2026-06-06.md)*