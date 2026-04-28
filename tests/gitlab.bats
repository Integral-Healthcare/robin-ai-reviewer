#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
  export GITLAB_TOKEN="fake-token"
  export CI_API_V4_URL="https://gitlab.example/api/v4"
  export CI_PROJECT_ID="42"
  export CI_MERGE_REQUEST_IID="7"
}

# Stub gitlab::api_request to dispatch on the URL's `page=N` query param so we
# can simulate pagination without a curl shim. (We cannot use a shell counter
# because api_request is invoked inside `$(...)`, so subshell mutations are
# lost.)
stub_api_pages() {
  # $1 = page1 body, $2 = page2 body (defaults to []), …
  export STUB_PAGE1="$1"
  export STUB_PAGE2="${2:-[]}"
  export STUB_PAGE3="${3:-[]}"
  gitlab::api_request() {
    local api_url="$2"
    # Extract the page= query parameter exactly so e.g. page=1 doesn't also
    # match page=10 / page=11 / page=100, which would loop forever.
    local page="${api_url##*page=}"
    page="${page%%&*}"
    case "$page" in
      1) printf "%s\n" "$STUB_PAGE1" ;;
      2) printf "%s\n" "$STUB_PAGE2" ;;
      3) printf "%s\n" "$STUB_PAGE3" ;;
      *) printf "[]\n" ;;
    esac
  }
}

@test "get_merge_request_diff: collects diffs from a single page" {
  stub_api_pages '[
    {"new_path":"src/main.sh","deleted_file":false,"diff":"@@ keep main.sh"}
  ]'

  run gitlab::get_merge_request_diff ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep main.sh"* ]]
}

@test "get_merge_request_diff: skips deleted files" {
  stub_api_pages '[
    {"new_path":"src/main.sh","deleted_file":false,"diff":"@@ keep"},
    {"new_path":"src/gone.sh","deleted_file":true,"diff":"@@ gone"}
  ]'

  run gitlab::get_merge_request_diff ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"@@ keep"* ]]
  [[ "$output" != *"@@ gone"* ]]
}

@test "get_merge_request_diff: paginates across multiple pages" {
  stub_api_pages \
    '[{"new_path":"src/a.sh","deleted_file":false,"diff":"@@ a"}]' \
    '[{"new_path":"src/b.sh","deleted_file":false,"diff":"@@ b"}]'

  run gitlab::get_merge_request_diff ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"@@ a"* ]]
  [[ "$output" == *"@@ b"* ]]
}

@test "get_merge_request_diff: respects files_to_ignore" {
  stub_api_pages '[
    {"new_path":"src/main.sh","deleted_file":false,"diff":"@@ keep"},
    {"new_path":"package-lock.json","deleted_file":false,"diff":"@@ skip"}
  ]'

  run gitlab::get_merge_request_diff "package-lock.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"@@ keep"* ]]
  [[ "$output" != *"@@ skip"* ]]
}
