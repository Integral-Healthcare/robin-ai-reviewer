#!/usr/bin/env bash

load '../test_helper.bash'

setup() {
    # Set up environment variables
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/error_handler.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/github.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/gpt.sh"
}

@test "error_handler::handle_github_error handles API errors" {
    run_with_stderr_redirect github::get_pr_files "invalid_pr"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Failed to get PR files"
}

@test "error_handler::handle_openai_error handles API errors" {
    export OPEN_AI_API_KEY="invalid_key"
    run_with_stderr_redirect gpt::review_code "test code"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Failed to get code review"
}

@test "error_handler::handle_input_error validates PR number" {
    run_with_stderr_redirect github::validate_pr_number ""
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Invalid PR number"
}

@test "error_handler::handle_input_error validates diff content" {
    run_with_stderr_redirect github::validate_diff ""
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Empty diff content"
}

@test "error_handler::handle_system_error handles missing dependencies" {
    local original_path="$PATH"
    export PATH="/nonexistent"
    run_with_stderr_redirect github::check_dependencies
    export PATH="$original_path"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Required dependency not found"
}

@test "error_handler::handle_system_error handles missing environment variables" {
    local original_token="$GITHUB_TOKEN"
    unset GITHUB_TOKEN
    run_with_stderr_redirect github::check_environment
    export GITHUB_TOKEN="$original_token"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Required environment variable GITHUB_TOKEN not set"
}
