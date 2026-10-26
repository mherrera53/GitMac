#!/bin/bash
# Preserve xcodebuild/tee failures and reject incomplete build or test runs.
set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 build|build-for-testing|test|test-without-building LOG_PATH XCODEBUILD_ARGUMENTS..." >&2
    exit 64
fi

operation=$1
log_path=$2
shift 2
case "$operation" in
    build) success_marker='** BUILD SUCCEEDED **' ;;
    build-for-testing) success_marker='** TEST BUILD SUCCEEDED **' ;;
    test) success_marker='** TEST SUCCEEDED **' ;;
    test-without-building) success_marker='** TEST EXECUTE SUCCEEDED **' ;;
    *) echo "Unsupported operation: $operation" >&2; exit 64 ;;
esac

xcodebuild "$@" 2>&1 | tee "$log_path"
if ! grep -Fq -- "$success_marker" "$log_path"; then
    echo "xcodebuild exited without completing $operation; see $log_path" >&2
    exit 1
fi
