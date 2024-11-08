#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
if [[ -f .env.development ]]; then
  source .env.development
else
  echo "Error: .env.development file not found"
  exit 1
fi

# Verify required environment variables
required_vars=(
  "GITHUB_TOKEN"
  "GITHUB_REPOSITORY"
  "GITHUB_API_URL"
  "GITHUB_EVENT_PATH"
  "OPEN_AI_API_KEY"
  "GPT_MODEL"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set in .env.development"
    exit 1
  fi
done

# Run the main script with development arguments
./src/main.sh \
  --github_token="$GITHUB_TOKEN" \
  --open_ai_api_key="$OPEN_AI_API_KEY" \
  --gpt_model_name="$GPT_MODEL" \
  --github_api_url="$GITHUB_API_URL" \
  --files_to_ignore=""
