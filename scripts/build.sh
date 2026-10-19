#!/bin/bash
# Compila PasteAnything y arma build/PasteAnything.app
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/PasteAnything.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PasteAnything" "$APP/Contents/MacOS/PasteAnything"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Firma local (ad hoc): suficiente para usarla en este Mac.
codesign --force --sign - --options runtime "$APP"

echo "Listo: $(pwd)/$APP"
