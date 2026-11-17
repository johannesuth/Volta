#!/bin/zsh
# Sign Volta with Developer ID and submit/staple app + installer notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

: "${VOLTA_SIGN_IDENTITY:?Set VOLTA_SIGN_IDENTITY to a Developer ID Application identity}"
: "${VOLTA_INSTALLER_IDENTITY:?Set VOLTA_INSTALLER_IDENTITY to a Developer ID Installer identity}"
: "${VOLTA_NOTARY_PROFILE:?Set VOLTA_NOTARY_PROFILE to an existing notarytool Keychain profile}"

VERSION=${VOLTA_VERSION:-$(<VERSION)}
VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$'
if ! [[ "$VERSION" =~ $VERSION_PATTERN ]]; then
  print -u2 "Invalid VOLTA_VERSION: expected a version such as 2.1.0."
  exit 2
fi
APP=build/Volta.app
ZIP=dist/Volta-${VERSION}-macos-universal.zip
PKG=dist/Volta-${VERSION}-installer.pkg
[[ -d "$APP" ]] || { print -u2 "Build the app first: ./Scripts/build-app.sh"; exit 1; }
mkdir -p dist

codesign --force --deep --options runtime --timestamp --sign "$VOLTA_SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$VOLTA_NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

PKGROOT=$(mktemp -d "${TMPDIR:-/tmp}/volta-notary.XXXXXX")
trap 'rm -rf "$PKGROOT"' EXIT
mkdir -p "$PKGROOT/Applications"
ditto "$APP" "$PKGROOT/Applications/Volta.app"
pkgbuild --root "$PKGROOT" \
  --identifier com.johannesuth.volta.pkg \
  --version "$VERSION" \
  --install-location / \
  --sign "$VOLTA_INSTALLER_IDENTITY" \
  "$PKG"
xcrun notarytool submit "$PKG" --keychain-profile "$VOLTA_NOTARY_PROFILE" --wait
xcrun stapler staple "$PKG"
xcrun stapler validate "$PKG"

# Recreate the ZIP after stapling the app so the ticket is included.
ditto -c -k --keepParent "$APP" "$ZIP"
codesign --verify --deep --strict "$APP"
shasum -a 256 "$ZIP" "$PKG" > dist/SHA256SUMS.txt
print "SHA-256 manifest: dist/SHA256SUMS.txt"
print "Notarized artifacts are ready in dist/. Refresh the Homebrew Cask SHA before publishing."
