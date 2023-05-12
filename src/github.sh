#!/usr/bin/env bash

GITHUB_API_HEADER="Accept: application/vnd.github.v3.diff"

github::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}

github::get_commit_diff() {
  local -r pr_number="$1"
  local -r body=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "$GITHUB_API_HEADER" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number")

  echo "$body"
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