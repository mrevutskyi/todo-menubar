#!/bin/zsh
# Builds CurrentTask.app next to this script. Requires Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

APP=CurrentTask.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library -target arm64-apple-macos13.0 \
  CurrentTask.swift -o "$APP/Contents/MacOS/CurrentTask"

# App icon (regenerate with: swift scripts/make-icon.swift)
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# LSUIElement = menu-bar-only app (no Dock icon, no app menu).
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>CurrentTask</string>
  <key>CFBundleIdentifier</key><string>local.currenttask</string>
  <key>CFBundleExecutable</key><string>CurrentTask</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"   # ad-hoc sign so macOS will launch it
echo "Built $(pwd)/$APP"
