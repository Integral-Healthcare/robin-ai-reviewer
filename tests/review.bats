#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
  # review.sh isn't auto-loaded by test_helper so far.
  # shellcheck source=../src/review.sh
  source "$HOME_DIR/src/review.sh"
}

# Sample diff used by several tests below.
#
# src/foo.py hunk starts at new-file line 10:
#   line 10: ctx_a       (context)
#   line 11: ctx_b       (context)
#   line 12: added_12    (+ added)
#   line 13: ctx_c       (context)
#   line 14: added_14    (+ added)
#
# src/bar.py hunk starts at new-file line 20:
#   line 20: ctx_x       (context)
#   line 21: ctx_y       (context)
#   line 22: added_22    (+ added)
SAMPLE_DIFF='diff --git a/src/foo.py b/src/foo.py
--- a/src/foo.py
+++ b/src/foo.py
@@ -8,4 +10,5 @@ def existing():
 ctx_a
 ctx_b
+added_12
 ctx_c
+added_14
diff --git a/src/bar.py b/src/bar.py
--- a/src/bar.py
+++ b/src/bar.py
@@ -18,2 +20,3 @@
 ctx_x
 ctx_y
+added_22
'

@test "diff_added_lines: emits path/line for added lines on the new side" {
  result="$(printf '%s' "$SAMPLE_DIFF" | review::diff_added_lines)"
  [[ "$result" == *"src/foo.py"$'\t'"12"* ]]
  [[ "$result" == *"src/foo.py"$'\t'"14"* ]]
  [[ "$result" == *"src/bar.py"$'\t'"22"* ]]
}

@test "diff_added_lines: does not emit removed lines" {
  diff='diff --git a/x.py b/x.py
--- a/x.py
+++ b/x.py
@@ -1,2 +1,1 @@
-removed_old
 kept
'
  result="$(printf '%s' "$diff" | review::diff_added_lines)"
  [[ -z "$result" ]] || [[ "$result" != *"removed_old"* ]]
}

@test "filter_comments: keeps comments whose (path,line) match an added line" {
  comments='[
    {"path":"src/foo.py","line":12,"body":"good catch"},
    {"path":"src/bar.py","line":22,"body":"nice"},
    {"path":"src/foo.py","line":99,"body":"hallucinated"}
  ]'
  filtered="$(printf '%s' "$SAMPLE_DIFF" | review::filter_comments "$comments")"
  count=$(jq 'length' <<< "$filtered")
  [ "$count" -eq 2 ]
  [[ "$filtered" == *'"line": 12'* ]]
  [[ "$filtered" == *'"line": 22'* ]]
  [[ "$filtered" != *'"line": 99'* ]]
}

@test "filter_comments: drops comments on lines not in the diff" {
  comments='[{"path":"src/foo.py","line":1,"body":"out of range"}]'
  filtered="$(printf '%s' "$SAMPLE_DIFF" | review::filter_comments "$comments")"
  count=$(jq 'length' <<< "$filtered")
  [ "$count" -eq 0 ]
}

@test "create: invalid JSON falls back to plain comment" {
  export GITHUB_API_URL="https://api.github.example"
  export GITHUB_REPOSITORY="acme/widget"
  export GITHUB_TOKEN="t"

  github::comment() {
    echo "FALLBACK_COMMENT($1|$2)"
  }
  curl() {
    echo "CURL_CALLED"
  }

  run review::create "this is not json" 42 "$SAMPLE_DIFF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"FALLBACK_COMMENT(this is not json|42)"* ]]
  [[ "$output" != *"CURL_CALLED"* ]]
}

@test "create: valid JSON posts a review with filtered inline comments" {
  export GITHUB_API_URL="https://api.github.example"
  export GITHUB_REPOSITORY="acme/widget"
  export GITHUB_TOKEN="t"

  # Capture what curl is asked to send.
  curl() {
    # The payload is the value of the -d argument; print it back so the
    # test can inspect it.
    while [ $# -gt 0 ]; do
      if [[ "$1" == "-d" ]]; then
        printf 'PAYLOAD=%s\n' "$2"
      fi
      shift
    done
    echo '{"id":42,"state":"COMMENTED"}'
  }

  ai='{"summary":"LGTM overall","score":92,"comments":[
    {"path":"src/foo.py","line":12,"body":"comment1"},
    {"path":"src/foo.py","line":99,"body":"hallucinated"}
  ]}'

  run review::create "$ai" 42 "$SAMPLE_DIFF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"\"event\": \"COMMENT\""* ]]
  [[ "$output" == *"comment1"* ]]
  [[ "$output" != *"hallucinated"* ]]
  [[ "$output" == *"Score: 92"* ]]
}

@test "create: fails when GitHub returns an HTTP error" {
  export GITHUB_API_URL="https://api.github.example"
  export GITHUB_REPOSITORY="acme/widget"
  export GITHUB_TOKEN="t"

  curl() {
    echo '{"message":"Resource not accessible by integration","status":"403"}'
    return 22
  }

  ai='{"summary":"needs posting","score":80,"comments":[]}'

  run review::create "$ai" 42 "$SAMPLE_DIFF"
  [ "$status" -eq 22 ]
  [[ "$output" == *"Resource not accessible by integration"* ]]
}
