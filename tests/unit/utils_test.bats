#!/usr/bin/env bats

# Load test helpers and set up environment
load '../test_helper.bash'

setup() {
    # Set up environment variables first
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    # Then source the module under test
    # shellcheck disable=SC1091
    source "${HOME_DIR}/src/utils.sh"
}

@test "utils::log_info outputs info message correctly" {
    run utils::log_info "Test message"
    assert_success
    assert_info_message "Test message" "$output"
}

@test "utils::log_error outputs error message and returns error code" {
    run utils::log_error "Test error" "Test context" 2
    assert_failure 2
    assert_error_message "Test error" "$output"
    [[ "$output" =~ "Test context" ]] || fail "Error context not found in output"
}

@test "utils::log_warn outputs warning message correctly" {
    run utils::log_warn "Test warning" "Test context"
    assert_success
    [[ "$output" =~ .*"[WARN]".* ]] || fail "Warning level not found in output"
    [[ "$output" =~ "Test warning" ]] || fail "Warning message not found in output"
    [[ "$output" =~ "Test context" ]] || fail "Warning context not found in output"
}

@test "utils::verify_required_env_vars succeeds with all variables set" {
    export GITHUB_REPOSITORY="test/repo"
    export GITHUB_EVENT_PATH="/tmp/event.json"
    # shellcheck disable=SC2030,SC2031  # Variables used in subshell
    export github_token="test_token"
    # shellcheck disable=SC2030,SC2031  # Variables used in subshell
    export github_api_url="https://api.github.com"
    # shellcheck disable=SC2030,SC2031  # Variables used in subshell
    export open_ai_api_key="test_key"
    # shellcheck disable=SC2030,SC2031  # Variables used in subshell
    export gpt_model_name="gpt-3.5-turbo"

    run utils::verify_required_env_vars
    assert_success
}

@test "utils::verify_required_env_vars fails with missing variables" {
    unset GITHUB_REPOSITORY
    unset GITHUB_EVENT_PATH

    run utils::verify_required_env_vars
    assert_failure
    assert_error_message "Missing required variables" "$output"
}

@test "utils::validate_input succeeds with valid input" {
    run utils::validate_input "test_value" "test_name" "test_context"
    assert_success
}

@test "utils::validate_input fails with empty input" {
    run utils::validate_input "" "test_name" "test_context"
    assert_failure
    assert_error_message "Empty or missing test_name" "$output"
}

@test "utils::parse_args parses valid arguments correctly" {
    run utils::parse_args \
        "--github_token=test_token" \
        "--open_ai_api_key=test_key" \
        "--gpt_model_name=gpt-4" \
        "--github_api_url=https://api.github.com" \
        "--files_to_ignore=*.md"

    assert_success
    # shellcheck disable=SC2031  # Variables used in subshell
    [[ "$github_token" == "test_token" ]] || fail "github_token not set correctly"
    # shellcheck disable=SC2031  # Variables used in subshell
    [[ "$open_ai_api_key" == "test_key" ]] || fail "open_ai_api_key not set correctly"
    # shellcheck disable=SC2031  # Variables used in subshell
    [[ "$gpt_model_name" == "gpt-4" ]] || fail "gpt_model_name not set correctly"
    # shellcheck disable=SC2031  # Variables used in subshell
    [[ "$github_api_url" == "https://api.github.com" ]] || fail "github_api_url not set correctly"
    [[ "$files_to_ignore" == "*.md" ]] || fail "files_to_ignore not set correctly"
}

@test "utils::parse_args fails with invalid argument" {
    run utils::parse_args "--invalid_arg=value"
    assert_failure
    assert_error_message "Unknown argument: --invalid_arg=value" "$output"
}

@test "utils::parse_args fails with empty required arguments" {
    run utils::parse_args \
        "--github_token=" \
        "--open_ai_api_key=test_key"

    assert_failure
    assert_error_message "Empty or missing github_token" "$output"
}

@test "utils::parse_args allows empty files_to_ignore" {
    run utils::parse_args \
        "--github_token=test_token" \
        "--open_ai_api_key=test_key" \
        "--gpt_model_name=gpt-4" \
        "--github_api_url=https://api.github.com" \
        "--files_to_ignore="

    assert_success
}
