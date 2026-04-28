#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
}

@test "should_ignore_file: returns true for exact match" {
  run utils::should_ignore_file "README.md" "README.md"
  [ "$status" -eq 0 ]
}

@test "should_ignore_file: returns false for non-match" {
  run utils::should_ignore_file "src/main.sh" "README.md"
  [ "$status" -eq 1 ]
}

@test "should_ignore_file: glob pattern matches" {
  run utils::should_ignore_file "assets/foo.png" "assets/*"
  [ "$status" -eq 0 ]
}

@test "should_ignore_file: glob pattern misses sibling dirs" {
  run utils::should_ignore_file "src/main.sh" "assets/*"
  [ "$status" -eq 1 ]
}

@test "should_ignore_file: handles multiple whitespace-separated patterns" {
  run utils::should_ignore_file "package-lock.json" "README.md package-lock.json"
  [ "$status" -eq 0 ]
}

@test "should_ignore_file: handles patterns wrapped in double quotes" {
  run utils::should_ignore_file "README.md" '"README.md"'
  [ "$status" -eq 0 ]
}

@test "should_ignore_file: returns false for empty pattern list" {
  run utils::should_ignore_file "src/main.sh" ""
  [ "$status" -eq 1 ]
}
