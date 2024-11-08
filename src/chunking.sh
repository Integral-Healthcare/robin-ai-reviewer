#!/usr/bin/env bash
#
# Chunking Module
# Handles the splitting of large diffs into manageable chunks and merging of reviews
#
# This module provides functionality to:
# 1. Split large diffs into smaller chunks while preserving file boundaries
# 2. Merge multiple reviews into a single coherent review
# 3. Handle score averaging and improvement deduplication
#
# Dependencies:
#   - error_handler.sh: Error handling utilities
#   - utils.sh: Logging and utility functions
#
# Environment Variables:
#   MAX_CHUNK_SIZE: Maximum characters per chunk (default: 3000)
#   MAX_FILES_PER_CHUNK: Maximum files per chunk (default: 5)
#   CHUNK_SEPARATOR: String to separate chunks (default: "=== END OF CHUNK ===")

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/error_handler.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utils.sh"

readonly MAX_CHUNK_SIZE=${MAX_CHUNK_SIZE:-3000}  # Characters per chunk
readonly MAX_FILES_PER_CHUNK=${MAX_FILES_PER_CHUNK:-5}
readonly CHUNK_SEPARATOR=${CHUNK_SEPARATOR:-"=== END OF CHUNK ==="}

chunking::split_diff() {
    local diff="$1"
    local context="Diff chunking"

    if [[ -z "$diff" ]]; then
        utils::log_warn "Empty diff provided" "$context" >&2
        printf "%s" "$CHUNK_SEPARATOR"
        return 0
    fi

    # Split diff into individual file changes
    local IFS=$'\n'
    local files=()
    local current_file=""
    local in_file=false

    while read -r line; do
        if [[ "$line" =~ ^diff\ --git ]]; then
            if [[ "$in_file" == true ]]; then
                files+=("$current_file")
                current_file=""
            fi
            in_file=true
        fi
        if [[ "$in_file" == true ]]; then
            [[ -n "$current_file" ]] && current_file+=$'\n'
            current_file+="$line"
        fi
    done <<< "$diff"

    # Add the last file if exists
    if [[ -n "$current_file" ]]; then
        files+=("$current_file")
    fi

    # Group files into chunks
    local chunks=()
    local current_chunk=""
    local chunk_size=0
    local files_in_chunk=0

    for file in "${files[@]}"; do
        local file_size=${#file}

        # Force new chunk if we've hit the file limit or size limit
        if ((files_in_chunk >= MAX_FILES_PER_CHUNK)) || ((chunk_size + file_size > MAX_CHUNK_SIZE)); then
            if [[ -n "$current_chunk" ]]; then
                chunks+=("$current_chunk")  # Don't remove trailing newline here
                current_chunk=""
                chunk_size=0
                files_in_chunk=0
            fi
        fi

        # Add file to current chunk
        if [[ -n "$current_chunk" ]]; then
            current_chunk+=$'\n'
            ((chunk_size++))  # Account for newline
        fi
        current_chunk+="$file"
        chunk_size=$((chunk_size + ${#file}))
        ((files_in_chunk++))
        [[ "$files_in_chunk" -eq "$MAX_FILES_PER_CHUNK" ]] && chunks+=("$current_chunk") && current_chunk="" && chunk_size=0 && files_in_chunk=0
    done

    # Add the last chunk if exists
    if [[ -n "$current_chunk" ]]; then
        chunks+=("$current_chunk")
    fi

    # Output chunks with separator
    local chunk_count=${#chunks[@]}
    if ((chunk_count > 1)); then
        utils::log_info "Split diff into $chunk_count chunks" "$context" >&2
    fi

    if [[ ${#chunks[@]} -eq 0 ]]; then
        printf "%s" "$CHUNK_SEPARATOR"
    else
        local first=true
        for chunk in "${chunks[@]}"; do
            if [[ "$first" == true ]]; then
                first=false
                printf "%s" "$chunk"
            else
                printf "\n%s" "$chunk"
            fi
            printf "%s" "$CHUNK_SEPARATOR"
        done
    fi
}

# Description: Merges multiple code reviews into a single coherent review
# Arguments:
#   $@ - Array of review strings, each in the format:
#        <details>
#        <summary>Score: N</summary>
#        Improvements:
#        - Improvement 1
#        - Improvement 2
#        </details>
# Returns:
#   0 on success, non-zero on failure
# Outputs:
#   Writes merged review to stdout with:
#   - Averaged score
#   - Deduplicated improvements
#   - Code block examples for scores < 90
# Notes:
#   - Handles "nothing to grade" reviews by skipping them
#   - Preserves code blocks only from the first review
chunking::merge_reviews() {
    local reviews=("$@")
    local context="Review merging"

    if [[ ${#reviews[@]} -eq 0 ]]; then
        utils::log_warn "No reviews to merge" "$context" >&2
        printf ""
        return 0
    fi

    if [[ ${#reviews[@]} -eq 1 ]]; then
        printf "%s" "${reviews[0]}"
        return 0
    fi

    # Extract scores and improvements from each review
    local total_score=0
    local all_improvements=""
    local review_count=0

    for review in "${reviews[@]}"; do
        if [[ "$review" == "nothing to grade" ]]; then
            continue
        fi

        # Extract score
        local score
        score=$(echo "$review" | grep -oP "Score: \K[0-9]+")
        if [[ -n "$score" ]]; then
            total_score=$((total_score + score))
            review_count=$((review_count + 1))
        fi

        # Extract improvements
        local improvements
        improvements=$(echo -e "$review" | sed -n '/Improvements:/,/<\/details>/p' | grep -E '^[-*]' | sed 's/^[[:space:]]*//g' || true)
        if [[ -n "$improvements" ]]; then
            all_improvements+="$improvements"$'\n'
        fi
    done

    # Calculate average score
    local final_score=0
    if [[ $review_count -gt 0 ]]; then
        final_score=$((total_score / review_count))
    fi

    # Remove duplicate improvements and sort
    local unique_improvements
    unique_improvements=$(echo -e "$all_improvements" | sort -u | sed '/^[[:space:]]*$/d')

    # Format final review
    printf "<details>\n<summary>Score: %d</summary>\n\nImprovements:\n%s\n" "$final_score" "$unique_improvements"

    # Add code block if score is below 90
    if [[ $final_score -lt 90 ]] && [[ "${reviews[0]}" != "nothing to grade" ]]; then
        local code_block
        code_block=$(echo -e "${reviews[0]}" | awk '/^```/{p=!p;next} p{print}' || true)
        if [[ -n "$code_block" ]]; then
            printf "\n\`\`\`\n%s\n\`\`\`" "$code_block"
        fi
    fi

    printf "</details>\n"
}
