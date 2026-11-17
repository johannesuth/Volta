#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Volta.app"
if [[ ! -d "$SOURCE" ]]; then
  SOURCE="$ROOT/build/Volta.app"
fi
if [[ ! -d "$SOURCE" ]]; then
  print -u2 "Volta.app was not found. Build it first with ./Scripts/build-app.sh."
  exit 1
fi

DEST="$HOME/Applications/Volta.app"
mkdir -p "$HOME/Applications"
if [[ -d "$DEST" ]]; then
  mv "$DEST" "${DEST}.backup.$(date +%Y%m%d%H%M%S)"
fi
ditto "$SOURCE" "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
open -a "$DEST"
print "Installed and launched Volta for this user: $DEST"
