#!/usr/bin/env bash
# split-sprints.sh — Topological sort + bin-packing sprint assignment
#
# Usage: split-sprints.sh <INPUT_JSON_WITH_SP> [SPRINT_CAPACITY]
# Input: JSON with implementation_units[].sp field added
# Output: JSON with sprint assignments to stdout

set -euo pipefail

INPUT="${1:?Usage: split-sprints.sh <INPUT_JSON_WITH_SP>}"
SPRINT_CAPACITY="${2:-7}"

if [[ ! -f "$INPUT" ]]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

jq --argjson cap "$SPRINT_CAPACITY" '
  # Save metadata before processing
  .frontmatter as $fm |
  .requirements as $reqs |
  .implementation_units as $units |

  # Build unit map for dependency lookup
  ($units | reduce .[] as $u ({}; . + {($u.uid): $u})) as $umap |

  # Topological sort via recursive function
  def topo:
    . as $state |
    if ($state.remaining | length == 0) then $state.sorted
    else
      [$state.remaining[] | select(
        . as $uid | $umap[$uid].dependencies // [] |
        all(. as $d | $state.done | index($d) != null)
      )] | sort as $ready |
      if ($ready | length == 0)
        then error("Circular dependency among: \($state.remaining | join(", "))")
      else
        $state |
        .sorted += $ready |
        .done += $ready |
        .remaining -= $ready |
        topo
      end
    end;

  {sorted: [], done: [], remaining: [$units[].uid]} | topo as $order |

  # Bin-packing: greedy first-fit in topological order
  [$order[] | $umap[.]] as $ordered |
  reduce $ordered[] as $unit (
    [{sprint: 1, total_sp: 0, units: []}];
    ($unit.sp // 1) as $sp |
    if $sp > $cap
      then error("Unit \($unit.uid) exceeds sprint capacity: \($sp) > \($cap)")
    elif (.[-1].total_sp + $sp) > $cap
      then . + [{sprint: (length + 1), total_sp: $sp, units: [$unit]}]
    else
      .[:-1] + [.[-1] | .total_sp += $sp | .units += [$unit]]
    end
  ) |

  # Output with original metadata
  {
    frontmatter: $fm,
    requirements: $reqs,
    sprints: .,
    total_sprints: (length),
    capacity: $cap
  }
' "$INPUT"
