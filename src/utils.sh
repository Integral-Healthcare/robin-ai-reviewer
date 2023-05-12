#!/usr/bin/env bash

echoerr() {
  echo "$@" 1>&2
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
    echoerr "The env variable $1 is required."
    exit 1
  fi
}
