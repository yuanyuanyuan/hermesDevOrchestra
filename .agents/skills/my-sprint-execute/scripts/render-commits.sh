#!/usr/bin/env bash
# render-commits.sh — 从 ${COMMITS_JSON} 渲染 ${COMMITS_TABLE}
#
# Usage: COMMITS_JSON='[...]' render-commits.sh
#   输出 markdown 表格到 stdout
#
# 依赖: jq

set -euo pipefail

: "${COMMITS_JSON:?COMMITS_JSON must be set}"

echo "$COMMITS_JSON" | jq -r '
  ["SHA", "Type", "Subject", "Files"]
  ,
  (.commits // .)[] | [
    .sha[0:7],
    .type,
    (.subject | gsub("\\|"; "\\|")),
    (.files | tostring | gsub("\\[|\\]"; ""))
  ]
  | @tsv
' | column -t -s $'\t'
