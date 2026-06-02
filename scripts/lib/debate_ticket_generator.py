from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_TICKET_FIELDS = [
    "project_background",
    "goal",
    "non_goal",
    "constraints",
    "acceptance_criteria",
    "risk_boundary",
    "failure_strategy",
]


class DebateTicketError(Exception):
    pass


def validate_ticket(ticket: dict[str, Any]) -> list[str]:
    return [field for field in REQUIRED_TICKET_FIELDS if field not in ticket]


def load_ticket(path: Path | str) -> dict[str, Any]:
    with Path(path).open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise DebateTicketError("debate ticket must be a JSON object")
    return data


def _main() -> int:
    parser = argparse.ArgumentParser(description="Validate a direction debate ticket contract.")
    parser.add_argument("--validate", type=Path, required=True)
    args = parser.parse_args()

    try:
        ticket = load_ticket(args.validate)
    except (OSError, json.JSONDecodeError, DebateTicketError) as exc:
        print(f"invalid debate ticket: {exc}", file=sys.stderr)
        return 1

    missing = validate_ticket(ticket)
    if missing:
        print(f"missing required fields: {', '.join(missing)}", file=sys.stderr)
        return 1

    print("valid debate ticket fields: " + ", ".join(REQUIRED_TICKET_FIELDS))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
