#!/usr/bin/env bash

# ANSI color codes
readonly RED='\e[1;91m'
readonly BLUE='\e[1;94m'
readonly RESET='\e[0m'

utils::log_info() {
  printf "[${BLUE}INFO${RESET}] %s\n" "$*"
}

utils::log_error() {
  printf "[${RED}ERROR${RESET}] %s\n" "$*" >&2
  exit 1
}

utils::verify_required_env_vars() {
  local required_vars=(
    "GITHUB_REPOSITORY"
    "GITHUB_EVENT_PATH"
    "github_token"
    "github_api_url"
    "open_ai_api_key"
    "gpt_model_name"
  )

  for var in "${required_vars[@]}"; do
    utils::env_variable_exist "$var"
  done
}

utils::env_variable_exist() {
  local var_name="$1"
  if [[ -z "${!var_name}" ]]; then
    utils::log_error "The env variable '$var_name' is required."
  fi
}

utils::parse_args() {
  # Declare variables as local to avoid shellcheck warnings
  local arg
  # Export variables so they're available in the main function
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --github_token=*)
        export github_token="${arg#*=}"
        shift
        ;;
      --open_ai_api_key=*)
        export open_ai_api_key="${arg#*=}"
        shift
        ;;
      --gpt_model_name=*)
        export gpt_model_name="${arg#*=}"
        shift
        ;;
      --github_api_url=*)
        export github_api_url="${arg#*=}"
        shift
        ;;
      --files_to_ignore=*)
        export files_to_ignore="${arg#*=}"
        shift
        ;;
      *)
        utils::log_error "Unknown argument: $arg"
        ;;
    esac
  done
}
