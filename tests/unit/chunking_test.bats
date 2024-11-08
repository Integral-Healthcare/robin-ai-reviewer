#!/usr/bin/env bats

# Load test helpers and set up environment
load '../test_helper.bash'

setup() {
    # Set up environment variables
    export HOME_DIR="$BATS_TEST_DIRNAME/../.."
    export CHUNK_SEPARATOR="=== END OF CHUNK ==="
    export MAX_CHUNK_SIZE=3000
    export MAX_FILES_PER_CHUNK=5

    # Source the modules under test
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/error_handler.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/utils.sh"
    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/../../src/chunking.sh"
}

@test "chunking::split_diff handles empty diff" {
    run_with_stderr_redirect chunking::split_diff ""
    assert_success
    assert_no_stderr
    [[ "$output" == "$CHUNK_SEPARATOR" ]] || fail "Expected chunk separator for empty diff"
}

@test "chunking::split_diff handles single small file" {
    local diff
    diff=$(create_test_diff)
    run_with_stderr_redirect chunking::split_diff "$diff"
    assert_success
    assert_no_stderr
    [[ "$output" =~ test\.py ]] || fail "Expected file content in output"
    [[ "${#lines[@]}" -eq 2 ]] || fail "Expected one chunk plus separator"
}

@test "chunking::split_diff splits large diffs correctly" {
    # Create a large diff with multiple files
    local large_diff=""
    for i in {1..10}; do
        large_diff+="diff --git a/file$i.py b/file$i.py\n"
        large_diff+="index 1234567..89abcdef 100644\n"
        large_diff+="--- a/file$i.py\n"
        large_diff+="+++ b/file$i.py\n"
        large_diff+="@@ -1,3 +1,3 @@\n"
        for j in {1..100}; do
            large_diff+="-old line $j\n"
            large_diff+="+new line $j\n"
        done
        large_diff+="\n"
    done

    run_with_stderr_redirect chunking::split_diff "$large_diff"
    assert_success
    assert_no_stderr
    [[ "${#lines[@]}" -gt 3 ]] || fail "Expected multiple chunks"
    [[ "${output}" =~ file1\.py ]] || fail "Expected first file in output"
    [[ "${output}" =~ ${CHUNK_SEPARATOR} ]] || fail "Expected chunk separator"
}

@test "chunking::merge_reviews handles empty reviews array" {
    run_with_stderr_redirect chunking::merge_reviews
    assert_success
    assert_no_stderr
    [[ -z "$output" ]] || fail "Expected empty output for no reviews"
}

@test "chunking::merge_reviews handles single review" {
    local review="<details>\n<summary>Score: 85</summary>\n\nImprovements:\n- Test improvement\n</details>"
    run_with_stderr_redirect chunking::merge_reviews "$review"
    assert_success
    assert_no_stderr
    [[ "$output" =~ "Score: 85" ]] || fail "Expected original score"
    [[ "$output" =~ "Test improvement" ]] || fail "Expected improvement in output"
}

@test "chunking::merge_reviews combines multiple reviews correctly" {
    local review1="<details>\n<summary>Score: 80</summary>\n\nImprovements:\n- First improvement\n</details>"
    local review2="<details>\n<summary>Score: 90</summary>\n\nImprovements:\n- Second improvement\n</details>"

    run_with_stderr_redirect chunking::merge_reviews "$review1" "$review2"
    assert_success
    assert_no_stderr
    [[ "$output" =~ "Score: 85" ]] || fail "Expected average score"
    [[ "$output" =~ "First improvement" ]] || fail "Expected first improvement"
    [[ "$output" =~ "Second improvement" ]] || fail "Expected second improvement"
}

@test "chunking::merge_reviews handles 'nothing to grade' reviews" {
    local review1="nothing to grade"
    local review2="<details>\n<summary>Score: 90</summary>\n\nImprovements:\n- Valid improvement\n</details>"

    run_with_stderr_redirect chunking::merge_reviews "$review1" "$review2"
    assert_success
    assert_no_stderr
    [[ "$output" =~ "Score: 90" ]] || fail "Expected score from valid review"
    [[ "$output" =~ "Valid improvement" ]] || fail "Expected improvement from valid review"
}

@test "chunking::merge_reviews removes duplicate improvements" {
    local review1="<details>\n<summary>Score: 85</summary>\n\nImprovements:\n- Same improvement\n</details>"
    local review2="<details>\n<summary>Score: 95</summary>\n\nImprovements:\n- Same improvement\n</details>"

    run_with_stderr_redirect chunking::merge_reviews "$review1" "$review2"
    assert_success
    assert_no_stderr
    local improvement_count
    improvement_count=$(echo "$output" | grep -c "Same improvement")
    [[ "$improvement_count" -eq 1 ]] || fail "Expected only one instance of duplicate improvement"
}

@test "chunking::merge_reviews preserves code blocks for low scores" {
    local review="<details>\n<summary>Score: 60</summary>\n\nImprovements:\n- Test improvement\n\n\`\`\`python\ndef test():\n    pass\n\`\`\`\n</details>"
    run_with_stderr_redirect chunking::merge_reviews "$review"
    assert_success
    assert_no_stderr
    [[ "$output" =~ python ]] || fail "Expected code block language"
    [[ "$output" =~ def\ test\(\): ]] || fail "Expected code block content"
}

@test "chunking::merge_reviews omits code blocks for high scores" {
    local review="<details>\n<summary>Score: 95</summary>\n\nImprovements:\n- Test improvement\n\n\`\`\`python\ndef test():\n    pass\n\`\`\`\n</details>"
    run_with_stderr_redirect chunking::merge_reviews "$review"
    assert_success
    assert_no_stderr
    [[ ! "$output" =~ "python" ]] || fail "Unexpected code block in high score review"
}

@test "chunking::split_diff respects MAX_FILES_PER_CHUNK" {
    # Create a diff with many small files
    local multi_file_diff=""
    for i in {1..10}; do
        multi_file_diff+="diff --git a/small$i.py b/small$i.py\n"
        multi_file_diff+="index 1234567..89abcdef 100644\n"
        multi_file_diff+="--- a/small$i.py\n"
        multi_file_diff+="+++ b/small$i.py\n"
        multi_file_diff+="@@ -1 +1 @@\n"
        multi_file_diff+="-old\n+new\n"
    done

    run_with_stderr_redirect chunking::split_diff "$multi_file_diff"
    assert_success
    assert_no_stderr

    # Count number of chunks (excluding separator)
    local chunk_count=0
    for line in "${lines[@]}"; do
        [[ "$line" != "$CHUNK_SEPARATOR" ]] && ((chunk_count++))
    done

    [[ "$chunk_count" -gt 1 ]] || fail "Expected multiple chunks due to MAX_FILES_PER_CHUNK"
}

@test "chunking::split_diff handles malformed diff" {
    local malformed_diff="This is not a valid diff format"
    run_with_stderr_redirect chunking::split_diff "$malformed_diff"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Invalid diff format"
}

@test "chunking::merge_reviews handles malformed review format" {
    local malformed_review="<details>Invalid review format</details>"
    run_with_stderr_redirect chunking::merge_reviews "$malformed_review"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Invalid review format"
}

@test "chunking::split_diff handles oversized chunks" {
    # Set a very small chunk size limit
    local original_size="$MAX_CHUNK_SIZE"
    export MAX_CHUNK_SIZE=10

    local large_diff
    large_diff=$(create_test_diff)
    run_with_stderr_redirect chunking::split_diff "$large_diff"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Chunk size exceeds limit"

    export MAX_CHUNK_SIZE="$original_size"
}

@test "chunking::merge_reviews handles missing environment variables" {
    local original_separator="$CHUNK_SEPARATOR"
    unset CHUNK_SEPARATOR

    local review="<details>\n<summary>Score: 85</summary>\n\nImprovements:\n- Test improvement\n</details>"
    run_with_stderr_redirect chunking::merge_reviews "$review"
    assert_failure
    assert_no_stderr
    assert_output --partial "[ERROR] Required environment variable CHUNK_SEPARATOR not set"

    export CHUNK_SEPARATOR="$original_separator"
}
