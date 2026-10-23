#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.build/module-cache"
developer_root="$(xcode-select -p)"
frameworks="$developer_root/Library/Developer/Frameworks"
if [[ ! -d "$frameworks/Testing.framework" ]]; then
  frameworks="$developer_root/Platforms/MacOSX.platform/Developer/Library/Frameworks"
fi
swift_binary="$(xcrun --find swiftc)"
plugins="$(dirname "$swift_binary")/../lib/swift/host/plugins/testing"
# Command Line Tools has Swift Testing but no XCTest. Explicit paths also avoid
# the new SwiftBuild driver's missing TestingMacros flag during module emission.
subcommand="${1:-build}"
shift || true
if [[ "$subcommand" == test ]]; then
  set -- --disable-xctest "$@"
  if [[ -d "$frameworks/Testing.framework" ]]; then
    set -- -Xswiftc -F -Xswiftc "$frameworks" -Xlinker -rpath -Xlinker "$frameworks" "$@"
  fi
  if [[ -d "$plugins" ]]; then
    set -- -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
  fi
fi
exec swift "$subcommand" --build-system native --disable-sandbox \
  --cache-path "$project_root/.build/cache" \
  --config-path "$project_root/.build/config" \
  --security-path "$project_root/.build/security" \
  "$@"
