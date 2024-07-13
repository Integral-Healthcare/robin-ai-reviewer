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
