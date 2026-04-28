#!/usr/bin/env bash

# Helpers for splitting an oversized diff into per-file chunks and running
# the AI reviewer over each chunk. The aggregated response keeps the same
# shape the rest of the action expects (a single string), so downstream
# comment / review posting is unchanged.

# chunked::split_by_file reads a unified diff on stdin and prints chunks
# separated by a literal "<<<ROBIN_CHUNK_BOUNDARY>>>" sentinel on its own
# line. NUL would be cleaner but busybox/BSD awk drop embedded NULs in
# printf, and Alpine's runtime image uses busybox.
chunked::split_by_file() {
  awk '
    BEGIN {
      buf = ""
      first = 1
    }
    /^diff --git a\// {
      if (!first) {
        print buf
        print "<<<ROBIN_CHUNK_BOUNDARY>>>"
      }
      buf = $0
      first = 0
      next
    }
    {
      buf = buf "\n" $0
    }
    END {
      if (!first) {
        print buf
      }
    }
  '
}

# chunked::file_path_of_chunk extracts `path/to/file` from the
# `diff --git a/<path> b/<path>` header of a chunk for use in the
# aggregated comment body.
chunked::file_path_of_chunk() {
  local -r chunk="$1"
  # First line is `diff --git a/<path> b/<path>`; pull the `b/` side.
  awk 'NR==1 { sub(/.* b\//, ""); print; exit }' <<< "$chunk"
}

# chunked::review iterates over per-file chunks and concatenates the AI
# responses into a single Markdown body. Each chunk is submitted with the
# existing ai::prompt_model so prompt resolution / model selection / retries
# all keep working.
#
# Args:
#   $1 the full diff
chunked::review() {
  local -r diff="$1"
  local aggregated=""
  local chunk_count=0

  # Slurp the sentinel-delimited output, then split it back in shell. Using
  # mapfile / readarray is unfortunately awkward when the records contain
  # newlines, so we do it with a tmp variable and parameter expansion.
  local raw
  raw="$(printf '%s' "$diff" | chunked::split_by_file)"
  if [[ -z "$raw" ]]; then
    # No `diff --git a/` headers found - just hand off to the single-shot
    # reviewer.
    ai::prompt_model "$diff"
    return
  fi

  local sentinel="<<<ROBIN_CHUNK_BOUNDARY>>>"
  while [[ -n "$raw" ]]; do
    local chunk rest
    if [[ "$raw" == *"$sentinel"* ]]; then
      chunk="${raw%%"$sentinel"*}"
      rest="${raw#*"$sentinel"}"
      # Trim the trailing newline that `print` added before the sentinel.
      chunk="${chunk%$'\n'}"
    else
      chunk="$raw"
      rest=""
    fi
    raw="$rest"

    chunk_count=$((chunk_count + 1))
    local path response
    path="$(chunked::file_path_of_chunk "$chunk")"
    [[ -z "$path" ]] && path="(unknown file)"

    utils::log_info "Reviewing chunk $chunk_count: $path"
    response="$(ai::prompt_model "$chunk")"

    if [[ -z "$response" ]]; then
      response="_(no feedback returned)_"
    fi

    aggregated+="## \`${path}\`"$'\n\n'
    aggregated+="$response"$'\n\n'

    # Strip the leading newline that `print` may have left at the front of
    # the next chunk.
    raw="${raw#$'\n'}"
    [[ -z "$raw" ]] && break
  done

  printf '%s' "$aggregated"
}
