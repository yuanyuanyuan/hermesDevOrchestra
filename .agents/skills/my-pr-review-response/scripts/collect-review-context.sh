#!/usr/bin/env bash
# collect-review-context.sh — 收集 PR review 响应所需的全部上下文
#
# MCP FALLBACK: 当 SKILL.md 中 GitHub MCP 路径不可用时，调用此脚本作为降级方案。
# 优先使用 mcp__github__get_pull_request / get_pull_request_reviews / get_pull_request_comments / get_pull_request_files。
# PR issue comments 暂无 MCP 工具，即使 MCP 路径也仍需 gh api 获取。
# 此脚本依赖 gh CLI，所有数据通过 gh 命令获取。
#
# 输出 JSON 到 stdout，包含：
#   - PR 元数据（标题、分支、作者等）
#   - Review bodies（REQUEST_CHANGES / APPROVED / COMMENTED 等）
#   - Review inline comments（代码行级评论）
#   - PR issue comments（通用评论）
#   - 变更文件列表
#
# Usage: collect-review-context.sh <PR_NUMBER>
#   PR_NUMBER  — GitHub PR 编号

set -euo pipefail

PR_NUMBER="${1:?Usage: collect-review-context.sh <PR_NUMBER>}"

# ── Repo context ──
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

# ── PR metadata ──
PR_META=$(gh pr view "$PR_NUMBER" \
  --json number,title,body,author,headRefName,baseRefName,headRefOid,baseRefOid,createdAt,updatedAt,mergeable,changedFiles,additions,deletions,url 2>/dev/null)

HEAD_OID=$(echo "$PR_META" | jq -r '.headRefOid')
BRANCH=$(echo "$PR_META" | jq -r '.headRefName')

# ── Reviews（含 body，用于提取 REQUEST_CHANGES 清单）──
REVIEWS=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
  --jq '[.[] | {id: .id, state: .state, user: .user.login, body: .body, submitted_at: .submitted_at}]' 2>/dev/null || echo "[]")

# ── Review inline comments（代码行级评论，reviewer 在 diff 上留的）──
REVIEW_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/comments" \
  --jq '[.[] | {id: .id, user: .user.login, path: .path, line: .line, body: .body, created_at: .created_at, diff_hunk: .diff_hunk}]' 2>/dev/null || echo "[]")

# ── PR issue comments（通用评论区）──
ISSUE_COMMENTS=$(gh api "repos/${OWNER}/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq '[.[] | {id: .id, user: .user.login, body: .body, created_at: .created_at}]' 2>/dev/null || echo "[]")

# ── Changed files ──
DIFF_FILES=$(gh pr diff "$PR_NUMBER" 2>/dev/null | grep -E "^\+\+\+ b/" | sed 's/+++ b\///' || echo "")

# ── 输出 ──
jq -n \
  --argjson pr "$PR_META" \
  --arg owner "$OWNER" \
  --arg repo "$REPO" \
  --arg branch "$BRANCH" \
  --arg headOid "$HEAD_OID" \
  --argjson reviews "$REVIEWS" \
  --argjson reviewComments "$REVIEW_COMMENTS" \
  --argjson issueComments "$ISSUE_COMMENTS" \
  --arg diffFiles "$DIFF_FILES" \
  '{
    owner: $owner,
    repo: $repo,
    branch: $branch,
    head_oid: $headOid,
    pr_number: $pr.number,
    title: $pr.title,
    author: $pr.author.login,
    base_ref: $pr.baseRefName,
    mergeable: $pr.mergeable,
    changed_files: $pr.changedFiles,
    additions: $pr.additions,
    deletions: $pr.deletions,
    url: $pr.url,
    reviews: $reviews,
    review_comments: $reviewComments,
    issue_comments: $issueComments,
    diff_files: ($diffFiles | split("\n") | map(select(length > 0)))
  }'
