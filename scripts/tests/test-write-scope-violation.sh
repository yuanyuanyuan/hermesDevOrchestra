#!/usr/bin/env bash
set -euo pipefail

TEST_NAME="write-scope-violation"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# shellcheck source=lib/assert.sh
source "$TEST_DIR/lib/assert.sh"

python3 - "$REPO_ROOT" <<'PY'
import hashlib
import sys
import tempfile
from pathlib import Path

repo = Path(sys.argv[1])
sys.path.insert(0, str(repo / "scripts/lib"))

from write_scope_validator import WriteScopeError, validate_completion_scope


def expect(code, func):
    try:
        func()
    except WriteScopeError as exc:
        assert exc.code == code, (exc.code, code, exc.violations)
        return
    raise AssertionError(f"expected {code}")


with tempfile.TemporaryDirectory() as tmp:
    workspace = Path(tmp) / "workspace"
    workspace.mkdir()
    allowed = workspace / "src" / "login.py"
    allowed.parent.mkdir()
    allowed.write_text("print('ok')\n", encoding="utf-8")
    digest = hashlib.sha256(allowed.read_bytes()).hexdigest()

    result = validate_completion_scope(
        workspace,
        ["src/login.py"],
        ["src/login.py"],
        [{"path": "src/login.py", "sha256": digest}],
    )
    assert result["result"] == "passed", result

    expect(
        "write_scope_violation",
        lambda: validate_completion_scope(
            workspace,
            ["src/login.py"],
            ["src/login.py", "README.md"],
            [{"path": "src/login.py", "sha256": digest}],
        ),
    )
    expect(
        "unexpected_file_detected",
        lambda: validate_completion_scope(
            workspace,
            ["src/login.py"],
            ["src/login.py"],
            [{"path": "README.md", "sha256": digest}],
        ),
    )

    outside = Path(tmp) / "outside.txt"
    outside.write_text("secret\n", encoding="utf-8")
    link = workspace / "src" / "escape.txt"
    link.symlink_to(outside)
    expect(
        "symlink_escape_detected",
        lambda: validate_completion_scope(
            workspace,
            ["src/escape.txt"],
            ["src/escape.txt"],
            [{"path": "src/escape.txt", "sha256": hashlib.sha256(outside.read_bytes()).hexdigest()}],
        ),
    )

    allowed.write_text("changed\n", encoding="utf-8")
    expect(
        "file_integrity_mismatch",
        lambda: validate_completion_scope(
            workspace,
            ["src/login.py"],
            ["src/login.py"],
            [{"path": "src/login.py", "sha256": digest}],
        ),
    )
PY

test_done
