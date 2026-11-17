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

# 서명: 인증서가 있으면 그걸로 서명해서 다시 빌드해도 macOS 권한(전체 디스크 접근)이 유지되게 함
#  - SIGN_IDENTITY 환경변수로 직접 지정 가능 (인증서 이름 또는 SHA-1 해시)
#  - 없으면 키체인에서 "Apple Development" 인증서를 자동으로 찾음
#  - 그것도 없으면 ad-hoc 서명 (다시 빌드할 때마다 권한을 다시 줘야 함)
IDENTITY="${SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/"Apple Development:/ { print $2; exit }')
fi

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "🔏 인증서로 서명함 (다시 빌드해도 권한 유지)"
else
    codesign --force --sign - "$APP"
    echo "⚠️  인증서가 없어 ad-hoc 서명함 (다시 빌드하면 전체 디스크 접근 권한을 다시 줘야 해)"
fi

echo "✅ 빌드 완료: $(pwd)/$APP"
echo "   응용 프로그램 폴더로 옮기려면: mv \"$APP\" /Applications/"
