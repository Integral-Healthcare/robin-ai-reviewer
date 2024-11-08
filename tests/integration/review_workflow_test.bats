#!/usr/bin/env bash

load '../test_helper.bash'

setup() {
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    export CHUNK_SEPARATOR="=== END OF CHUNK ==="
    export MAX_CHUNK_SIZE=3000
    export MAX_FILES_PER_CHUNK=5
    export MOCK_RESPONSES=true

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/error_handler.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/github.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/gpt.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/chunking.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/main.sh"
}

@test "integration::full_review_workflow handles single file PR" {
    # Set up test PR
    create_test_event "123"

    # Run full review workflow
    run_with_stderr_redirect main::review_pull_request "123"
    assert_success
    assert_no_stderr

    # Verify expected outputs
    assert_output --partial "Score: 85"
    assert_output --partial "Improvements"
}

@test "integration::full_review_workflow handles multi-file PR" {
    # Create a PR with multiple files
    create_test_event "456"

    # Run full review workflow
    run_with_stderr_redirect main::review_pull_request "456"
    assert_success
    assert_no_stderr

    # Verify chunking and merging worked
    assert_output --partial "Overall Score"
    assert_output --partial "Key Improvements"
}

@test "integration::full_review_workflow handles PR with no changes" {
    create_test_event "789"

    # Mock an empty diff response
    export MOCK_EMPTY_DIFF=true

    # Run full review workflow
    run_with_stderr_redirect main::review_pull_request "789"
    assert_success
    assert_no_stderr

    assert_output --partial "No changes to review"
}

@test "integration::full_review_workflow propagates errors correctly" {
    create_test_event "invalid"

    # Run with invalid PR number
    run_with_stderr_redirect main::review_pull_request "invalid"
    assert_failure
    assert_no_stderr

    assert_output --partial "[ERROR]"
}

@test "integration::full_review_workflow respects chunk limits" {
    create_test_event "999"
    export MAX_FILES_PER_CHUNK=2

    # Run workflow with small chunk size
    run_with_stderr_redirect main::review_pull_request "999"
    assert_success
    assert_no_stderr

    # Verify multiple chunks were processed
    assert_output --partial "Overall Score"
    assert_output --partial "Combined review for multiple chunks"
}
