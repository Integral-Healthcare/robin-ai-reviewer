#!/usr/bin/env bash

set -euo pipefail

trap 'exit 1' TERM
export TOP_PID=$$

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/ai.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh --github_token=<token> --ai_provider=<provider> --ai_api_key=<key> --ai_model=<model> --github_api_url=<url> --files_to_ignore=<files> --open_ai_api_key=<token> --gpt_model_name=<name>
main() {
  local github_token ai_provider ai_api_key ai_model github_api_url files_to_ignore
  local open_ai_api_key gpt_model_name  # Legacy parameters

  eval "$(docpars -h "$(grep "^##?" "${BASH_SOURCE[0]}" | cut -c 5-)" : "$@")"

  # Handle backward compatibility - use legacy params if new ones aren't provided
  if [[ -n "${open_ai_api_key:-}" && -z "${ai_api_key:-}" ]]; then
    ai_api_key="$open_ai_api_key"
    utils::log_info "Using legacy OPEN_AI_API_KEY parameter. Consider migrating to AI_API_KEY."
  fi

  if [[ -n "${gpt_model_name:-}" && -z "${ai_model:-}" ]]; then
    ai_model="$gpt_model_name"
    utils::log_info "Using legacy gpt_model_name parameter. Consider migrating to AI_MODEL."
  fi

  # Set default provider if not specified
  if [[ -z "${ai_provider:-}" ]]; then
    ai_provider="openai"
  fi

  # Set default model based on provider if not specified
  if [[ -z "${ai_model:-}" ]]; then
    case "$ai_provider" in
      "openai")
        ai_model="o4-mini"
        ;;
      "claude")
        ai_model="claude-3-7-sonnet-20250219"
        ;;
      *)
        ai_model="o4-mini"
        ;;
    esac
  fi

  utils::verify_required_env_vars

  export GITHUB_TOKEN="$github_token"
  export GITHUB_API_URL="$github_api_url"
  export AI_PROVIDER="$ai_provider"
  export AI_API_KEY="$ai_api_key"
  export AI_MODEL="$ai_model"

  local pr_number commit_diff ai_response
  pr_number=$(github::get_pr_number)
  commit_diff=$(github::get_commit_diff "$pr_number" "${files_to_ignore[*]}")

  if [[ -z "$commit_diff" ]]; then
    utils::log_info "Nothing in the commit diff."
    exit 0
  fi

  ai_response=$(ai::prompt_model "$commit_diff")

  if [[ -z "$ai_response" ]]; then
    utils::log_error "AI response was empty. Double check your API key and billing details."
    exit 1
  fi

  github::comment "$ai_response" "$pr_number"
}
