#!/usr/bin/env bash

gpt::prompt_model() {
  local -r git_diff="$1"
  local -r initial_prompt=$(cat <<EOF
root_language: $2
coding_principles: $3
ignored_principles: $4
Pretend you're the pull request reviewer on our software engineering team. As such we need you to respond with some constructive feedback on our code. \
Your main contribution to the team is providing crisp constructive feedback on how we can improve our code's quality. The code is primarily written in \
"root_language".\n\
The code will come as a git-diff. If a file is deleted, do not give feedback on it.\n\
You will first give feedback in the form of a score between 0-100. The number will estimate how likely the code change will be accepted. Assume the \
team only accepts high level production code, so they reject most initial code changes. Do not give a justification for your 0-100 score.\n\
Second, you will respond with a short list of improvements. Possible code improvements include but are certainly not limited to: "coding_principles". \
You are not to give feedback on "ignored_principles".\n\
Finally, you will respond with a code block. Important: If you assigned an score of >= 90, you should not produce a code block; instead respond "N/A". \
For scores < 90, the code block can either be a complete re-write of the code being scrutinized or a subset of it, but you should illustrate your \
feedback with a code example. Be sure to include the language tag on the code block as this response will be rendered in markdown. Do not explain the \
code block!\n\
The code block should be the last thing you output. Do not write any messaging after the code block.
EOF
)

  local -r body=$(curl -sSL \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPEN_AI_API_KEY" \
    -d "$(jq -n --arg model "$GPT_MODEL" --arg prompt "$initial_prompt" --arg git_diff "$git_diff" '{model: $model, messages: [{role: "user", content: $prompt}, {role: "user", content: $git_diff}]}')" \
    "https://api.openai.com/v1/chat/completions")

  local -r error=$(echo "$body" | jq -r '.error')

  if [[ "$error" != "null" ]]; then
    echoerr "API request failed: $error"
    exit 1
  fi

  local -r response=$(echo "$body" | jq -r '.choices[0].message.content')

  echo "$response"
}
