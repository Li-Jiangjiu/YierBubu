#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
bash scripts/swift-tool.sh build -c release
binary_dir="$(bash scripts/swift-tool.sh build -c release --show-bin-path)"
"$binary_dir/BubuDesktop" --validate-layers "$project_root/Resources/Layered"
if [[ -L "$project_root/dist" ]]; then
  echo 'Refusing to package through a symlinked dist directory.' >&2
  exit 1
fi
app="$project_root/dist/YierBubu.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/BubuDesktop" "$app/Contents/MacOS/BubuDesktop"
# Remove retired assets only when explicitly building a new package. Never run
# this script just to launch the already-authorized development application.
rm -rf "$app/Contents/Resources/Sprites"
rm -f "$app/Contents/Resources/Layered/characters.png" "$app/Contents/Resources/Layered/characters-blink.png"
/usr/bin/ditto "$project_root/Resources/Layered" "$app/Contents/Resources/Layered"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>YierBubu</string>
  <key>CFBundleDisplayName</key><string>一二布布</string>
  <key>CFBundleIdentifier</key><string>local.yierbubu.desktop</string>
  <key>CFBundleExecutable</key><string>BubuDesktop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>CFBundleShortVersionString</key><string>0.3.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - --identifier local.yierbubu.desktop "$app"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
