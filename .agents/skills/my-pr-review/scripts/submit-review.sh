#!/usr/bin/env bash
# submit-review.sh — Submit a PR review as COMMENT event (not APPROVE/REQUEST_CHANGES)
#
# GitHub 不允许 review 自己的 PR，所以必须用 COMMENT 事件。
# 此脚本处理 API 调用、格式验证和错误重试。
#
# Usage: submit-review.sh <PR_NUMBER> <REVIEW_BODY_FILE> [INLINE_COMMENTS_FILE]
#
# REVIEW_BODY_FILE: review 摘要 markdown 文件路径
# INLINE_COMMENTS_FILE (optional): JSON 文件，格式如下：
#   [{"path": "src/foo.py", "line": 42, "body": "comment text"}, ...]

set -euo pipefail

PR_NUMBER="${1:?Usage: submit-review.sh <PR_NUMBER> <REVIEW_BODY_FILE> [INLINE_COMMENTS_FILE]}"
REVIEW_BODY_FILE="${2:?Missing review body file}"
INLINE_COMMENTS_FILE="${3:-}"

# Resolve repo context
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

# Read review body
REVIEW_BODY=$(cat "$REVIEW_BODY_FILE")

if [[ -z "$REVIEW_BODY" ]]; then
  echo "ERROR: Review body is empty" >&2
  exit 1
fi

# Build the API payload
# Always use COMMENT event — we cannot APPROVE/REQUEST_CHANGES on our own PR
build_payload() {
  local body="$1"
  local comments_file="$2"

  if [[ -n "$comments_file" && -f "$comments_file" ]]; then
    # With inline comments — must use PR Review API with positioning
    # Each inline comment needs path + position (diff line position) OR path + line (for issue comments)
    # PR Review API comments: use `position` (0-indexed diff position) or `line` + `side`
    jq -n \
      --arg body "$body" \
      --slurpfile comments "$comments_file" \
      '{
        event: "COMMENT",
        body: $body,
        comments: [
          $comments[] | {
            path: .path,
            position: .position // .line,
            body: .body
          }
        ]
      }'
  else
    # No inline comments — simple review body
    jq -n \
      --arg body "$body" \
      '{
        event: "COMMENT",
        body: $body,
        comments: []
      }'
  fi
}

PAYLOAD=$(build_payload "$REVIEW_BODY" "$INLINE_COMMENTS_FILE")

# Submit via gh api — handles auth and error formatting
submit_review() {
  local payload="$1"
  local response

  response=$(echo "$payload" | gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
    --method POST \
    --input - \
    2>&1) || {
    # Parse GitHub API error for common issues
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // empty' 2>/dev/null)

    if [[ "$error_msg" == *"Invalid request"* ]]; then
      echo "WARN: GitHub API validation error. Retrying without inline comments..." >&2
      # Retry with body-only (no inline comments)
      local simple_payload
      simple_payload=$(jq -n --arg body "$REVIEW_BODY" '{event: "COMMENT", body: $body, comments: []}')
      echo "$simple_payload" | gh api "repos/${OWNER}/${REPO}/pulls/${PR_NUMBER}/reviews" \
        --method POST \
        --input - || {
        echo "ERROR: Failed to submit review even without inline comments" >&2
        echo "$response" >&2
        exit 1
      }
      echo "Review submitted (body-only, inline comments skipped due to API validation)" >&2
      return 0
    fi

    echo "ERROR: Failed to submit review" >&2
    echo "$response" >&2
    exit 1
  }

  # Success — extract review URL
  local review_id
  review_id=$(echo "$response" | jq -r '.id // empty')
  local review_url
  review_url=$(echo "$response" | jq -r '.html_url // empty')

  echo "Review submitted successfully"
  [[ -n "$review_id" ]] && echo "  Review ID: $review_id"
  [[ -n "$review_url" ]] && echo "  URL: $review_url"
}

submit_review "$PAYLOAD"

# Also add a label to the PR for tracking
echo "Adding review label to PR..."
gh pr edit "$PR_NUMBER" --add-label "reviewed" 2>/dev/null || true
