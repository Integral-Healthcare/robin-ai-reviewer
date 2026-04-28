#!/usr/bin/env bash

set -euo pipefail

trap 'exit 1' TERM
export TOP_PID=$$

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/gitlab.sh"
source "$HOME_DIR/src/ai.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh [--git_provider=<provider>] [--git_token=<token>] [--github_token=<token>] [--ai_provider=<provider>] [--ai_api_key=<key>] [--ai_model=<model>] [--ai_max_tokens=<n>] [--max_diff_bytes=<n>] [--prompt_override=<text>] [--prompt_file=<path>] [--github_api_url=<url>] [--files_to_ignore=<files>] [--open_ai_api_key=<token>] [--gpt_model_name=<name>]
main() {
  local git_provider git_token github_token ai_provider ai_api_key ai_model ai_max_tokens max_diff_bytes prompt_override prompt_file github_api_url files_to_ignore
  local open_ai_api_key gpt_model_name  # Legacy parameters

  eval "$(docpars -h "$(grep "^##?" "${BASH_SOURCE[0]}" | cut -c 5-)" : "$@")"

  # Prefer secrets passed via env (so they don't show up in `ps` or be
  # echoed back into workflow logs). Fall back to CLI flags so the
  # docker / GitLab CI usage still works for users invoking the entrypoint
  # directly.
  if [[ -n "${GITHUB_TOKEN_INPUT:-}" && -z "${github_token:-}" ]]; then
    github_token="$GITHUB_TOKEN_INPUT"
  fi
  if [[ -n "${AI_API_KEY_INPUT:-}" && -z "${ai_api_key:-}" ]]; then
    ai_api_key="$AI_API_KEY_INPUT"
  fi
  if [[ -n "${OPEN_AI_API_KEY_INPUT:-}" && -z "${open_ai_api_key:-}" ]]; then
    open_ai_api_key="$OPEN_AI_API_KEY_INPUT"
  fi

  if [[ -z "${git_provider:-}" ]]; then
    git_provider="github"
  fi

  if [[ -n "${github_token:-}" && -z "${git_token:-}" ]]; then
    git_token="$github_token"
  fi

  if [[ -z "${github_api_url:-}" ]]; then
    github_api_url="https://api.github.com"
  fi

  if [[ -z "${files_to_ignore:-}" ]]; then
    files_to_ignore=""
  fi

  # Handle backward compatibility - use legacy params if new ones aren't provided.
  # NOTE: OPEN_AI_API_KEY and gpt_model_name are scheduled for removal in v2.0 (target 2026-Q3).
  if [[ -n "${open_ai_api_key:-}" && -z "${ai_api_key:-}" ]]; then
    ai_api_key="$open_ai_api_key"
    utils::log_info "[DEPRECATION] OPEN_AI_API_KEY will be removed in v2.0 (target 2026-Q3). Migrate to AI_API_KEY."
  fi

  if [[ -n "${gpt_model_name:-}" && -z "${ai_model:-}" ]]; then
    ai_model="$gpt_model_name"
    utils::log_info "[DEPRECATION] gpt_model_name will be removed in v2.0 (target 2026-Q3). Migrate to AI_MODEL."
  fi

  # Set default provider if not specified
  if [[ -z "${ai_provider:-}" ]]; then
    ai_provider="openai"
  fi

  # Set default model based on provider if not specified
  if [[ -z "${ai_model:-}" ]]; then
    case "$ai_provider" in
      "openai")
        ai_model="gpt-5-mini"
        ;;
      "claude")
        ai_model="claude-sonnet-4-5"
        ;;
      *)
        ai_model="gpt-5-mini"
        ;;
    esac
  fi

  utils::verify_required_env_vars "git_provider" "git_token" "ai_api_key"

  export AI_PROVIDER="$ai_provider"
  export AI_API_KEY="$ai_api_key"
  export AI_MODEL="$ai_model"
  if [[ -n "${ai_max_tokens:-}" ]]; then
    export AI_MAX_TOKENS="$ai_max_tokens"
  fi
  if [[ -n "${prompt_override:-}" ]]; then
    export AI_PROMPT_OVERRIDE="$prompt_override"
  fi
  if [[ -n "${prompt_file:-}" ]]; then
    export AI_PROMPT_FILE="$prompt_file"
  fi

  # Soft cap on the diff size we send to the model. Anything larger gets
  # truncated so a giant PR doesn't blow the context window or rack up
  # surprise spend. Defaults to 200000 bytes (~50k tokens).
  local diff_byte_cap
  diff_byte_cap="${max_diff_bytes:-200000}"

  local review_number commit_diff ai_response
  case "$git_provider" in
    "github")
      utils::verify_required_env_vars "GITHUB_REPOSITORY" "GITHUB_EVENT_PATH" "github_api_url"
      export GITHUB_TOKEN="$git_token"
      export GITHUB_API_URL="$github_api_url"
      review_number=$(github::get_pr_number)
      commit_diff=$(github::get_commit_diff "$review_number" "$files_to_ignore")
      ;;
    "gitlab")
      utils::verify_required_env_vars "CI_API_V4_URL" "CI_PROJECT_ID" "CI_MERGE_REQUEST_IID"
      export GITLAB_TOKEN="$git_token"
      commit_diff=$(gitlab::get_merge_request_diff "$files_to_ignore")
      ;;
    *)
      utils::log_error "Unsupported git provider: $git_provider. Supported providers: github, gitlab"
      ;;
  esac

  if [[ -z "$commit_diff" ]]; then
    utils::log_info "Nothing in the commit diff."
    exit 0
  fi

  local diff_size
  diff_size=${#commit_diff}
  if (( diff_size > diff_byte_cap )); then
    utils::log_info "Diff is ${diff_size} bytes; truncating to ${diff_byte_cap} bytes for the model."
    commit_diff="[Diff truncated to ${diff_byte_cap} of ${diff_size} bytes for model context limits.]"$'\n\n'"${commit_diff:0:$diff_byte_cap}"
  fi

  ai_response=$(ai::prompt_model "$commit_diff")

  if [[ -z "$ai_response" ]]; then
    utils::log_error "AI response was empty. Double check your API key and billing details."
  fi

  case "$git_provider" in
    "github")
      github::comment "$ai_response" "$review_number"
      ;;
    "gitlab")
      gitlab::comment "$ai_response"
      ;;
  esac
}
