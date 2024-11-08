#!/usr/bin/env bash
#
# OpenAI GPT Module
# Handles all interactions with OpenAI's GPT API for code review generation
#
# This module provides functionality to:
# 1. Make authenticated requests to OpenAI's GPT API with retry logic
# 2. Format and validate code review prompts
# 3. Process and validate API responses
# 4. Handle token limits and error conditions
#
# Dependencies:
#   - error_handler.sh: Error handling and retry logic
#   - utils.sh: Logging and utility functions
#   - jq: JSON parsing utility
#
# Environment Variables:
#   OPEN_AI_API_KEY: OpenAI API authentication token
#   GPT_MODEL: GPT model to use (default: gpt-3.5-turbo)
#   MAX_TOKENS: Maximum tokens per request (default: 4096)

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/error_handler.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

readonly MAX_RETRIES=3
readonly RETRY_DELAY=2
# Maximum tokens per request (used in API calls)
# shellcheck disable=SC2034  # Used in API requests
readonly MAX_TOKENS=4096
readonly OPENAI_API_URL="https://api.openai.com/v1/chat/completions"

INITIAL_PROMPT=$(cat <<EOF
You are a Pull Request Code Reviewer in our engineering team. Your task is to provide constructive feedback on code changes to improve quality, maintainability, and readability.

Guidelines:
1. Review the provided Git diff.
2. Ignore deleted files, configuration files, README files, package.json, and non-code files.
3. If all files are non-code, respond with "nothing to grade" and stop.

Scoring:
- Assign a score from 0-100 based on code quality and acceptability.
- Assume high standards for production code.

Feedback:
- Provide a concise list of potential improvements (e.g., naming, simplification, edge cases, optimization, unused code removal, SOLID principles).
- Focus on code improvements rather than comments.

Output Format:
<details>
<summary>Score: [0-100]</summary>

Improvements:
- [Bullet point 1]
- [Bullet point 2]
- ...

\`\`\`[language]
[Example code block if score < 90]
\`\`\`
</details>

Note: Include the code block only for scores below 90.
EOF
)

# Description: Validates the response from OpenAI API
# Arguments:
#   $1 - API response JSON
#   $2 - Context for error messages
# Returns:
#   0 on success, non-zero on failure
# Notes:
#   - Checks for empty responses
#   - Validates JSON structure
#   - Handles API error messages
#   - Verifies required response fields
gpt::validate_response() {
  local response="$1"
  local context="$2"

  # Check for empty response
  if [[ -z "$response" ]]; then
    error_handler::handle_error "$E_API_ERROR" \
      "$context" \
      "Empty response from OpenAI API"
    return 1
  fi

  # Check for API errors
  local error
  error=$(jq -r '.error.message // .error // empty' <<< "$response")
  if [[ -n "$error" ]]; then
    error_handler::handle_error "$E_API_ERROR" \
      "$context" \
      "OpenAI API error: $error"
    return 1
  fi

  # Validate response structure
  if ! jq -e '.choices[0].message.content' <<< "$response" >/dev/null; then
    error_handler::handle_error "$E_API_ERROR" \
      "$context" \
      "Invalid response structure from OpenAI API"
    return 1
  fi

  return 0
}

gpt::make_api_request() {
  local model="$1"
  local messages="$2"
  local context="$3"

  local data
  data=$(jq -n \
    --arg model "$model" \
    --argjson messages "$messages" \
    '{
      model: $model,
      messages: $messages
    }')

  local curl_args=(
    -sSL
    -H "Content-Type: application/json"
    -H "Authorization: Bearer $OPEN_AI_API_KEY"
    -d "$data"
    "$OPENAI_API_URL"
  )

  local response
  # Pass curl command as array to preserve argument handling
  response=$(error_handler::retry curl "${curl_args[@]}" "$MAX_RETRIES" "$RETRY_DELAY")

  if ! gpt::validate_response "$response" "$context"; then
    return 1
  fi

  echo "$response"
}

gpt::prompt_model() {
  local -r git_diff="$1"
  local context="OpenAI API request"

  # Validate inputs
  if [[ -z "$git_diff" ]]; then
    utils::log_warn "Empty git diff provided" "$context"
    echo "nothing to grade"
    return 0
  fi

  if [[ -z "$GPT_MODEL" ]]; then
    error_handler::handle_error "$E_INVALID_INPUT" \
      "$context" \
      "GPT model name not specified"
    return 1
  fi

  if [[ -z "$OPEN_AI_API_KEY" ]]; then
    error_handler::handle_error "$E_INVALID_INPUT" \
      "$context" \
      "OpenAI API key not provided"
    return 1
  fi

  # Prepare messages
  local messages
  messages=$(jq -n \
    --arg prompt "$INITIAL_PROMPT" \
    --arg git_diff "$git_diff" \
    '[
      {role: "user", content: $prompt},
      {role: "user", content: $git_diff}
    ]')

  # Make API request and handle errors
  local response
  response=$(gpt::make_api_request "$GPT_MODEL" "$messages" "$context") || return 1

  # Extract and return the content from the response
  jq -r '.choices[0].message.content' <<< "$response"
}
