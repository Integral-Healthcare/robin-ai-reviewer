#!/usr/bin/env bash

# Prints error messages to stderr
echoerr() {
  echo "[ERROR] $@" 1>&2
}

# Checks if all required environment variables exist
verify_required_env_vars() {
  env_variable_exist "GITHUB_REPOSITORY"
  env_variable_exist "GITHUB_EVENT_PATH"
  env_variable_exist "github_token"
  env_variable_exist "github_api_url"
  env_variable_exist "open_ai_api_key"
  env_variable_exist "gpt_model_name"
}

# Checks if a single environment variable exists
env_variable_exist() {
  if [[ -z "${!1}" ]]; then
    echoerr "The environment variable $1 is not set or is empty. This variable is required for this script to run."
    exit 1
  fi
}
