#!/usr/bin/env bash

# Mock OpenAI API responses
mock_code_review() {
    local data="$1"
    local error_type="${2:-}"

    case "$error_type" in
        "rate_limit")
            cat << 'EOF'
{
    "error": {
        "message": "Rate limit exceeded",
        "type": "rate_limit_error"
    }
}
EOF
            ;;
        "invalid_key")
            cat << 'EOF'
{
    "error": {
        "message": "Invalid API key",
        "type": "invalid_request_error"
    }
}
EOF
            ;;
        "network_error")
            cat << 'EOF'
{
    "error": {
        "message": "API request failed",
        "type": "connection_error"
    }
}
EOF
            ;;
        "malformed")
            cat << 'EOF'
{
    "choices": [{
        "text": "Invalid format response"
    }]
}
EOF
            ;;
        *)
            cat << 'EOF'
{
    "choices": [{
        "message": {
            "content": "<details>\n<summary>Score: 85</summary>\n\nImprovements:\n- Consider using more descriptive function names\n- Add docstrings to functions\n- Follow PEP 8 style guidelines\n\n```python\ndef hello_world():\n    \"\"\"Greet the world.\"\"\"\n    print(\"Hello, World!\")\n```\n</details>"
        }
    }]
}
EOF
            ;;
    esac
}

mock_review_summary() {
    local data="$1"
    local error_type="${2:-}"

    # Reuse code_review mock with different content for simplicity
    mock_code_review "$data" "$error_type"
}

# Export mock functions
export -f mock_code_review
export -f mock_review_summary
