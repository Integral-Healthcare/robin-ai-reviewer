#!/usr/bin/env bash
#
# Error Handler Module
# Provides error handling and retry functionality

# Error codes
# Export these for use in other modules
export E_INVALID_INPUT=1
export E_API_ERROR=2
export E_RATE_LIMIT=3

error_handler::handle_error() {
    local error_code="$1"
    local context="$2"
    local message="$3"
    printf "[ERROR] %s: %s\n" "$context" "$message" >&2
    return "$error_code"
}

error_handler::retry() {
    local -a cmd=("$@")
    local max_attempts="${cmd[-2]}"
    local delay="${cmd[-1]}"
    unset "cmd[-1]" "cmd[-1]"  # Remove max_attempts and delay from cmd array

    local attempt=1
    while ((attempt <= max_attempts)); do
        if "${cmd[@]}"; then
            return 0
        fi
        ((attempt < max_attempts)) && sleep "$delay"
        ((attempt++))
    done
    return 1
}

error_handler::check_rate_limit() {
    local response="$1"
    local api_name="$2"
    local remaining
    remaining=$(echo "$response" | jq -r '.rate.remaining // empty')
    if [[ -n "$remaining" ]] && ((remaining < 10)); then
        error_handler::handle_error "$E_RATE_LIMIT" \
            "$api_name rate limit" \
            "Rate limit nearly exceeded ($remaining remaining)"
        return 1
    fi
    return 0
}
