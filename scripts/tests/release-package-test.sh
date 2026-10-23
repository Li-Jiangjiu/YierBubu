#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest -v test_release.ReleaseTests.test_package_rejects_thin_binary_and_newer_deployment test_release.ReleaseTests.test_package_checks_version_before_creating_output test_release.ReleaseTests.test_real_macho_package_and_tamper_detection test_release.ReleaseTests.test_package_never_replaces_existing_directory
