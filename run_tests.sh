#!/usr/bin/env bash

set -euo pipefail

# Run all tests
run_all_tests() {
    local test_dir="$1"

    # Run unit tests
    echo "Running unit tests..."
    bats "${test_dir}/unit/"*.bats
}

# Set up colored output
setup_colors() {
    if [[ -t 1 ]]; then
        RED="$(tput setaf 1)"
        GREEN="$(tput setaf 2)"
        RESET="$(tput sgr0)"
    else
        RED=""
        GREEN=""
        RESET=""
    fi
}

main() {
    setup_colors

    local test_dir="./tests"

    # Ensure test directory exists
    if [[ ! -d "$test_dir" ]]; then
        echo "${RED}Error: Test directory '$test_dir' not found${RESET}"
        exit 1
    fi

    # Run tests
    if run_all_tests "$test_dir"; then
        echo "${GREEN}All tests passed!${RESET}"
        exit 0
    else
        echo "${RED}Some tests failed${RESET}"
        exit 1
    fi
}

main "$@"
