#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest -v test_release.ReleaseTests.test_export_whitelist_with_spaces_and_without_artwork test_release.ReleaseTests.test_export_never_overwrites_or_follows_link
