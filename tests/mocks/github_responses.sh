#!/usr/bin/env bash

# Mock GitHub API responses
mock_pr_diff() {
    local error_type="${1:-}"

    case "$error_type" in
        "error")
            cat << 'EOF'
{
    "message": "Bad credentials",
    "documentation_url": "https://docs.github.com/rest"
}
EOF
            ;;
        *)
            cat << 'EOF'
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
            ;;
    esac
}

mock_pr_files() {
    local pr_number="$1"
    local error_type="${2:-}"

    case "$error_type" in
        "error")
            cat << 'EOF'
{
    "message": "Validation Failed",
    "errors": [
        {
            "resource": "PullRequest",
            "code": "invalid"
        }
    ]
}
EOF
            ;;
        *)
            cat << 'EOF'
[
    {
        "filename": "test.py",
        "status": "modified",
        "additions": 2,
        "deletions": 2,
        "changes": 4
    }
]
EOF
            ;;
    esac
}

mock_pr_comments() {
    local pr_number="$1"
    local error_type="${2:-}"

    case "$error_type" in
        "error")
            echo "{\"message\": \"Pull Request #$pr_number Not Found\", \"documentation_url\": \"https://docs.github.com/rest\"}"
            ;;
        *)
            echo "[{\"id\": 1, \"body\": \"Test comment on PR #$pr_number\"}]"
            ;;
    esac
}

mock_pr_details() {
    local error_type="${2:-}"

    case "$error_type" in
        "error")
            cat << 'EOF'
{
    "message": "Not Found",
    "documentation_url": "https://docs.github.com/rest"
}
EOF
            ;;
        *)
            cat << 'EOF'
{
    "number": 123,
    "title": "Test PR",
    "body": "Test PR description",
    "state": "open",
    "user": {
        "login": "test-user"
    }
}
EOF
            ;;
    esac
}

# Export mock functions
export -f mock_pr_diff
export -f mock_pr_files
export -f mock_pr_comments
export -f mock_pr_details
