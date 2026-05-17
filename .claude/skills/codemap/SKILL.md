# MyCodeMap Code Analysis

## Overview

Use MyCodeMap to analyze TypeScript/JavaScript project structure, query symbols, analyze dependencies, and assess change impact.

## CLI Detection

Detect MyCodeMap CLI availability:

```bash
# Check global installation
if command -v mycodemap &> /dev/null; then
    CODEMAP="mycodemap"
# Check local installation
elif [ -f "./node_modules/.bin/mycodemap" ]; then
    CODEMAP="./node_modules/.bin/mycodemap"
# Fallback to npx
else
    CODEMAP="npx @mycodemap/mycodemap"
fi
```

## Commands

### Generate Code Map
```bash
$CODEMAP generate
```
Generates: `.mycodemap/AI_MAP.md`, `.mycodemap/CONTEXT.md`, `.mycodemap/codemap.json`

### Query Symbol
```bash
$CODEMAP query -s "<symbol-name>"
$CODEMAP query -s "<symbol-name>" -j  # JSON output
```

### Query Module
```bash
$CODEMAP query -m "<module-path>"
```

### Search
```bash
$CODEMAP query -S "<keyword>" -l 10
```

### Dependency Analysis
```bash
$CODEMAP deps -m "<module-path>"
$CODEMAP deps -m "<module-path>" -j
```

### Impact Analysis
```bash
$CODEMAP impact -f "<file-path>"
$CODEMAP impact -f "<file-path>" --transitive
```

### Cycle Detection
```bash
$CODEMAP cycles
```

### Complexity Analysis
```bash
$CODEMAP complexity
$CODEMAP complexity -f "<file-path>"
```

## Workflows

### Understanding Project Structure

1. Generate code map: `$CODEMAP generate`
2. Read `.mycodemap/AI_MAP.md` for overview
3. Query specific modules as needed

### Before Code Changes

1. Run impact analysis: `$CODEMAP impact -f "<file>" --transitive`
2. Review affected files
3. Suggest test cases based on impact

### Finding Code

1. Search symbol: `$CODEMAP query -s "<name>"`
2. If not found, fuzzy search: `$CODEMAP query -S "<name>"`
3. Check module context: `$CODEMAP query -m "<path>"`

## Output Format

- Default: Human-readable text
- JSON: Add `-j` flag for structured data
