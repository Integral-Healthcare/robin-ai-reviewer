#!/usr/bin/env bash

GITLAB_API_HEADER="Content-Type: application/json"

gitlab::api_request() {
  local -r method="$1"
  local -r api_url="$2"
  local -r data="${3:-}"

  local response
  if [[ -n "$data" ]]; then
    response=$(curl -sSL -w $'\n%{http_code}' \
      -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      -H "$GITLAB_API_HEADER" \
      -X "$method" \
      -d "$data" \
      "$api_url")
  else
    response=$(curl -sSL -w $'\n%{http_code}' \
      -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      -H "$GITLAB_API_HEADER" \
      -X "$method" \
      "$api_url")
  fi

  local http_code body
  http_code="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [[ ! "$http_code" =~ ^2 ]]; then
    local error
    error=$(jq -r '.message // .error // .' <<< "$body" 2>/dev/null || printf "%s" "$body")
    utils::log_error "API request to GitLab failed with status $http_code: $error"
  fi

  printf "%s\n" "$body"
}

gitlab::get_merge_request_diff() {
  local -r files_to_ignore="${1:-}"
  local diffs=""
  local page=1

  while true; do
    local page_body
    page_body=$(gitlab::api_request \
      "GET" \
      "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/diffs?per_page=100&page=$page")

    local page_length
    page_length=$(jq 'length' <<< "$page_body")
    [[ "$page_length" -eq 0 ]] && break

    while IFS= read -r file; do
      local filename deleted diff
      filename=$(jq -r '.new_path' <<< "$file")
      deleted=$(jq -r '.deleted_file // false' <<< "$file")
      diff=$(jq -r '.diff // empty' <<< "$file")

      [[ "$deleted" == "true" || -z "$diff" ]] && continue

      if ! utils::should_ignore_file "$filename" "$files_to_ignore"; then
        diffs+="$diff"
        diffs+=$'\n\n'
      fi
    done < <(jq -c '.[]' <<< "$page_body")

    page=$((page + 1))
  done

  printf "%s" "$diffs"
}

gitlab::comment() {
  local -r comment="$1"
  local -r api_url="$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"

  gitlab::api_request \
    "POST" \
    "$api_url" \
    "$(jq -n --arg comment "$comment" '{body: $comment}')"
}
