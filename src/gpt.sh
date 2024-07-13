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

gpt::prompt_model() {
  local -r git_diff="$1"
  local -r api_url="https://api.openai.com/v1/chat/completions"

  local response
  response=$(curl -sSL \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPEN_AI_API_KEY" \
    -d "$(jq -n \
      --arg model "$GPT_MODEL" \
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
    utils::log_error "API request to 'api.openai.com' failed: $error"
    return 1
  fi

  jq -r '.choices[0].message.content' <<< "$response"
}
