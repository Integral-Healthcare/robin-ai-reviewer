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
  for var in "$@"; do
    utils::env_variable_exist "$var"
  done
}

utils::env_variable_exist() {
  local var_name="$1"
  if [[ -z "${!var_name:-}" ]]; then
    utils::log_error "The env variable '$var_name' is required."
  fi
}

utils::should_ignore_file() {
  local filename="$1"
  local files_to_ignore="$2"

  local pattern
  for pattern in $files_to_ignore; do
    pattern="${pattern%\"}"
    pattern="${pattern#\"}"

    # shellcheck disable=SC2053
    [[ "$filename" == $pattern ]] && return 0
  done

  return 1
}
