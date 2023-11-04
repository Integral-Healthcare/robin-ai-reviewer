#!/usr/bin/env bash

trap "exit 1" TERM
export TOP_PID=$$

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/gitlab.sh"
source "$HOME_DIR/src/gpt.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh --git_provider=<(github|gitlab)> --git_token=<token> --open_ai_api_key=<token> [--gpt_model_name=<name>] [--github_api_url=<url>] [--files_to_ignore=<files>]
main() {
  eval "$(docpars -h "$(grep "^##?" "$HOME_DIR/src/main.sh" | cut -c 5-)" : "$@")"
  
  utils::set_default_env_vars
  utils::verify_required_env_vars

  check_commit_diff() {
    if [ -z "$commit_diff" ]; then
      utils::log_info "Nothing in the commit diff."
      exit
    fi
  }

  check_gpt_response() {
    if [ -z "$gpt_response" ]; then
      utils::log_error "GPT's response was NULL. Double check your API key and billing details."
    fi
  }

  export OPEN_AI_API_KEY="$open_ai_api_key"
  export GPT_MODEL="$gpt_model_name"

  case $git_provider in

    github)
      export GITHUB_TOKEN="$git_token"
      export GITHUB_API_URL="$github_api_url"
      local -r pr_number=$(github::get_pr_number)
      local -r commit_diff=$(github::get_commit_diff "$pr_number" "$files_to_ignore")
      check_commit_diff
      local -r gpt_response=$(gpt::prompt_model "$commit_diff")
      check_gpt_response
      github::comment "$gpt_response" "$pr_number"
    ;;

    gitlab)
      export GITLAB_TOKEN="$git_token"
      local -r commit_diff=$(gitlab::get_commit_diff "$files_to_ignore")
      check_commit_diff
      local -r gpt_response=$(gpt::prompt_model "$commit_diff")
      check_gpt_response
      gitlab::comment "$gpt_response"
    ;;

    *)
      utils::log_error "Git provider '$git_provider' is unknown"
      ;;
  esac

  exit $?
}
