#!/bin/zsh
# Volta · Copyright © 2026 Johannes Uth. All rights reserved.
# Source-available under the Volta License (see LICENSE). Not for redistribution.
# Build a universal Volta.app and its disk image (dist/Volta-<version>.dmg); --install also copies it to Applications.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

VERSION=${VOLTA_VERSION:-$(<VERSION)}
BUILD_NUMBER=${VOLTA_BUILD_NUMBER:-33}
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$'
if ! [[ "$VERSION" =~ $VERSION_PATTERN ]]; then
  print -u2 "Invalid VOLTA_VERSION: expected a version such as 2.1.0."
  exit 2
fi
BUILD_PATTERN='^[0-9]+$'
if ! [[ "$BUILD_NUMBER" =~ $BUILD_PATTERN ]]; then
  print -u2 "Invalid VOLTA_BUILD_NUMBER: expected a positive integer."
  exit 2
fi
APP=build/Volta.app
DIST=dist
ARM_TRIPLE=arm64-apple-macosx15.0
X86_TRIPLE=x86_64-apple-macosx15.0
ARM_BUILD_PATH=.build/release-arm64
X86_BUILD_PATH=.build/release-x86_64

swift build -c release --triple "$ARM_TRIPLE" --build-path "$ARM_BUILD_PATH"
ARM_BIN="$(swift build -c release --show-bin-path --triple "$ARM_TRIPLE" --build-path "$ARM_BUILD_PATH")/Volta"
swift build -c release --triple "$X86_TRIPLE" --build-path "$X86_BUILD_PATH"
X86_BIN="$(swift build -c release --show-bin-path --triple "$X86_TRIPLE" --build-path "$X86_BUILD_PATH")/Volta"

[[ -x "$ARM_BIN" ]] || { print -u2 "Missing arm64 executable: $ARM_BIN"; exit 1; }
[[ -x "$X86_BIN" ]] || { print -u2 "Missing x86_64 executable: $X86_BIN"; exit 1; }

rm -rf "$APP" build/Volta.app.backup.*(N)
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$ARM_BIN" "$X86_BIN" -output "$APP/Contents/MacOS/Volta"

# Reuse the project's generated icon; create it only when absent.
if [[ ! -f build/AppIcon.icns ]]; then
  mkdir -p build/AppIcon.iconset
  swift Scripts/make-icon.swift build/icon-1024.png
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z "$((s * 2))" "$((s * 2))" build/icon-1024.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
ditto Resources/de.lproj "$APP/Contents/Resources/de.lproj"
ditto Resources/en.lproj "$APP/Contents/Resources/en.lproj"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>CFBundleDisplayName</key><string>Volta</string>
  <key>CFBundleExecutable</key><string>Volta</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>com.johannesuth.volta</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Volta</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Johannes Uth. All rights reserved.</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>CFBundleLocalizations</key><array><string>de</string><string>en</string></array>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>com.johannesuth.volta.deeplink</string>
    <key>CFBundleURLSchemes</key><array><string>volta</string></array>
  </dict></array>
  <key>NSAppleEventsUsageDescription</key><string>Volta changes Low Power Mode only when you ask it to.</string>
</dict>
</plist>
PLIST

SIGN_IDENTITY=${VOLTA_SIGN_IDENTITY:--}
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
  print "Signing: ad-hoc (local development; not notarized)"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  print "Signing identity: $SIGN_IDENTITY"
fi
codesign --verify --deep --strict "$APP"

print "Built and verified: $APP"
rm -rf "$DIST"
mkdir -p "$DIST"
./Scripts/make-dmg.sh
DMG="$DIST/Volta-${VERSION}.dmg"
(cd "$DIST" && shasum -a 256 "Volta-${VERSION}.dmg" > SHA256SUMS.txt)
print "SHA-256 manifest: $DIST/SHA256SUMS.txt"

if [[ "${1:-}" == "--install" || "${VOLTA_INSTALL:-0}" == "1" ]]; then
  if [[ -w /Applications ]]; then
    DEST=/Applications/Volta.app
  else
    DEST="$HOME/Applications/Volta.app"
    mkdir -p "$HOME/Applications"
  fi
  osascript -e 'tell application id "com.johannesuth.volta" to quit' >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
  open -a "$DEST"
  print "Installed and launched: $DEST"
fi
