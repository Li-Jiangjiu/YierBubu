#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest -v test_release.ReleaseTests.test_build_rejects_existing_or_linked_output_without_mutation test_release.ReleaseTests.test_build_rejects_outside_release_tree test_release.ReleaseTests.test_toolchain_failure_cannot_leave_candidate
