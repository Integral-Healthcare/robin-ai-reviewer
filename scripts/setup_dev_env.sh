#!/usr/bin/env bash
#
# Development Environment Setup Script
# Sets up the development environment for Robin AI Reviewer
#
# This script:
# 1. Installs required system dependencies
# 2. Configures development environment
# 3. Sets up testing infrastructure
# 4. Validates installation

# Exit on error
set -e

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load utility functions
source "${PROJECT_ROOT}/src/utils.sh"

# Configuration
REQUIRED_PACKAGES=(
    curl
    jq
    bats
    shellcheck
    git
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_success() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

log_error() {
    printf "${RED}✗ %s${NC}\n" "$1" >&2
}

log_info() {
    printf "${YELLOW}➜ %s${NC}\n" "$1"
}

check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Command '$1' not found"
        return 1
    fi
    log_success "Found $1"
    return 0
}

install_dependencies() {
    log_info "Installing system dependencies..."

    # Update package lists
    sudo apt-get update

    # Install required packages
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if ! check_command "$package"; then
            log_info "Installing $package..."
            sudo apt-get install -y "$package"
            log_success "Installed $package"
        fi
    done
}

setup_environment() {
    log_info "Setting up development environment..."

    # Create .env.development if it doesn't exist
    if [[ ! -f "${PROJECT_ROOT}/.env.development" ]]; then
        cat > "${PROJECT_ROOT}/.env.development" <<EOF
# Development Environment Configuration
GITHUB_TOKEN=your_github_token
OPEN_AI_API_KEY=your_openai_key
GPT_MODEL=gpt-3.5-turbo
GITHUB_API_URL=https://api.github.com
MAX_CHUNK_SIZE=3000
MAX_FILES_PER_CHUNK=5
CHUNK_SEPARATOR="\=\=\= END OF CHUNK \=\=\="
EOF
        log_success "Created .env.development template"
    fi

    # Set up git hooks
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        # Pre-commit hook for shellcheck
        cat > "${PROJECT_ROOT}/.git/hooks/pre-commit" <<'EOF'
#!/bin/bash
set -e

# Run shellcheck on all shell scripts
for file in $(git diff --cached --name-only | grep -E '\.(sh|bash)$'); do
    shellcheck "$file"
done
EOF
        chmod +x "${PROJECT_ROOT}/.git/hooks/pre-commit"
        log_success "Set up git pre-commit hook"
    fi
}

validate_installation() {
    log_info "Validating installation..."
    local errors=0

    # Check all required commands
    for cmd in "${REQUIRED_PACKAGES[@]}"; do
        if ! check_command "$cmd"; then
            ((errors++))
        fi
    done

    # Check environment file
    if [[ ! -f "${PROJECT_ROOT}/.env.development" ]]; then
        log_error "Missing .env.development file"
        ((errors++))
    fi

    # Run a test BATS file
    if ! bats "${PROJECT_ROOT}/tests/unit/chunking_test.bats"; then
        log_error "BATS test failed"
        ((errors++))
    fi

    # Final validation
    if ((errors > 0)); then
        log_error "Installation validation failed with $errors errors"
        return 1
    fi

    log_success "Installation validated successfully"
    return 0
}

main() {
    log_info "Starting development environment setup..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi

    # Install dependencies
    install_dependencies

    # Setup environment
    setup_environment

    # Validate installation
    validate_installation

    log_info "Setup complete! Please edit .env.development with your API keys"
    log_info "Run 'source .env.development' to load environment variables"
}

# Run main function
main "$@"
