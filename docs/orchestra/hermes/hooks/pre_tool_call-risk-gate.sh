#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ORCHESTRA_HOME="${ORCHESTRA_HOME:-$HOME/.hermes-orchestra}"

RISK_CHECK="$ORCHESTRA_HOME/bin/orch-risk-check"
if [ ! -x "$RISK_CHECK" ]; then
    RISK_CHECK="$PACKAGE_DIR/scripts/bin/orch-risk-check"
fi

ROLE="${HERMES_PROFILE_ROLE:-${1:-}}"
TOOL_NAME="${HERMES_TOOL_NAME:-${2:-}}"
TOOL_ARGS="${HERMES_TOOL_ARGS:-${3:-}}"

if [ -z "$TOOL_NAME" ]; then
    echo '{"decision":"allow","reason":"missing tool context"}'
    exit 0
fi

set +e
CHECK_OUTPUT="$("$RISK_CHECK" --role "$ROLE" --tool "$TOOL_NAME" "$TOOL_ARGS" 2>/dev/null)"
CHECK_STATUS=$?
set -e

case "$CHECK_STATUS" in
    4)
        printf '%s\n' "$CHECK_OUTPUT"
        exit 2
        ;;
    2|3)
        printf '%s\n' "$CHECK_OUTPUT"
        exit 3
        ;;
    *)
        printf '%s\n' "$CHECK_OUTPUT"
        exit 0
        ;;
esac
