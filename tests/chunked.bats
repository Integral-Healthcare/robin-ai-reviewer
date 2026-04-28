#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
  # shellcheck source=../src/chunked.sh
  source "$HOME_DIR/src/chunked.sh"
}

THREE_FILE_DIFF='diff --git a/src/foo.py b/src/foo.py
--- a/src/foo.py
+++ b/src/foo.py
@@ -1 +1,2 @@
 ctx
+added foo
diff --git a/src/bar.py b/src/bar.py
--- a/src/bar.py
+++ b/src/bar.py
@@ -1 +1,2 @@
 ctx
+added bar
diff --git a/src/baz/qux.py b/src/baz/qux.py
--- a/src/baz/qux.py
+++ b/src/baz/qux.py
@@ -1 +1,2 @@
 ctx
+added qux
'

@test "split_by_file: emits one chunk per file separated by sentinel" {
  output="$(printf '%s' "$THREE_FILE_DIFF" | chunked::split_by_file)"
  # Three files -> two boundary sentinels.
  count=$(grep -c '^<<<ROBIN_CHUNK_BOUNDARY>>>$' <<< "$output" || true)
  [ "$count" -eq 2 ]
}

@test "split_by_file: each chunk starts with a diff header" {
  output="$(printf '%s' "$THREE_FILE_DIFF" | chunked::split_by_file)"
  # First and post-sentinel lines must begin with `diff --git a/`.
  awk '
    NR == 1 && !/^diff --git a\// { exit 1 }
    prev_was_sentinel && !/^diff --git a\// { exit 1 }
    { prev_was_sentinel = ($0 == "<<<ROBIN_CHUNK_BOUNDARY>>>") }
  ' <<< "$output"
}

@test "file_path_of_chunk: extracts the b-side path" {
  chunk='diff --git a/src/baz/qux.py b/src/baz/qux.py
--- a/src/baz/qux.py
+++ b/src/baz/qux.py
@@ -1 +1,2 @@
 ctx
+x
'
  result="$(chunked::file_path_of_chunk "$chunk")"
  [ "$result" = "src/baz/qux.py" ]
}

@test "review: invokes ai::prompt_model once per file and aggregates" {
  # Use a file-based counter because the stub gets called inside $()
  # subshells, so a regular shell variable wouldn't survive across calls.
  counter_file="$(mktemp)"
  echo 0 > "$counter_file"
  export COUNTER_FILE="$counter_file"

  ai::prompt_model() {
    local n
    n=$(< "$COUNTER_FILE")
    n=$((n+1))
    echo "$n" > "$COUNTER_FILE"
    echo "REVIEW_$n"
  }

  result="$(chunked::review "$THREE_FILE_DIFF")"
  [[ "$result" == *"## \`src/foo.py\`"* ]]
  [[ "$result" == *"## \`src/bar.py\`"* ]]
  [[ "$result" == *"## \`src/baz/qux.py\`"* ]]
  [[ "$result" == *"REVIEW_1"* ]]
  [[ "$result" == *"REVIEW_2"* ]]
  [[ "$result" == *"REVIEW_3"* ]]

  total="$(< "$counter_file")"
  [ "$total" -eq 3 ]
  rm -f "$counter_file"
}

@test "review: substitutes a placeholder when the AI returns nothing" {
  ai::prompt_model() { :; }  # echoes nothing
  result="$(chunked::review "$THREE_FILE_DIFF")"
  [[ "$result" == *"_(no feedback returned)_"* ]]
}

@test "review: falls through to single-shot when there are no diff headers" {
  ai::prompt_model() { echo "SINGLE_SHOT"; }
  result="$(chunked::review "this is not a diff at all")"
  [ "$result" = "SINGLE_SHOT" ]
}
