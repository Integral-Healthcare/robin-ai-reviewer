#!/usr/bin/env bash

set -euo pipefail

trap 'exit 1' TERM
export TOP_PID=$$

source "$HOME_DIR/src/utils.sh"
source "$HOME_DIR/src/github.sh"
source "$HOME_DIR/src/gpt.sh"
source "$HOME_DIR/src/chunking.sh"

##? Auto-reviews a Pull Request
##?
##? Usage:
##?   main.sh --github_token=<token> --open_ai_api_key=<token> --gpt_model_name=<name> --github_api_url=<url> --files_to_ignore=<files>
main() {
  local github_token="" open_ai_api_key="" gpt_model_name="gpt-3.5-turbo" github_api_url="https://api.github.com" files_to_ignore=""
  utils::parse_args "$@"

  utils::verify_required_env_vars

  export GITHUB_TOKEN="$github_token"
  export GITHUB_API_URL="$github_api_url"
  export OPEN_AI_API_KEY="$open_ai_api_key"
  export GPT_MODEL="$gpt_model_name"

  local pr_number commit_diff
  pr_number=$(github::get_pr_number)
  commit_diff=$(github::get_commit_diff "$pr_number" "${files_to_ignore[*]}")

  if [[ -z "$commit_diff" ]]; then
    utils::log_info "Nothing in the commit diff."
    exit 0
  fi

  # Split diff into chunks if necessary
  local chunks
  IFS=$'\n' read -r -d '' -a chunks < <(chunking::split_diff "$commit_diff" && printf '\0')

  # Process each chunk and collect reviews
  local reviews=()
  local chunk
  for chunk in "${chunks[@]}"; do
    [[ "$chunk" == "$CHUNK_SEPARATOR" ]] && break

    utils::log_info "Processing diff chunk..."

    local chunk_response
    if ! chunk_response=$(gpt::prompt_model "$chunk"); then
      utils::log_error "Failed to process diff chunk" "GPT API"
      exit 1
    fi

    if [[ -n "$chunk_response" && "$chunk_response" != "nothing to grade" ]]; then
      reviews+=("$chunk_response")
    fi
  done

  # Handle case where no valid reviews were generated
  if [[ ${#reviews[@]} -eq 0 ]]; then
    utils::log_error "No valid reviews generated. Check API key and billing details."
    exit 1
  fi

  # Merge reviews if multiple chunks were processed
  local final_review
  if [[ ${#reviews[@]} -gt 1 ]]; then
    utils::log_info "Merging ${#reviews[@]} reviews..."
    final_review=$(chunking::merge_reviews "${reviews[@]}")
  else
    final_review="${reviews[0]}"
  fi

  # Post the final review as a comment
  if ! github::comment "$final_review" "$pr_number"; then
    utils::log_error "Failed to post review comment" "GitHub API"
    exit 1
  fi

  utils::log_info "Review completed successfully"
}

# Only run main if the script is being executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
