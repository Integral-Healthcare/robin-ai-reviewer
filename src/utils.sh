#!/usr/bin/env bash

utils::log_info() {
  echo -e "[\\e[1;94mINFO\\e[0m] $@"
}

utils::log_error() {
  echo -e "[\\e[1;91mERROR\\e[0m] $@" 1>&2
  exit 1
}

utils::verify_required_env_vars() {
  utils::env_variable_exist "GITHUB_REPOSITORY"
  utils::env_variable_exist "GITHUB_EVENT_PATH"
  utils::env_variable_exist "github_token"
  utils::env_variable_exist "github_api_url"
  utils::env_variable_exist "open_ai_api_key"
  utils::env_variable_exist "gpt_model_name"
}

utils::env_variable_exist() {
  if [[ -z "${!1}" ]]; then
    utils::log_error "The env variable '$1' is required."
  fi
}
