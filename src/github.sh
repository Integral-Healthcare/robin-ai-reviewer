#!/usr/bin/env bash

GITHUB_API_DIFF_HEADER="Accept: application/vnd.github.v3.diff"
GITHUB_API_HEADER="Accept: application/vnd.github.v3+json"

# Gets the PR number from the GitHub event
github::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}

# Gets the diff of the commit in the PR
github::get_commit_diff() {
  local -r PR_NUMBER="$1"
  local -r BODY=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "$GITHUB_API_DIFF_HEADER" "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

  if [[ "$BODY" == *"Not Found"* ]]; then
    echoerr "Error: Pull request not found."
    exit 1
  fi

  echo "$BODY"
}

# Posts a comment on the PR
github::comment() {
  local -r COMMENT="$1"
  local -r PR_NUMBER="$2"

  local -r RESPONSE=$(curl -sSL \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "$GITHUB_API_HEADER" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg comment "$COMMENT" '{body: $comment}')" \
    "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments")

  if [[ "$RESPONSE" == *"Not Found"* ]]; then
    echoerr "Error: Failed to post comment."
    exit 1
  fi

  echo "Comment posted successfully."
}
