#!/bin/zsh
# Volta · Copyright © 2026 Johannes Uth. All rights reserved.
# Source-available under the Volta License (see LICENSE). Not for redistribution.
#
# Packs build/Volta.app into a designed disk image: dist/Volta-<version>.dmg
# The window shows Volta, an arrow and an Applications shortcut ("drag to install").
# If VOLTA_SIGN_IDENTITY is set, the disk image is signed with it.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${VOLTA_VERSION:-$(<VERSION)}
APP=build/Volta.app
WORK=build/dmg
OUT=dist/Volta-${VERSION}.dmg
TOOLS=.build/dmg-tools

[[ -d "$APP" ]] || { print -u2 "Build the app first: ./Scripts/build-app.sh"; exit 1; }
mkdir -p "$WORK" dist

# Background in 1x and 2x, combined into one multi-resolution TIFF for Retina displays.
swift Scripts/make-dmg-background.swift "$WORK/background.png" 1 "$VERSION"
swift Scripts/make-dmg-background.swift "$WORK/background@2x.png" 2 "$VERSION"
tiffutil -cathidpicheck "$WORK/background.png" "$WORK/background@2x.png" -out "$WORK/background.tiff" >/dev/null

# dmgbuild lays out the Finder window without scripting Finder. It is installed once into .build/.
if [[ ! -x "$TOOLS/bin/dmgbuild" ]]; then
  python3 -m venv "$TOOLS"
  "$TOOLS/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==1.6.5"
fi

rm -f "$OUT"
"$TOOLS/bin/dmgbuild" -s Scripts/dmg-settings.py \
  -D app="$APP" -D background="$WORK/background.tiff" -D icon=build/AppIcon.icns \
  "Volta" "$OUT" >/dev/null

if [[ -n "${VOLTA_SIGN_IDENTITY:-}" && "${VOLTA_SIGN_IDENTITY}" != "-" ]]; then
  codesign --force --sign "$VOLTA_SIGN_IDENTITY" --timestamp "$OUT"
fi
hdiutil verify "$OUT" >/dev/null
print "Disk image: $OUT"
