#!/usr/bin/env bash

set -euo pipefail

trap 'exit 1' TERM
export TOP_PID=$$

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/gpt.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh --github_token=<token> --open_ai_api_key=<token> --gpt_model_name=<name> --github_api_url=<url> --files_to_ignore=<files>
main() {
  local github_token="" open_ai_api_key="" gpt_model_name="gpt-3.5-turbo" github_api_url="https://api.github.com" files_to_ignore=""
  utils::parse_args "$@"

  utils::verify_required_env_vars

  export GITHUB_TOKEN="$github_token"
  export GITHUB_API_URL="$github_api_url"
  export OPEN_AI_API_KEY="$open_ai_api_key"
  export GPT_MODEL="$gpt_model_name"

  local pr_number commit_diff gpt_response
  pr_number=$(github::get_pr_number)
  commit_diff=$(github::get_commit_diff "$pr_number" "${files_to_ignore[*]}")

  if [[ -z "$commit_diff" ]]; then
    utils::log_info "Nothing in the commit diff."
    exit 0
  fi

  gpt_response=$(gpt::prompt_model "$commit_diff")

  if [[ -z "$gpt_response" ]]; then
    utils::log_error "GPT's response was empty. Double check your API key and billing details."
    # utils::log_error already calls exit 1, so we don't need it here
  fi

  github::comment "$gpt_response" "$pr_number"
}
