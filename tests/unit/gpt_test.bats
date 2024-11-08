#!/usr/bin/env bats

# Load test helpers and set up environment
load '../test_helper.bash'

setup() {
    # Set up environment variables first
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    export GPT_MODEL="gpt-3.5-turbo"
    export OPEN_AI_API_KEY="test_key"

    # Source the modules under test
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/error_handler.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/gpt.sh"

    # Reset mock environment variables
    unset MOCK_RESPONSE
    unset MOCK_ERROR_TYPE
}

@test "gpt::prompt_model handles successful API response" {
    # Mock successful API response
    local mock_response='{
        "choices": [
            {
                "message": {
                    "content": "<details>\n<summary>Score: 85</summary>\n\nImprovements:\n- Test improvement\n</details>"
                }
            }
        ]
    }'
    mock_curl_response "$mock_response"

    run gpt::prompt_model "$(create_test_diff)"
    assert_success
    [[ "$output" =~ "Score: 85" ]] || fail "Score not found in output"
    [[ "$output" =~ "Test improvement" ]] || fail "Improvements not found in output"
}

@test "gpt::prompt_model handles API error" {
    set_mock_error "invalid_key"
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "Invalid API key" "$output"
}

@test "gpt::prompt_model handles empty diff" {
    run gpt::prompt_model ""
    assert_success
    assert_output "nothing to grade"
}

@test "gpt::prompt_model handles missing API key" {
    unset OPEN_AI_API_KEY
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "OpenAI API key not provided" "$output"
}

@test "gpt::prompt_model handles missing model name" {
    unset GPT_MODEL
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "GPT model name not specified" "$output"
}

@test "gpt::prompt_model handles malformed API response" {
    set_mock_error "malformed"
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "Invalid response structure" "$output"
}

@test "gpt::prompt_model handles rate limit error" {
    set_mock_error "rate_limit"
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "Rate limit exceeded" "$output"
}

@test "gpt::prompt_model handles network error" {
    set_mock_error "network_error"
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "API request failed" "$output"
}

@test "gpt::prompt_model validates response format" {
    # Mock response with invalid format
    local mock_response='{
        "choices": [
            {
                "message": {
                    "content": "Invalid format response"
                }
            }
        ]
    }'
    mock_curl_response "$mock_response"

    run gpt::prompt_model "$(create_test_diff)"
    assert_success
    [[ "$output" =~ "Invalid format response" ]] || fail "Response content not found"
}

@test "gpt::prompt_model handles large input" {
    # Create a large diff
    local large_diff=""
    # shellcheck disable=SC2034
    for i in {1..100}; do
        large_diff+="$(create_test_diff)\n"
    done

    # Mock successful response
    local mock_response='{
        "choices": [
            {
                "message": {
                    "content": "<details>\n<summary>Score: 90</summary>\n\nImprovements:\n- Large input handled correctly\n</details>"
                }
            }
        ]
    }'
    mock_curl_response "$mock_response"

    run gpt::prompt_model "$large_diff"
    assert_success
    [[ "$output" =~ "Score: 90" ]] || fail "Score not found in output"
    [[ "$output" =~ "Large input handled correctly" ]] || fail "Improvements not found in output"
}

@test "gpt::prompt_model retries on temporary failure" {
    # First attempt fails with rate limit
    set_mock_error "rate_limit"
    run gpt::prompt_model "$(create_test_diff)"
    assert_failure
    assert_error_message "Rate limit exceeded" "$output"

    # Second attempt succeeds
    unset MOCK_ERROR_TYPE
    run gpt::prompt_model "$(create_test_diff)"
    assert_success
    [[ "$output" =~ "Score: 85" ]] || fail "Score not found in output"
}
