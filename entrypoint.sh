#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ "$HOME_DIR" == "/" ]; then
  HOME_DIR=""
fi

export HOME_DIR

source "$HOME_DIR/src/main.sh"

for a in "${@}"; do
  arg=$(echo "$a" | tr '\n' ' ' | xargs echo | sed "s/'//g"| sed "s/’//g")
  sanitizedArgs+=("$arg")
done

main "${sanitizedArgs[@]}"

exit $?
