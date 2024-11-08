#!/usr/bin/env bash

set -euo pipefail

# Install BATS and dependencies
install_bats() {
    local bats_core_version="1.9.0"
    local bats_support_version="0.3.0"
    local bats_assert_version="2.1.0"

    # Install BATS core
    git clone --depth 1 --branch "v${bats_core_version}" https://github.com/bats-core/bats-core.git
    cd bats-core
    sudo ./install.sh /usr/local
    cd ..
    rm -rf bats-core

    # Create BATS plugins directory
    sudo mkdir -p /usr/local/lib/bats

    # Install bats-support
    git clone --depth 1 --branch "v${bats_support_version}" https://github.com/bats-core/bats-support.git
    sudo mv bats-support /usr/local/lib/bats/

    # Install bats-assert
    git clone --depth 1 --branch "v${bats_assert_version}" https://github.com/bats-core/bats-assert.git
    sudo mv bats-assert /usr/local/lib/bats/
}

# Create test runner script
create_test_runner() {
    cat > run_tests.sh <<EOF
#!/usr/bin/env bash

set -euo pipefail

# Run all tests
run_all_tests() {
    local test_dir="\$1"

    # Run unit tests
    echo "Running unit tests..."
    bats "\${test_dir}/unit/"*.bats
}

# Set up colored output
setup_colors() {
    if [[ -t 1 ]]; then
        RED="\$(tput setaf 1)"
        GREEN="\$(tput setaf 2)"
        YELLOW="\$(tput setaf 3)"
        RESET="\$(tput sgr0)"
    else
        RED=""
        GREEN=""
        YELLOW=""
        RESET=""
    fi
}

main() {
    setup_colors

    local test_dir="./tests"

    # Ensure test directory exists
    if [[ ! -d "\$test_dir" ]]; then
        echo "\${RED}Error: Test directory '\$test_dir' not found\${RESET}"
        exit 1
    fi

    # Run tests
    if run_all_tests "\$test_dir"; then
        echo "\${GREEN}All tests passed!\${RESET}"
        exit 0
    else
        echo "\${RED}Some tests failed\${RESET}"
        exit 1
    fi
}

main "\$@"
EOF

    chmod +x run_tests.sh
}

main() {
    echo "Installing BATS and dependencies..."
    install_bats

    echo "Creating test runner script..."
    create_test_runner

    echo "Test setup complete!"
    echo "Run './run_tests.sh' to execute the test suite"
}

main "$@"
