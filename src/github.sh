#!/usr/bin/env bash

GITHUB_API_HEADER="Accept: application/vnd.github.v3.diff"

github::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}

github::get_commit_diff() {
  local -r pr_number="$1"
  local -r files_to_ignore="${2}"

  if [ -z "$files_to_ignore" ]; then
    local -r body=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "$GITHUB_API_HEADER" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number")

    echo "$body"
  else
    local -r body=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "$GITHUB_API_HEADER" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number/files?per_page=100")

    local diffs=""

    for file in $(echo "$body" | jq -r '.[] | @base64'); do
      _jq() {
        echo ${file} | base64 -d | jq -r ${1}
      }

      filename=$(_jq '.filename')
      status=$(_jq '.status')
      ignore=false

      if [ "$status" == "removed" ]; then
        continue
      fi

      for pattern in $files_to_ignore; do
        if [[ $filename == $pattern ]]; then
          ignore=true
          break
        fi
      done

      if [ "$ignore" = false ]; then
        diffs+=$(_jq '.patch')
        diffs+=$'\n\n'
      fi
    done

    echo "$diffs"
  fi
}

github::comment() {
  local -r comment="$1"
  local -r pr_number="$2"

  curl -sSL \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg comment "$comment" '{body: $comment}')" \
    "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$pr_number/comments"
}