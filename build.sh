#!/bin/bash
# AccelToggle.app 빌드 스크립트 (Xcode Command Line Tools 필요: xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")"

APP="AccelToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/AccelToggle"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>local.acceltoggle</string>
    <key>CFBundleName</key>              <string>AccelToggle</string>
    <key>CFBundleExecutable</key>        <string>AccelToggle</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>LSUIElement</key>               <true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

echo "✅ 빌드 완료: $(pwd)/$APP"
echo "   응용 프로그램 폴더로 옮기려면: mv \"$APP\" /Applications/"
