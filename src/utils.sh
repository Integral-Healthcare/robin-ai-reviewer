#!/usr/bin/env bash

utils::log_info() {
  echo -e "[\\e[1;94mINFO\\e[0m] $@"
}

utils::log_error() {
  echo -e "[\\e[1;91mERROR\\e[0m] $@" 1>&2
  exit 1
}

utils::verify_required_env_vars() {
  utils::env_variable_exist "git_provider"
  utils::env_variable_exist "git_token"
  utils::env_variable_exist "open_ai_api_key"
}

utils::set_default_env_vars() {
  utils::env_variable_default "gpt_model_name" "gpt-3.5-turbo"
  utils::env_variable_default "github_api_url" "https://api.github.com"
  utils::env_variable_default "files_to_ignore" ""
}

utils::env_variable_exist() {
  if [ -z "${!1}" ]; then
    utils::log_error "The env variable '$1' is required."
  fi
}

utils::env_variable_default() {
  if [ -z "${!1}" ]; then
    export "${1}"="${2}"
  fi
}
