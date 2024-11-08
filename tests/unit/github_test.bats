#!/usr/bin/env bats

# Load test helpers and set up environment
load '../test_helper.bash'

setup() {
    # Set up environment variables
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    export GITHUB_TOKEN="test_token"

    # Source the modules under test
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/error_handler.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/github.sh"

    # Create test PR event
    create_test_event "123"

    # Reset mock environment variables
    unset MOCK_RESPONSE
    unset MOCK_ERROR_TYPE
}

@test "github::get_pr_number returns correct PR number" {
    run github::get_pr_number
    assert_success
    assert_output "123"
}

@test "github::get_pr_number fails with invalid event file" {
    export GITHUB_EVENT_PATH="/nonexistent/path"
    run github::get_pr_number
    assert_failure
    assert_error_message "Event file not found" "$output"
}

@test "github::get_commit_diff fetches diff successfully" {
    # Create mock diff data
    local mock_diff
    mock_diff=$(create_test_diff)
    local mock_data
    mock_data=$(create_mock_data "$mock_diff")
    set_mock_response "$mock_data"

    run github::get_commit_diff "123" ""
    assert_success
    assert_output "$mock_diff"
}

@test "github::get_commit_diff handles API error" {
    set_mock_error "error"
    run github::get_commit_diff "123" ""
    assert_failure
    assert_error_message "Bad credentials" "$output"
}

@test "github::get_commit_diff with files_to_ignore filters correctly" {
    # Create mock response with multiple files
    local mock_response='[
        {
            "filename": "test.py",
            "status": "modified",
            "patch": "test patch 1"
        },
        {
            "filename": "README.md",
            "status": "modified",
            "patch": "test patch 2"
        }
    ]'
    local mock_data
    mock_data=$(create_mock_data "$mock_response")
    set_mock_response "$mock_data"

    run github::get_commit_diff "123" "*.md"
    assert_success
    [[ "$output" =~ "test patch 1" ]] || fail "Expected patch not found"
    [[ ! "$output" =~ "test patch 2" ]] || fail "Ignored file patch found"
}

@test "github::should_ignore_file matches patterns correctly" {
    run github::should_ignore_file "test.md" "*.md"
    assert_success

    run github::should_ignore_file "src/test.py" "*.md"
    assert_failure

    run github::should_ignore_file "test.txt" "*.md *.txt"
    assert_success
}

@test "github::should_ignore_file handles empty patterns" {
    run github::should_ignore_file "test.md" ""
    assert_failure
}

@test "github::comment posts comment successfully" {
    # Create mock successful response
    local mock_response='{"id": 1, "body": "Test comment"}'
    local mock_data
    mock_data=$(create_mock_data "$mock_response")
    set_mock_response "$mock_data"

    run github::comment "Test comment" "123"
    assert_success
}

@test "github::comment handles API error" {
    set_mock_error "error"
    run github::comment "Test comment" "123"
    assert_failure
    assert_error_message "Validation Failed" "$output"
}

@test "github::comment handles empty PR number" {
    run github::comment "Test comment" ""
    assert_failure
    assert_error_message "Empty or missing PR number" "$output"
}

@test "github::get_commit_diff handles removed files" {
    # Create mock response with removed file
    local mock_response='[
        {
            "filename": "removed.py",
            "status": "removed",
            "patch": "should not appear"
        },
        {
            "filename": "modified.py",
            "status": "modified",
            "patch": "should appear"
        }
    ]'
    local mock_data
    mock_data=$(create_mock_data "$mock_response")
    set_mock_response "$mock_data"

    run github::get_commit_diff "123" ""
    assert_success
    [[ ! "$output" =~ "should not appear" ]] || fail "Removed file patch found"
    [[ "$output" =~ "should appear" ]] || fail "Modified file patch not found"
}

@test "github::get_commit_diff handles large responses" {
    # Create a large mock response
    local mock_response='['
    for i in {1..100}; do
        mock_response+="{"
        mock_response+="\"filename\": \"file$i.py\","
        mock_response+="\"status\": \"modified\","
        mock_response+="\"patch\": \"patch $i\""
        mock_response+="}"
        [[ $i -lt 100 ]] && mock_response+=","
    done
    mock_response+=']'
    local mock_data
    mock_data=$(create_mock_data "$mock_response")
    set_mock_response "$mock_data"

    run github::get_commit_diff "123" ""
    assert_success
    [[ "$output" =~ "patch 1" ]] || fail "First patch not found"
    [[ "$output" =~ "patch 100" ]] || fail "Last patch not found"
}
