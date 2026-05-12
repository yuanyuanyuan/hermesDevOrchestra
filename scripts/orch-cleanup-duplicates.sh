#!/usr/bin/env bash
# orch-cleanup-duplicates.sh — 安全清理重复注册的 Orchestra 项目
# 同一目录注册了多个项目名时，保留最新的，删除重复项
# 如果任何重复项有活跃任务，则跳过该目录（避免误删）

set -euo pipefail

STATE_ROOT="${STATE_ROOT:-$HOME/.local/state/hermes-orchestra}"
PROJECTS_FILE="$STATE_ROOT/projects.json"
DRY_RUN=false
FORCE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

安全清理重复注册的 Orchestra 项目。

Options:
  -n, --dry-run    只展示会做什么，不实际删除
  -f, --force      即使检测到非 idle 状态也强制清理（谨慎使用）
  -h, --help       显示帮助

逻辑：
  1. 找出同一目录注册了多个项目名的情况
  2. 检查这些项目是否有活跃任务（state != idle、active-run.json、pending-decisions）
  3. 如果有活跃任务 → 跳过该目录，提示用户手动处理
  4. 如果都空闲 → 保留 updated_at 最新的，删除其余
EOF
}

# --------------- args ---------------
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ; shift ;;
        -f|--force)   FORCE=true   ; shift ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [ ! -f "$PROJECTS_FILE" ]; then
    echo "No projects file found at $PROJECTS_FILE"
    exit 0
fi

echo "=== Orchestra 重复项目清理 ==="
[ "$DRY_RUN" = true ] && echo "[DRY-RUN 模式] 不会实际删除任何内容"
echo ""

# --------------- 核心逻辑用 Python 处理 ---------------
python3 - "$PROJECTS_FILE" "$FORCE" "$DRY_RUN" <<'PY'
import json
import sys
import os
import subprocess
import shutil
from collections import defaultdict

projects_file = sys.argv[1]
force = sys.argv[2] == "true"
dry_run = sys.argv[3] == "true"

with open(projects_file, encoding="utf-8") as f:
    projects = json.load(f)

# 按 project_dir 分组
groups = defaultdict(list)
for p in projects:
    groups[p["project_dir"]].append(p)

duplicates = {d: ps for d, ps in groups.items() if len(ps) > 1}

if not duplicates:
    print("未发现重复注册的项目。")
    sys.exit(0)

projects_to_remove = []

for project_dir, proj_list in duplicates.items():
    print(f"📁 目录: {project_dir}")
    print(f"   注册了 {len(proj_list)} 个项目名:")

    any_active = False
    for p in proj_list:
        state_dir = p.get("state_dir", "")
        activity = "idle"

        # 1. active-run.json
        if os.path.exists(f"{state_dir}/active-run.json"):
            activity = "active"
        # 2. pending-decisions
        elif os.path.isdir(f"{state_dir}/pending-decisions") and os.listdir(f"{state_dir}/pending-decisions"):
            activity = "active"
        # 3. current-task.json state
        elif os.path.exists(f"{state_dir}/current-task.json"):
            try:
                with open(f"{state_dir}/current-task.json", encoding="utf-8") as f2:
                    ct = json.load(f2)
                st = ct.get("state", "")
                if st and st != "idle" and st != "null":
                    activity = "active"
            except Exception:
                pass
        # 4. watcher.pid 存活
        if activity == "idle" and os.path.exists(f"{state_dir}/watcher.pid"):
            try:
                with open(f"{state_dir}/watcher.pid", encoding="utf-8") as f2:
                    pid = f2.read().strip()
                if pid and os.path.exists(f"/proc/{pid}"):
                    activity = "active"
            except Exception:
                pass

        status_icon = "🟢 空闲" if activity == "idle" else "🔴 活跃"
        print(f"      • {p['project_id']:25s}  updated_at={p['updated_at']}  {status_icon}")
        if activity == "active":
            any_active = True

    if any_active and not force:
        print("   ⚠️  该目录下有项目处于活跃状态，跳过清理（使用 --force 强制清理）")
        print("")
        continue

    # 保留 updated_at 最新的
    proj_list_sorted = sorted(proj_list, key=lambda x: x.get("updated_at", ""), reverse=True)
    keep = proj_list_sorted[0]
    remove = proj_list_sorted[1:]

    print(f"   ✅ 保留: {keep['project_id']}")
    print(f"   🗑️  删除: {', '.join(p['project_id'] for p in remove)}")

    for p in remove:
        projects_to_remove.append(p)
    print("")

if not projects_to_remove:
    print("没有可安全删除的重复项目。")
    sys.exit(0)

print(f"准备删除 {len(projects_to_remove)} 个重复项目...")
print("")

new_projects = [p for p in projects if p["project_id"] not in {r["project_id"] for r in projects_to_remove}]

if dry_run:
    print("[DRY-RUN] 会更新 projects.json:")
    print(json.dumps(new_projects, indent=2))
    print("")
else:
    with open(projects_file, "w", encoding="utf-8") as f:
        json.dump(new_projects, f, indent=2)
    print("✅ 已更新 projects.json")

for p in projects_to_remove:
    pid = p["project_id"]
    print(f"\n清理项目: {pid}")

    # 1. tmux 会话
    for suffix in ["claude", "codex"]:
        session = f"hermes-{pid}-{suffix}"
        result = subprocess.run(["tmux", "has-session", "-t", session], capture_output=True)
        if result.returncode == 0:
            if dry_run:
                print(f"  [DRY-RUN] 会杀掉 tmux 会话: {session}")
            else:
                subprocess.run(["tmux", "kill-session", "-t", session], capture_output=True)
                print(f"  🗑️  已杀掉 tmux 会话: {session}")
        else:
            print(f"  ℹ️  tmux 会话不存在: {session}")

    # 2. 状态/运行时/审计/缓存目录
    for key in ["state_dir", "runtime_dir", "audit_dir", "cache_dir"]:
        path = p.get(key)
        if path and os.path.exists(path):
            if dry_run:
                print(f"  [DRY-RUN] 会删除 {key}: {path}")
            else:
                try:
                    if os.path.isdir(path):
                        shutil.rmtree(path)
                    else:
                        os.remove(path)
                    print(f"  🗑️  已删除 {key}: {path}")
                except Exception as e:
                    print(f"  ⚠️  删除 {key} 失败: {e}")

    # 3. workspace_root（如果在项目目录内才删）
    workspace = p.get("workspace_root")
    if workspace and os.path.exists(workspace):
        project_dir = p.get("project_dir", "")
        if workspace.startswith(project_dir):
            if dry_run:
                print(f"  [DRY-RUN] 会删除 workspace: {workspace}")
            else:
                try:
                    shutil.rmtree(workspace)
                    print(f"  🗑️  已删除 workspace: {workspace}")
                except Exception as e:
                    print(f"  ⚠️  删除 workspace 失败: {e}")
        else:
            print(f"  ⚠️  workspace 不在项目目录内，跳过: {workspace}")

print("")
if dry_run:
    print("[DRY-RUN] 完成。未做实际修改。")
    print("再次运行（不加 --dry-run）以执行清理。")
else:
    print("✅ 清理完成！")
    print("")
    print("剩余注册项目:")
    for p in new_projects:
        print(f"  • {p['project_id']} → {p['project_dir']}")
PY
