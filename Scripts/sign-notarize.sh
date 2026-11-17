#!/bin/zsh
# Volta · Copyright © 2026 Johannes Uth. All rights reserved.
# Source-available under the Volta License (see LICENSE). Not for redistribution.
#
# Release build with Developer ID signing and Apple notarization.
# Needs a paid Apple Developer Program membership:
#   VOLTA_SIGN_IDENTITY   "Developer ID Application: Johannes Uth (TEAMID)"
#   VOLTA_NOTARY_PROFILE  name of a profile saved with `xcrun notarytool store-credentials`
# Result: dist/Volta-<version>.dmg, signed, notarized and stapled. On other Macs it opens
# with the normal "downloaded from the Internet" confirmation instead of being blocked.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

: "${VOLTA_SIGN_IDENTITY:?Set VOLTA_SIGN_IDENTITY to your Developer ID Application identity}"
: "${VOLTA_NOTARY_PROFILE:?Set VOLTA_NOTARY_PROFILE to a notarytool Keychain profile}"

VERSION=${VOLTA_VERSION:-$(<VERSION)}
APP=build/Volta.app
DMG=dist/Volta-${VERSION}.dmg

# 1. Build and sign the app with the hardened runtime.
VOLTA_SIGN_IDENTITY="$VOLTA_SIGN_IDENTITY" ./Scripts/build-app.sh
codesign --verify --strict --verbose=2 "$APP"

# 2. Notarize the app itself and staple the ticket, so it also opens offline.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/volta-notary.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
ditto -c -k --keepParent "$APP" "$WORK/Volta.zip"
xcrun notarytool submit "$WORK/Volta.zip" --keychain-profile "$VOLTA_NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

# 3. Pack the stapled app into the disk image, then sign, notarize and staple the image.
VOLTA_SIGN_IDENTITY="$VOLTA_SIGN_IDENTITY" ./Scripts/make-dmg.sh
xcrun notarytool submit "$DMG" --keychain-profile "$VOLTA_NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

(cd dist && shasum -a 256 "Volta-${VERSION}.dmg" > SHA256SUMS.txt)
print "Notarized: $DMG"
print "Put this sha256 into Casks/volta.rb: $(cut -d' ' -f1 dist/SHA256SUMS.txt)"
