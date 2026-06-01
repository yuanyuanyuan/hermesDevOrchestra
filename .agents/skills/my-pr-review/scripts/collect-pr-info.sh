#!/usr/bin/env bash
# collect-pr-info.sh — Collect PR metadata, diff, and existing review context
#
# MCP FALLBACK: 当 SKILL.md 中 GitHub MCP 路径不可用时，调用此脚本作为降级方案。
# 此脚本依赖 gh CLI，所有数据通过 gh 命令获取。
#
# Usage: collect-pr-info.sh <PR_NUMBER>
# Outputs JSON with all needed context to stdout

set -euo pipefail

PR_NUMBER="${1:?Usage: collect-pr-info.sh <PR_NUMBER>}"

OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

# PR metadata
PR_META=$(gh pr view "$PR_NUMBER" \
  --json number,title,body,author,headRefName,baseRefName,headRefOid,baseRefOid,createdAt,updatedAt,mergeable,changedFiles,additions,deletions,url 2>/dev/null)

PR_URL=$(echo "$PR_META" | jq -r '.url')
HEAD_OID=$(echo "$PR_META" | jq -r '.headRefOid')
BASE_OID=$(echo "$PR_META" | jq -r '.baseRefOid')

# Changed files list
CHANGED_FILES=$(gh pr diff "$PR_NUMBER" --stat 2>/dev/null | tail -1 || echo "")
DIFF_FILES=$(gh pr diff "$PR_NUMBER" 2>/dev/null | grep -E "^\+\+\+ b/" | sed 's/+++ b\///' || echo "")

# Existing reviews (to avoid duplicate comments)
EXISTING_REVIEWS=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --jq '[.[] | {id: .id, state: .state, user: .user.login, body: .body[0:200]}]' 2>/dev/null || echo "[]")

EXISTING_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | {id: .id, user: .user.login, body: .body[0:200], created_at: .created_at}]' 2>/dev/null || echo "[]")

# Output structured JSON
jq -n \
  --argjson pr "$PR_META" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg prUrl "$PR_URL" \
  --arg headOid "$HEAD_OID" \
  --arg baseOid "$BASE_OID" \
  --arg changedFiles "$CHANGED_FILES" \
  --arg diffFiles "$DIFF_FILES" \
  --argjson existingReviews "$EXISTING_REVIEWS" \
  --argjson existingComments "$EXISTING_COMMENTS" \
  '{
    owner: $owner,
    repo: $repo,
    pr_number: $pr.number,
    pr_url: $prUrl,
    title: $pr.title,
    author: $pr.author.login,
    head_oid: $headOid,
    base_oid: $baseOid,
    head_ref: $pr.headRefName,
    base_ref: $pr.baseRefName,
    changed_files: $pr.changedFiles,
    additions: $pr.additions,
    deletions: $pr.deletions,
    mergeable: $pr.mergeable,
    changed_files_stat: $changedFiles,
    diff_files: ($diffFiles | split("\n") | map(select(length > 0))),
    existing_reviews: $existingReviews,
    existing_comments: $existingComments
  }'
