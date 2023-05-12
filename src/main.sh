#!/usr/bin/env bash

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/gpt.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh --github_token=<token> --open_ai_api_key=<token> --gpt_model_name=<name> --github_api_url=<url>
main() {
  eval "$(/root/bin/docpars -h "$(grep "^##?" "$HOME_DIR/src/main.sh" | cut -c 5-)" : "$@")"

  verify_required_env_vars

  export GITHUB_TOKEN="$github_token"
  export GITHUB_API_URL="$github_api_url"
  export OPEN_AI_API_KEY="$open_ai_api_key"
  export GPT_MODEL="$gpt_model_name"

  local -r PR_NUMBER=$(github::get_pr_number)
  local -r COMMIT_DIFF=$(github::get_commit_diff "$PR_NUMBER")

   if [ -z "$COMMIT_DIFF" ]; then
    echoerr "Error: Failed to get the commit diff."
    exit 1
  fi

  local -r GPT_RESPONSE=$(gpt::prompt_model "$COMMIT_DIFF")

  if [ -z "$GPT_RESPONSE" ]; then
    echoerr "Error: GPT's response was NULL. Double check your API key and billing details."
    exit 1
  fi

  github::comment "$GPT_RESPONSE" "$PR_NUMBER"

  exit $?
}
