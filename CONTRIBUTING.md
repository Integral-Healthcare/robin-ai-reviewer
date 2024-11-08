# Contributing to Robin AI Reviewer

Thank you for your interest in contributing to Robin AI Reviewer! This document provides guidelines and information for contributors.

## Development Environment Setup

### Prerequisites

- Bash 4.0+
- curl
- jq
- BATS (Bash Automated Testing System)
- OpenAI API key (for testing)
- GitHub token (for testing)

### Setting Up Your Development Environment

1. Clone the repository:
```bash
git clone https://github.com/Integral-Healthcare/robin-ai-reviewer.git
cd robin-ai-reviewer
```

2. Set up environment variables:
```bash
export GITHUB_TOKEN="your_github_token"
export OPEN_AI_API_KEY="your_openai_key"
export GPT_MODEL="gpt-3.5-turbo"  # or your preferred model
```

## Testing Infrastructure

The project uses BATS (Bash Automated Testing System) for testing. The test infrastructure is organized as follows:

### Test Directory Structure
```
tests/
├── test_helper.bash     # Common test utilities
├── unit/               # Unit tests
│   ├── chunking_test.bats
│   ├── github_test.bats
│   ├── gpt_test.bats
│   └── error_handling_test.bats
├── integration/        # Integration tests
│   └── review_workflow_test.bats
└── mocks/             # Mock responses
    ├── github_responses.sh
    ├── openai_responses.sh
    └── mock_handler.sh
```

### Running Tests

To run all tests:
```bash
./run_tests.sh
```

To run specific test files:
```bash
bats tests/unit/chunking_test.bats
bats tests/integration/review_workflow_test.bats
```

### Mock System

The test infrastructure includes a comprehensive mocking system for external APIs:

- `github_responses.sh`: Mocks for GitHub API responses
- `openai_responses.sh`: Mocks for OpenAI API responses
- `mock_handler.sh`: Coordinates between different mock types

### Test Helper Functions

Common test utilities in `test_helper.bash`:
- `run_with_stderr_redirect`: Handles stderr redirection
- `assert_no_stderr`: Validates stderr output
- `create_test_event`: Creates mock GitHub events
- `assert_error_message`: Validates error messages
- `assert_info_message`: Validates info messages

## Code Style Guidelines

### Bash Script Style

1. Use meaningful variable names:
```bash
# Good
local pull_request_number="123"
# Bad
local n="123"
```

2. Always use local variables in functions:
```bash
function process_data() {
    local input="$1"
    local result
    result=$(transform "$input")
}
```

3. Use shellcheck for linting:
```bash
shellcheck src/*.sh tests/**/*.bash
```

### Documentation Guidelines

1. Function documentation:
```bash
# Description: Processes a pull request and generates a review
# Arguments:
#   $1 - Pull request number
#   $2 - (Optional) Review type
# Returns:
#   0 on success, non-zero on failure
# Outputs:
#   Writes review to stdout
function process_pull_request() {
    local pr_number="$1"
    local review_type="${2:-full}"
    ...
}
```

2. Module documentation:
```bash
#!/usr/bin/env bash
#
# GitHub API interaction module
# Handles all communication with the GitHub API
# Dependencies: curl, jq
```

## Pull Request Process

1. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

2. Add tests for new functionality:
- Unit tests for individual components
- Integration tests for workflow changes
- Error handling tests for edge cases

3. Update documentation:
- Add inline documentation for new functions
- Update README.md if adding user-facing features
- Update CONTRIBUTING.md for development changes

4. Submit your PR:
- Provide a clear description of changes
- Link to any related issues
- Ensure all tests pass
- Follow code style guidelines

## Error Handling

When adding new functionality, ensure proper error handling:

1. Use the error handler module:
```bash
source "./src/error_handler.sh"

if [[ -z "$required_var" ]]; then
    handle_error "Required variable not set"
    return 1
fi
```

2. Add error handling tests:
```bash
@test "function::handles_missing_input" {
    run_with_stderr_redirect function_name ""
    assert_failure
    assert_output --partial "[ERROR]"
}
```

## Questions and Support

- Open an issue for bug reports or feature requests
- Join our community discussions
- Contact maintainers through GitHub

## License

By contributing to Robin AI Reviewer, you agree that your contributions will be licensed under the MIT License.
