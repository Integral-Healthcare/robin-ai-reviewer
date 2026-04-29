#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
  export GITHUB_TOKEN="fake-token"
  export GITHUB_API_URL="https://api.github.example"
  export GITHUB_REPOSITORY="acme/widget"

  # Sandbox so the mock curl is preferred over the real binary.
  TMPBIN="$(mktemp -d)"
  export TMPBIN
  export PATH="$TMPBIN:$PATH"
}

teardown() {
  rm -rf "$TMPBIN"
}

# Install a curl shim that returns whatever we put in $TMPBIN/curl.body.
install_curl_shim() {
  # Bake the absolute path into the shim so it doesn't rely on $TMPBIN being
  # exported to curl's child environment. Extract `page=N` exactly to avoid
  # glob ambiguity (page=10 must not match the page=1 case).
  cat > "$TMPBIN/curl" <<SH
#!/usr/bin/env bash
url=""
for arg in "\$@"; do
  case "\$arg" in
    http*) url="\$arg" ;;
  esac
done
page="\${url##*page=}"
page="\${page%%&*}"
case "\$page" in
  1) cat "$TMPBIN/page1.json" ;;
  2) cat "$TMPBIN/page2.json" ;;
  3) cat "$TMPBIN/page3.json" ;;
  *) cat "$TMPBIN/default.json" 2>/dev/null || echo "[]" ;;
esac
SH
  chmod +x "$TMPBIN/curl"
}

@test "get_commit_diff: walks all pages, not just the first" {
  install_curl_shim
  # With per_page=3, page 1 returns a "full" page so the paginator must
  # keep fetching. Page 2 has 1 entry, then page 3 is empty so we stop.
  export GITHUB_FILES_PER_PAGE=3
  jq -nc '[range(0;3) | {filename:("file_"+(tostring)+".py"), status:"modified", patch:"@@ x"}]' \
    > "$TMPBIN/page1.json"
  jq -nc '[{filename:"final.py", status:"modified", patch:"@@ y"}]' \
    > "$TMPBIN/page2.json"
  echo "[]" > "$TMPBIN/page3.json"

  run github::get_commit_diff 42 "ignored.txt"
  [ "$status" -eq 0 ]
  count=$(grep -c '^diff --git ' <<<"$output" || true)
  [ "$count" -eq 4 ]
  [[ "$output" == *"diff --git a/file_0.py b/file_0.py"* ]]
  [[ "$output" == *"diff --git a/file_2.py b/file_2.py"* ]]
  [[ "$output" == *"diff --git a/final.py b/final.py"* ]]
}

@test "get_commit_diff: skips removed files and null patches" {
  install_curl_shim
  cat > "$TMPBIN/page1.json" <<'JSON'
[
  {"filename":"keep.py","status":"modified","patch":"@@ keep"},
  {"filename":"gone.py","status":"removed","patch":"@@ gone"},
  {"filename":"binary.bin","status":"modified","patch":null}
]
JSON
  echo "[]" > "$TMPBIN/page2.json"

  run github::get_commit_diff 42 "nothing"
  [ "$status" -eq 0 ]
  [[ "$output" == *"diff --git a/keep.py b/keep.py"* ]]
  [[ "$output" != *"gone.py"* ]]
  [[ "$output" != *"binary.bin"* ]]
  [[ "$output" != *"null"* ]]
}

@test "get_commit_diff: respects files_to_ignore" {
  install_curl_shim
  cat > "$TMPBIN/page1.json" <<'JSON'
[
  {"filename":"src/main.sh","status":"modified","patch":"@@ keep"},
  {"filename":"package-lock.json","status":"modified","patch":"@@ skip"}
]
JSON
  echo "[]" > "$TMPBIN/page2.json"

  run github::get_commit_diff 42 "package-lock.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"diff --git a/src/main.sh b/src/main.sh"* ]]
  [[ "$output" != *"package-lock.json"* ]]
}

@test "comment: fails when GitHub returns an HTTP error" {
  curl() {
    echo '{"message":"Resource not accessible by integration","status":"403"}'
    return 22
  }

  run github::comment "review body" 42
  [ "$status" -eq 22 ]
  [[ "$output" == *"Resource not accessible by integration"* ]]
}
