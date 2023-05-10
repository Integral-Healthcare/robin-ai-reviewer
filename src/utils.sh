#!/usr/bin/env bash

echoerr() {
  echo "$@" 1>&2
}

utils::env_variable_exist() {
  if [[ -z "${!1}" ]]; then
    echoerr "The env variable $1 is required."
    exit 1
  fi
}

utils::get_pr_number() {
  jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH"
}