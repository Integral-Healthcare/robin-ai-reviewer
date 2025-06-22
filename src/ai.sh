#!/usr/bin/env bash

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

ai::prompt_model() {
  local -r git_diff="$1"

  case "$AI_PROVIDER" in
    "openai")
      ai::prompt_openai "$git_diff"
      ;;
    "claude")
      ai::prompt_claude "$git_diff"
      ;;
    *)
      utils::log_error "Unsupported AI provider: $AI_PROVIDER. Supported providers: openai, claude"
      ;;
  esac
}

ai::prompt_openai() {
  local -r git_diff="$1"
  local -r api_url="https://api.openai.com/v1/chat/completions"

  local response
  response=$(curl -sSL \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $AI_API_KEY" \
    -d "$(jq -n \
      --arg model "$AI_MODEL" \
      --arg prompt "$INITIAL_PROMPT" \
      --arg git_diff "$git_diff" \
      '{
        model: $model,
        messages: [
          {role: "user", content: $prompt},
          {role: "user", content: $git_diff}
        ]
      }'
    )" \
    "$api_url")

  local error
  error=$(jq -r '.error' <<< "$response")

  if [[ "$error" != "null" ]]; then
    utils::log_error "API request to OpenAI failed: $error"
    return 1
  fi

  jq -r '.choices[0].message.content' <<< "$response"
}

ai::prompt_claude() {
  local -r git_diff="$1"
  local -r api_url="https://api.anthropic.com/v1/messages"

  local response
  response=$(curl -sSL \
    -H "Content-Type: application/json" \
    -H "x-api-key: $AI_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$(jq -n \
      --arg model "$AI_MODEL" \
      --arg prompt "$INITIAL_PROMPT" \
      --arg git_diff "$git_diff" \
      '{
        model: $model,
        max_tokens: 4096,
        messages: [
          {role: "user", content: $prompt},
          {role: "user", content: $git_diff}
        ]
      }'
    )" \
    "$api_url")

  local error
  error=$(jq -r '.error' <<< "$response")

  if [[ "$error" != "null" ]]; then
    utils::log_error "API request to Claude failed: $error"
    return 1
  fi

  # Claude returns content in a different format
  jq -r '.content[0].text' <<< "$response"
}
