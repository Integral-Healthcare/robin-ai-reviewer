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

  utils::env_variable_exist "GITHUB_REPOSITORY"
  utils::env_variable_exist "GITHUB_EVENT_PATH"
  utils::env_variable_exist "github_token"
  utils::env_variable_exist "github_api_url"
  utils::env_variable_exist "open_ai_api_key"
  utils::env_variable_exist "gpt_model_name"

  export GITHUB_TOKEN="$github_token"
  export GITHUB_API_URL="$github_api_url"
  export OPEN_AI_API_KEY="$open_ai_api_key"
  export GPT_MODEL="$gpt_model_name"

  local -r pr_number=$(utils::get_pr_number)
  local -r commit_diff=$(github::get_commit_diff "$pr_number")

  local -r gpt_response=$(gpt::prompt_model "$commit_diff")

  github::comment "$gpt_response" "$pr_number"

  exit $?
}
