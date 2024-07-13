#!/usr/bin/env bash

GITHUB_API_HEADER="Accept: application/vnd.github.v3.diff"

github::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}

github::get_commit_diff() {
  local -r pr_number="$1"
  local -r files_to_ignore="$2"
  local -r api_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number"

  if [[ -z "$files_to_ignore" ]]; then
    curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "$GITHUB_API_HEADER" "$api_url"
  else
    local body
    body=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$api_url/files?per_page=100")

    local diffs=""
    while read -r file; do
      local filename status
      filename=$(jq -r '.filename' <<< "$file")
      status=$(jq -r '.status' <<< "$file")

      [[ "$status" == "removed" ]] && continue

      if ! github::should_ignore_file "$filename" "$files_to_ignore"; then
        diffs+=$(jq -r '.patch' <<< "$file")
        diffs+=$'\n\n'
      fi
    done < <(jq -c '.[]' <<< "$body")

    echo "$diffs"
  fi
}

github::should_ignore_file() {
  local -r filename="$1"
  local -r files_to_ignore="$2"

  for pattern in $files_to_ignore; do
    [[ "$filename" == $pattern ]] && return 0
  done

  return 1
}

github::comment() {
  local -r comment="$1"
  local -r pr_number="$2"
  local -r api_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$pr_number/comments"

  curl -sSL \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg comment "$comment" '{body: $comment}')" \
    "$api_url"
}