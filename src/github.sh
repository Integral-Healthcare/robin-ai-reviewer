#!/usr/bin/env bash

GITHUB_API_HEADER="Accept: application/vnd.github.v3.diff"

github::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}

# When no ignore patterns are provided, the unified `.diff` representation of
# the PR is the most faithful input for the model. When patterns are provided
# we have to fetch per-file metadata so we can filter, then reconstruct a
# diff-like blob.
#
# Pagination: GitHub caps `/files` at 100 entries per page, so we loop until
# we get a short page.
github::get_commit_diff() {
  local -r pr_number="$1"
  local -r files_to_ignore="$2"
  local -r api_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/pulls/$pr_number"

  if [[ -z "$files_to_ignore" ]]; then
    curl -sSL \
      --retry 3 --retry-delay 2 --retry-connrefused --max-time 120 \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "$GITHUB_API_HEADER" \
      "$api_url"
    return
  fi

  local diffs=""
  local page=1
  local per_page="${GITHUB_FILES_PER_PAGE:-100}"

  while true; do
    local body
    body=$(curl -sSL \
      --retry 3 --retry-delay 2 --retry-connrefused --max-time 120 \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "$api_url/files?per_page=$per_page&page=$page")

    local count
    count=$(jq 'length' <<< "$body" 2>/dev/null || echo 0)
    [[ "$count" -eq 0 ]] && break

    while read -r file; do
      local filename status patch
      filename=$(jq -r '.filename' <<< "$file")
      status=$(jq -r '.status' <<< "$file")
      patch=$(jq -r '.patch // empty' <<< "$file")

      [[ "$status" == "removed" ]] && continue
      [[ -z "$patch" ]] && continue

      if ! utils::should_ignore_file "$filename" "$files_to_ignore"; then
        # Prepend a synthetic diff header so the AI sees the same shape as the
        # raw `.diff` endpoint.
        diffs+="diff --git a/$filename b/$filename"$'\n'
        diffs+="$patch"
        diffs+=$'\n\n'
      fi
    done < <(jq -c '.[]' <<< "$body")

    [[ "$count" -lt "$per_page" ]] && break
    page=$((page + 1))
  done

  printf "%s" "$diffs"
}

github::comment() {
  local -r comment="$1"
  local -r pr_number="$2"
  local -r api_url="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$pr_number/comments"

  curl -sSL \
    --retry 3 --retry-delay 2 --retry-connrefused --max-time 60 \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg comment "$comment" '{body: $comment}')" \
    "$api_url"
}
