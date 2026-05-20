#!/usr/bin/env bash
# parse-plan.sh — Extract structured data from ce-plan markdown output
#
# Usage: parse-plan.sh <PLAN_FILE>
# Outputs JSON to stdout with frontmatter, requirements, implementation_units

set -euo pipefail

PLAN_FILE="${1:?Usage: parse-plan.sh <PLAN_FILE>}"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "Error: Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

python3 - "$PLAN_FILE" << 'PYEOF'
import sys, re, json

plan_file = sys.argv[1]
with open(plan_file, 'r') as f:
    text = f.read()

lines = text.split('\n')

# --- Parse frontmatter ---
fm = {}
in_fm = False
fm_done = False
for line in lines:
    if line.strip() == '---':
        if not in_fm and not fm_done:
            in_fm = True
            continue
        elif in_fm:
            in_fm = False
            fm_done = True
            continue
    if in_fm:
        m = re.match(r'^(\w+):\s*(.*)', line)
        if m:
            fm[m.group(1)] = m.group(2).strip()

# --- Parse requirements ---
requirements = []
in_req = False
for line in lines:
    if re.match(r'^## Requirements', line):
        in_req = True
        continue
    if in_req and re.match(r'^## ', line):
        break
    if in_req:
        m = re.match(r'^- (R\d+)\.\s*(.*)', line)
        if m:
            requirements.append({"id": m.group(1), "description": m.group(2).strip()})

# --- Parse implementation units ---
units = []
current = None
current_field = None

in_units = False
for line in lines:
    if re.match(r'^## Implementation Units', line):
        in_units = True
        continue
    if in_units and re.match(r'^## ', line):
        break
    if not in_units:
        continue

    # New unit header
    m = re.match(r'^### (U\d+)\.\s*(.*)', line)
    if m:
        if current:
            units.append(current)
        current = {
            "uid": m.group(1),
            "name": m.group(2).strip(),
            "goal": "",
            "requirements": [],
            "dependencies": [],
            "files": [],
            "approach": [],
            "test_scenarios": [],
            "verification": []
        }
        current_field = None
        continue

    if not current:
        continue

    # Single-value fields
    if '**Goal:**' in line:
        current['goal'] = line.split('**Goal:**')[1].strip()
        current_field = None
    elif '**Requirements:**' in line:
        val = line.split('**Requirements:**')[1].strip()
        current['requirements'] = [r.strip() for r in val.split(',') if r.strip()]
        current_field = None
    elif '**Dependencies:**' in line:
        val = line.split('**Dependencies:**')[1].strip()
        if val.lower() == 'none':
            current['dependencies'] = []
        else:
            current['dependencies'] = [d.strip() for d in val.split(',') if d.strip()]
        current_field = None
    # Multi-value fields (start)
    elif '**Files:**' in line:
        current_field = 'files'
    elif '**Approach:**' in line:
        current_field = 'approach'
    elif '**Test scenarios:**' in line:
        current_field = 'test_scenarios'
    elif '**Verification:**' in line:
        current_field = 'verification'
    # Other bold headers end current field
    elif re.match(r'^\*\*[A-Z]', line):
        current_field = None
    # List items for current field
    elif current_field and line.strip().startswith('- '):
        current[current_field].append(line.strip()[2:].strip())

if current:
    units.append(current)

# --- Output ---
result = {
    "frontmatter": fm,
    "requirements": requirements,
    "implementation_units": units
}
json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
PYEOF
