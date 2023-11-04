#!/usr/bin/env bash

GITLAB_API_HEADER="Content-Type: application/json"

gitlab::get_commit_diff() {
  local -r files_to_ignore="${1}"
  local -r response=$(curl -w "%{http_code}" -sSL -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "$GITLAB_API_HEADER" "$CI_API_V4_URL/projects/$CI_PROJECT_ID/repository/commits/$CI_COMMIT_SHA/diff")
  
  local -r http_code=${response: -3}
  local -r body=$(echo ${response} | head -c-4)

  if [ $http_code != "200" ]; then
    kill -s TERM $TOP_PID
    local -r error=$(echo "$body" | jq -r '.')
    utils::log_error "API request to '$CI_API_V4_URL' failed: $error"
  fi

  if [ -z "${files_to_ignore}" ]; then
    echo "${body}"
  else
    local diffs=""

    for file in $(echo "${body}" | jq -r '.[] | @base64 '); do
      _jq() {
        echo "${file}" | base64 -d | jq -r "${1}"
      }

      filename=$(_jq '.new_path')
      ignore=false

      for pattern in $files_to_ignore; do
        if [[ "${filename}" == "${pattern}" ]]; then
          ignore=true
          break
        fi
      done

      if [ $ignore = false ]; then
        diffs+=$(_jq '.diff')
        diffs+=$'\n\n'
      fi
    done
    echo "${diffs}"
  fi
}

gitlab::comment() {
  local -r comment="$1"
  
  curl -sSL \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "$GITLAB_API_HEADER" \
    -X POST \
    -d "$(jq -n --arg comment "$comment" '{body: $comment}')" \
    "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
}