#!/usr/bin/env bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/error_handler.sh"

# ANSI color codes
if [[ -z "${RED:-}" ]]; then readonly RED='\e[1;91m'; fi
# shellcheck disable=SC2034  # Used in log_warn function
if [[ -z "${YELLOW:-}" ]]; then readonly YELLOW='\e[1;93m'; fi
if [[ -z "${BLUE:-}" ]]; then readonly BLUE='\e[1;94m'; fi
if [[ -z "${RESET:-}" ]]; then readonly RESET='\e[0m'; fi

# Log levels
if [[ -z "${LOG_LEVEL_INFO:-}" ]]; then readonly LOG_LEVEL_INFO=0; fi
if [[ -z "${LOG_LEVEL_WARN:-}" ]]; then readonly LOG_LEVEL_WARN=1; fi
if [[ -z "${LOG_LEVEL_ERROR:-}" ]]; then readonly LOG_LEVEL_ERROR=2; fi

utils::log() {
  local level="$1"
  local message="$2"
  local context="${3:-}"
  local color

  case "$level" in
    "$LOG_LEVEL_INFO")
      color="$BLUE"
      prefix="INFO"
      ;;
    "$LOG_LEVEL_WARN")
      color="$YELLOW"
      prefix="WARN"
      ;;
    "$LOG_LEVEL_ERROR")
      color="$RED"
      prefix="ERROR"
      ;;
  esac

  printf "[${color}%s${RESET}] %s%s\n" \
    "$prefix" \
    "$message" \
    "${context:+ ($context)}" \
    >&2
}

utils::log_info() {
  utils::log "$LOG_LEVEL_INFO" "$1" "${2:-}"
}

utils::log_warn() {
  utils::log "$LOG_LEVEL_WARN" "$1" "${2:-}"
}

utils::log_error() {
  local message="$1"
  local context="${2:-}"
  local error_code="${3:-$E_UNKNOWN}"

  utils::log "$LOG_LEVEL_ERROR" "$message" "$context"
  return "$error_code"
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

  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    error_handler::handle_error "$E_INVALID_INPUT" \
      "Environment validation" \
      "Missing required variables: ${missing_vars[*]}"
    return 1
  fi

  return 0
}

utils::validate_input() {
  local input="$1"
  local name="$2"
  local context="$3"

  if [[ -z "$input" ]]; then
    error_handler::handle_error "$E_INVALID_INPUT" \
      "$context" \
      "Empty or missing $name"
    return 1
  fi

  return 0
}

utils::parse_args() {
  local arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "$arg" in
      --github_token=*)
        export github_token="${arg#*=}"
        utils::validate_input "$github_token" "github_token" "Argument parsing" || return 1
        ;;
      --open_ai_api_key=*)
        export open_ai_api_key="${arg#*=}"
        utils::validate_input "$open_ai_api_key" "open_ai_api_key" "Argument parsing" || return 1
        ;;
      --gpt_model_name=*)
        export gpt_model_name="${arg#*=}"
        utils::validate_input "$gpt_model_name" "gpt_model_name" "Argument parsing" || return 1
        ;;
      --github_api_url=*)
        export github_api_url="${arg#*=}"
        utils::validate_input "$github_api_url" "github_api_url" "Argument parsing" || return 1
        ;;
      --files_to_ignore=*)
        export files_to_ignore="${arg#*=}"
        # files_to_ignore can be empty, so no validation needed
        ;;
      *)
        error_handler::handle_error "$E_INVALID_INPUT" \
          "Argument parsing" \
          "Unknown argument: $arg"
        return 1
        ;;
    esac
    shift
  done

  return 0
}
