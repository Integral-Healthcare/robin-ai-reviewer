#!/usr/bin/env bash

# Load mock responses
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1091
source "$DIR/github_responses.sh"
# shellcheck disable=SC1091
source "$DIR/openai_responses.sh"

# Mock API request handler
mock_api_request() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local response
    local error_type

    # Use MOCK_RESPONSE if available
    if [[ -n "${MOCK_RESPONSE:-}" ]]; then
        response="$MOCK_RESPONSE"
        unset MOCK_RESPONSE  # Clear after use to prevent affecting subsequent calls
        echo "$response"
        return 0
    fi

    # Extract error type from data if present
    if [[ "$data" =~ error_type=([^\"]+) ]]; then
        error_type="${BASH_REMATCH[1]}"
    elif [[ -n "${MOCK_ERROR_TYPE:-}" ]]; then
        error_type="$MOCK_ERROR_TYPE"
    fi

    # GitHub API mocks
    if [[ "$endpoint" =~ github.com ]]; then
        if [[ "$endpoint" =~ /pulls/([0-9]+)/files ]]; then
            response=$(mock_pr_files "${BASH_REMATCH[1]}" "$error_type")
        elif [[ "$endpoint" =~ /pulls/([0-9]+)/comments ]]; then
            response=$(mock_pr_comments "${BASH_REMATCH[1]}" "$error_type")
        elif [[ "$endpoint" =~ /pulls/([0-9]+)$ ]]; then
            response=$(mock_pr_details "${BASH_REMATCH[1]}" "$error_type")
        elif [[ "$endpoint" =~ /diff$ ]]; then
            response=$(mock_pr_diff "$error_type")
        else
            echo "Unmocked GitHub endpoint: $endpoint" >&2
            return 1
        fi
    # OpenAI API mocks
    elif [[ "$endpoint" =~ openai.com ]]; then
        if [[ "$endpoint" =~ /chat/completions ]]; then
            if [[ "$data" =~ "code review" ]]; then
                response=$(mock_code_review "$data" "$error_type")
            else
                response=$(mock_review_summary "$data" "$error_type")
            fi
        else
            echo "Unmocked OpenAI endpoint: $endpoint" >&2
            return 1
        fi
    # Test endpoint mocks
    elif [[ "$endpoint" =~ test_endpoint ]]; then
        response="$data"  # For test_endpoint, just echo back the data
    else
        echo "Unmocked endpoint: $endpoint" >&2
        return 1
    fi

    echo "$response"
    return 0
}

# Mock curl wrapper
mock_curl() {
    local url=""
    local method="GET"
    local data=""

    # Parse curl arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -X|--request)
                method="$2"
                shift 2
                ;;
            -d|--data)
                data="$2"
                shift 2
                ;;
            -*)
                shift
                ;;
            *)
                url="$1"
                shift
                ;;
        esac
    done

    mock_api_request "$url" "$method" "$data"
}

# Export mock functions
export -f mock_api_request
export -f mock_curl
