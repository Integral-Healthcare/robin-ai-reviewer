#!/usr/bin/env bash

# Load test dependencies
load '/usr/local/lib/bats/bats-support/load.bash'
load '/usr/local/lib/bats/bats-assert/load.bash'
load "../mocks/mock_handler.sh"

# Initialize test environment
init_test_env() {
    # Set up test environment variables
    export HOME_DIR="$BATS_TEST_DIRNAME/.."
    export GITHUB_REPOSITORY="test/repo"
    export GITHUB_EVENT_PATH="$BATS_TEST_DIRNAME/fixtures/github_event.json"
    export GITHUB_TOKEN="test_token"
    export OPEN_AI_API_KEY="test_key"
    export GPT_MODEL="gpt-3.5-turbo"
    export GITHUB_API_URL="https://api.github.com"
    export MOCK_RESPONSES=true

    # Create test fixtures directory if it doesn't exist
    mkdir -p "$BATS_TEST_DIRNAME/fixtures"

    # Initialize mock environment
    init_mock_env
}

# Initialize mock environment
init_mock_env() {
    # Reset mock environment variables
    unset MOCK_RESPONSE
    unset MOCK_ERROR_TYPE
    # Export mock environment functions
    export -f set_mock_response
    export -f set_mock_error
}

# Helper functions for setting mock environment
set_mock_response() {
    export MOCK_RESPONSE="$1"
}

set_mock_error() {
    export MOCK_ERROR_TYPE="$1"
}

# Call initialization
init_test_env

# Clean up after tests
teardown() {
    # Remove any temporary files created during tests
    rm -f "$BATS_TEST_DIRNAME/fixtures/temp_*"
    # Reset mock error type
    unset MOCK_ERROR_TYPE
}

# Helper function to create a mock GitHub event file
create_test_event() {
    local pr_number="$1"
    cat > "$GITHUB_EVENT_PATH" <<EOF
{
    "pull_request": {
        "number": $pr_number
    }
}
EOF
}

# Helper function to create mock data with error type
create_mock_data() {
    local data="$1"
    if [[ -n "${MOCK_ERROR_TYPE:-}" ]]; then
        echo "${data:-{}}" | jq --arg type "$MOCK_ERROR_TYPE" '. + {error_type: $type}'
    else
        echo "${data:-{}}"
    fi
}

# Helper function to assert error messages
assert_error_message() {
    local expected="$1"
    local output="$2"
    [[ "$output" =~ .*"[ERROR]".* ]] || return 1
    [[ "$output" =~ .*"$expected".* ]] || return 1
}

# Helper function to assert info messages
assert_info_message() {
    local expected="$1"
    local output="$2"
    [[ "$output" =~ .*"[INFO]".* ]] || return 1
    [[ "$output" =~ .*"$expected".* ]] || return 1
}

# Helper function to create a test diff
create_test_diff() {
    cat <<EOF
diff --git a/test.py b/test.py
index 1234567..89abcdef 100644
--- a/test.py
+++ b/test.py
@@ -1,3 +1,3 @@
-def hello():
-    print("Hello")
+def hello_world():
+    print("Hello, World!")
EOF
}

# Helper function to run command with stderr redirected
run_with_stderr_redirect() {
    local command="$1"
    shift
    local args=("$@")

    # Create temporary files for stderr
    local stderr_capture
    stderr_capture="$(mktemp)"
    local stderr_output
    stderr_output="$(mktemp)"

    # Run the command with stderr redirected
    STDERR_FILE="$stderr_output" run bash -c "source \"${BATS_TEST_DIRNAME}/../../src/${command%::*}.sh\" && ${command} \"\${@}\"" _ "${args[@]}" 2>"$stderr_capture"

    # Copy captured stderr to output file
    cat "$stderr_capture" > "$stderr_output"

    # Clean up
    rm -f "$stderr_capture" "$stderr_output"
}

# Helper function to assert no stderr output
assert_no_stderr() {
    local stderr_file="${STDERR_FILE:-}"
    [[ ! -s "$stderr_file" ]] || return 1
}
