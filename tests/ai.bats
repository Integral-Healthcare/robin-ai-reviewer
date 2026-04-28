#!/usr/bin/env bats

setup() {
  load test_helper
  load_sources
}

@test "is_openai_reasoning_model: gpt-5-mini -> reasoning" {
  run ai::is_openai_reasoning_model "gpt-5-mini"
  [ "$status" -eq 0 ]
}

@test "is_openai_reasoning_model: gpt-5 -> reasoning" {
  run ai::is_openai_reasoning_model "gpt-5"
  [ "$status" -eq 0 ]
}

@test "is_openai_reasoning_model: o3 -> reasoning" {
  run ai::is_openai_reasoning_model "o3"
  [ "$status" -eq 0 ]
}

@test "is_openai_reasoning_model: o4-mini -> reasoning" {
  run ai::is_openai_reasoning_model "o4-mini"
  [ "$status" -eq 0 ]
}

@test "is_openai_reasoning_model: gpt-4.1-mini -> classic" {
  run ai::is_openai_reasoning_model "gpt-4.1-mini"
  [ "$status" -eq 1 ]
}

@test "is_openai_reasoning_model: claude model -> classic" {
  run ai::is_openai_reasoning_model "claude-sonnet-4-5"
  [ "$status" -eq 1 ]
}

@test "max_tokens: returns default when AI_MAX_TOKENS unset" {
  unset AI_MAX_TOKENS
  result="$(ai::max_tokens)"
  [ "$result" = "8192" ]
}

@test "max_tokens: returns override when AI_MAX_TOKENS set" {
  AI_MAX_TOKENS=1024 result="$(AI_MAX_TOKENS=1024 ai::max_tokens)"
  [ "$result" = "1024" ]
}

@test "resolve_prompt: defaults to AI_DEFAULT_PROMPT" {
  unset AI_PROMPT_OVERRIDE AI_PROMPT_FILE
  run ai::resolve_prompt
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pull Request Code Reviewer"* ]]
}

@test "resolve_prompt: AI_PROMPT_OVERRIDE wins" {
  unset AI_PROMPT_FILE
  AI_PROMPT_OVERRIDE="custom inline prompt"
  result="$(AI_PROMPT_OVERRIDE='custom inline prompt' ai::resolve_prompt)"
  [ "$result" = "custom inline prompt" ]
}

@test "resolve_prompt: AI_PROMPT_FILE is read when no override" {
  unset AI_PROMPT_OVERRIDE
  tmp="$(mktemp)"
  printf "file-based prompt\n" > "$tmp"
  result="$(AI_PROMPT_FILE="$tmp" ai::resolve_prompt)"
  rm -f "$tmp"
  [[ "$result" == *"file-based prompt"* ]]
}

@test "resolve_prompt: missing AI_PROMPT_FILE produces an error" {
  unset AI_PROMPT_OVERRIDE
  run env AI_PROMPT_FILE="/nonexistent/path/$$" bash -c '
    source "'"$HOME_DIR"'/src/utils.sh"
    utils::log_error() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }
    source "'"$HOME_DIR"'/src/ai.sh"
    ai::resolve_prompt
  '
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing or not readable"* ]]
}

@test "prompt_model: routes to openai when AI_PROVIDER=openai" {
  AI_PROVIDER="openai"
  ai::prompt_openai() { echo "OPENAI_CALLED:$1"; }
  ai::prompt_claude() { echo "CLAUDE_CALLED:$1"; }
  run ai::prompt_model "diff-text"
  [ "$status" -eq 0 ]
  [ "$output" = "OPENAI_CALLED:diff-text" ]
}

@test "prompt_model: routes to claude when AI_PROVIDER=claude" {
  AI_PROVIDER="claude"
  ai::prompt_openai() { echo "OPENAI_CALLED:$1"; }
  ai::prompt_claude() { echo "CLAUDE_CALLED:$1"; }
  run ai::prompt_model "diff-text"
  [ "$status" -eq 0 ]
  [ "$output" = "CLAUDE_CALLED:diff-text" ]
}

@test "prompt_model: errors on unknown provider" {
  AI_PROVIDER="bogus"
  run ai::prompt_model "diff"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported AI provider"* ]]
}
