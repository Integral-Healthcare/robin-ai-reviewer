#!/usr/bin/env bash

# Helpers for "review" mode: instead of a single PR comment, the AI is asked
# to return structured JSON which we then turn into line-anchored review
# comments via the GitHub Reviews API.

# shellcheck disable=SC2034  # consumed by main.sh
INLINE_REVIEW_PROMPT=$(cat <<'EOF'
You are a Pull Request Code Reviewer. Review the unified diff below and
respond with a single JSON object — and nothing else — that conforms to:

{
  "summary": "Short overall summary of the change set (max 1 paragraph).",
  "score": 0-100,
  "comments": [
    {
      "path": "path/to/file.py",
      "line": <integer line number from the new (right) side of the diff>,
      "body": "Specific, actionable feedback for that line."
    }
  ]
}

Rules:
- Only return inline comments for lines that appear as additions (lines
  prefixed with `+`) in the diff. Do not comment on context or removed lines.
- `line` must be the absolute line number in the new file as shown by the
  hunk header (e.g., `@@ -12,3 +20,5 @@` means the new side starts at 20).
- If everything looks good, return an empty `comments` array and put your
  positive remarks in `summary`.
- Do not wrap the JSON in code fences or prose. The response MUST be parseable
  by `jq`.
EOF
)

# review::diff_added_lines reads a unified diff on stdin and prints
# `<path>\t<new_line_number>` for every line in the new file that actually
# exists in the diff (added or unchanged-context). Used to validate AI
# suggestions before sending them to GitHub.
review::diff_added_lines() {
  awk '
    /^diff --git a\// {
      # New file boundary; reset state.
      path = ""
      next
    }
    /^\+\+\+ b\// {
      path = substr($0, 7)
      next
    }
    /^@@ / {
      # @@ -old,oldlen +new,newlen @@
      match($0, /\+[0-9]+/)
      new_line = substr($0, RSTART + 1, RLENGTH - 1) + 0
      next
    }
    path == "" || new_line == 0 { next }
    /^\+/ && !/^\+\+\+/ {
      print path "\t" new_line
      new_line++
      next
    }
    /^-/ && !/^---/ {
      next
    }
    /^ / || /^$/ {
      new_line++
      next
    }
  '
}

# review::filter_comments keeps only comments whose (path, line) pairs
# correspond to an added line in the diff. Reads:
#   - stdin:        unified diff
#   - $1:           comments JSON array
# Prints the filtered array to stdout.
review::filter_comments() {
  local -r comments_json="$1"
  local valid_pairs
  valid_pairs="$(review::diff_added_lines)"

  if [[ -z "$valid_pairs" ]]; then
    echo "[]"
    return 0
  fi

  jq --arg pairs "$valid_pairs" '
    ($pairs | split("\n") | map(select(length > 0))) as $valid
    | map(select(((.path // "") + "\t" + ((.line // 0) | tostring)) as $key
                 | $valid | index($key)))
  ' <<< "$comments_json"
}

# review::create posts a GitHub PR review with inline comments. Falls back
# to a plain issue comment if the AI response isn't valid JSON.
#
# Args:
#   $1 raw AI response (expected to be JSON)
#   $2 PR number
#   $3 unified diff (used to validate inline comment positions)
review::create() {
  local -r ai_response="$1"
  local -r pr_number="$2"
  local -r diff="$3"

  local stripped
  stripped="$(printf '%s' "$ai_response" | sed -e 's/^```json//' -e 's/^```//' -e 's/```$//')"

  if ! jq -e '.' >/dev/null 2>&1 <<< "$stripped"; then
    utils::log_info "Inline-review JSON parse failed; falling back to a plain comment."
    github::comment "$ai_response" "$pr_number"
    return
  fi

  local summary score comments
  summary="$(jq -r '.summary // ""' <<< "$stripped")"
  score="$(jq -r '.score // empty' <<< "$stripped")"
  comments="$(jq -c '.comments // []' <<< "$stripped")"

  comments="$(printf '%s' "$diff" | review::filter_comments "$comments")"

  local body="$summary"
  if [[ -n "$score" ]]; then
    body="**Score: $score/100**"$'\n\n'"$summary"
  fi

  local payload
  payload="$(jq -n \
    --arg body "$body" \
    --argjson comments "$comments" \
    '{
      event: "COMMENT",
      body: $body,
      comments: ($comments | map({path, line, body, side: "RIGHT"}))
    }')"

  local api_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number/reviews"
  curl -sSL \
    --fail-with-body \
    --retry 3 --retry-delay 2 --retry-connrefused --max-time 60 \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$api_url"
}
