#!/usr/bin/env bash
# Common helpers for the bats test suite.

# Resolve repo root regardless of where bats is invoked from.
HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
export HOME_DIR

# Override `utils::log_error` so a failure inside a function under test
# doesn't kill the whole bats run; just record + return non-zero.
load_sources() {
  # shellcheck source=../src/utils.sh
  source "$HOME_DIR/src/utils.sh"
  utils::log_error() {
    printf "[ERROR] %s\n" "$*" >&2
    return 1
  }
  # shellcheck source=../src/ai.sh
  source "$HOME_DIR/src/ai.sh"
  # shellcheck source=../src/github.sh
  source "$HOME_DIR/src/github.sh"
  # shellcheck source=../src/gitlab.sh
  source "$HOME_DIR/src/gitlab.sh"
}
