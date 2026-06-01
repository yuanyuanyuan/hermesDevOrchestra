#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="atomic-writer"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import json
import os
import signal
import sys
import tempfile
from multiprocessing import Event, Process, Queue
from pathlib import Path

repo_root = Path(sys.argv[1])
sys.path.insert(0, str(repo_root / "scripts" / "lib"))

from atomic_writer import AtomicWriter


def paused_writer(path_str: str, ready: Event, proceed: Event, queue: Queue, payload: dict[str, object]) -> None:
    def hook(_path: Path, _tmp: Path) -> None:
        ready.set()
        proceed.wait(30)

    writer = AtomicWriter(before_commit_hook=hook)
    queue.put(writer.write(Path(path_str), payload))


def normal_writer(path_str: str, queue: Queue, payload: dict[str, object]) -> None:
    writer = AtomicWriter()
    queue.put(writer.write(Path(path_str), payload))


tmp_dir = Path(tempfile.mkdtemp(prefix="atomic-writer-"))
target = tmp_dir / "run.json"
target.write_text(json.dumps({"version": 1}) + "\n", encoding="utf-8")

# Basic write
writer = AtomicWriter()
receipt = writer.write(target, {"version": 2})
assert receipt["status"] == "written", receipt
assert json.loads(target.read_text(encoding="utf-8"))["version"] == 2

# Kill during write keeps a valid target file
target.write_text(json.dumps({"version": 10}) + "\n", encoding="utf-8")
ready = Event()
proceed = Event()
queue = Queue()
proc = Process(target=paused_writer, args=(str(target), ready, proceed, queue, {"version": 11, "payload": "x" * 200000}))
proc.start()
assert ready.wait(5), "writer never reached pre-commit hook"
os.kill(proc.pid, signal.SIGKILL)
proc.join(5)
after_kill = json.loads(target.read_text(encoding="utf-8"))
assert after_kill["version"] in {10, 11}, after_kill
tmp_candidates = list(target.parent.glob(".tmp.run.json.*"))
assert tmp_candidates, "expected a recoverable tmp file after kill"

# Recovery from tmp after target corruption
target.write_text("{bad json", encoding="utf-8")
recover_receipt = writer.recover(target)
assert recover_receipt["status"] == "recovered", recover_receipt
recovered = json.loads(target.read_text(encoding="utf-8"))
assert recovered["version"] == 11, recovered

# Concurrent write conflict detection
target.write_text(json.dumps({"version": 20}) + "\n", encoding="utf-8")
ready = Event()
proceed = Event()
slow_queue = Queue()
fast_queue = Queue()
slow = Process(target=paused_writer, args=(str(target), ready, proceed, slow_queue, {"version": 21}))
fast = Process(target=normal_writer, args=(str(target), fast_queue, {"version": 22}))
slow.start()
assert ready.wait(5), "slow writer never paused"
fast.start()
fast.join(5)
assert fast.exitcode == 0, fast.exitcode
proceed.set()
slow.join(5)
assert slow.exitcode == 0, slow.exitcode

slow_receipt = slow_queue.get(timeout=2)
fast_receipt = fast_queue.get(timeout=2)
assert fast_receipt["status"] == "written", fast_receipt
assert slow_receipt["status"] == "conflict", slow_receipt
assert json.loads(target.read_text(encoding="utf-8"))["version"] == 22

print("PASS atomic writer")
PY

test_done
