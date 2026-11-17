#!/bin/bash
# AccelToggle.app 빌드 스크립트 (Xcode Command Line Tools 필요: xcode-select --install)
#
# 사용법:
#   ./build.sh            개인용 빌드 (인증서가 있으면 인증서로 서명)
#   ./build.sh --release  배포용 빌드 (ad-hoc 서명 + AccelToggle-<버전>.zip 생성)
#                         배포용은 인증서에 포함된 개인정보(이름·이메일·팀 ID)가 앱에 들어가지 않도록
#                         항상 ad-hoc으로 서명합니다.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0.0}"
MIN_MACOS="13.0"
RELEASE=0
[ "${1:-}" = "--release" ] && RELEASE=1

APP="AccelToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# Apple Silicon(arm64) 전용으로 빌드합니다.
# -target을 지정하지 않으면 빌드한 맥의 macOS 버전이 최소 버전이 되므로, 반드시 지정합니다.
swiftc -O -swift-version 5 -target "arm64-apple-macos$MIN_MACOS" \
    main.swift -o "$APP/Contents/MacOS/AccelToggle"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>        <string>local.acceltoggle</string>
    <key>CFBundleName</key>              <string>AccelToggle</string>
    <key>CFBundleExecutable</key>        <string>AccelToggle</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>               <true/>
</dict>
</plist>
EOF

# 서명: 인증서가 있으면 해당 인증서로 서명하여, 다시 빌드해도 macOS 권한(전체 디스크 접근)이 유지되도록 합니다
#  - SIGN_IDENTITY 환경변수로 직접 지정할 수 있습니다 (인증서 이름 또는 SHA-1 해시)
#  - 지정하지 않으면 키체인에서 "Apple Development" 인증서를 자동으로 찾습니다
#  - 인증서가 없으면 ad-hoc 서명을 사용합니다 (다시 빌드할 때마다 권한을 다시 부여해야 합니다)
IDENTITY="${SIGN_IDENTITY:-}"
if [ "$RELEASE" = 1 ]; then
    IDENTITY=""
elif [ -z "$IDENTITY" ]; then
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/"Apple Development:/ { print $2; exit }')
fi

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "🔏 인증서로 서명했습니다 (다시 빌드해도 권한이 유지됩니다)"
else
    codesign --force --sign - "$APP"
    if [ "$RELEASE" = 1 ]; then
        echo "🔏 배포용으로 ad-hoc 서명했습니다"
    else
        echo "⚠️  인증서가 없어 ad-hoc 서명을 사용했습니다 (다시 빌드하면 전체 디스크 접근 권한을 다시 부여해야 합니다)"
    fi
fi

echo "✅ 빌드가 완료되었습니다: $(pwd)/$APP (버전 $VERSION, macOS $MIN_MACOS 이상, Apple Silicon)"

if [ "$RELEASE" = 1 ]; then
    ZIP="AccelToggle-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "📦 배포 파일을 만들었습니다: $(pwd)/$ZIP"
else
    echo "   응용 프로그램 폴더로 옮기려면 다음 명령을 실행하십시오: mv \"$APP\" /Applications/"
fi
