#!/bin/sh
# Builds build/ABreak.app (ad-hoc signed).
#   --install     copy into /Applications and launch
#   --zip         also write build/ABreak-<version>.zip for distribution
# Env: UNIVERSAL=1 builds arm64 + x86_64; VERSION=x.y.z stamps Info.plist.
set -e
cd "$(dirname "$0")/.."

if [ "$UNIVERSAL" = "1" ]; then
  # Build each slice separately: multi --arch needs full Xcode, per-triple works with Command Line Tools.
  for a in arm64 x86_64; do
    swift build -c release --triple "$a-apple-macosx14.2"
  done
  BIN=build/ABreak-universal
  mkdir -p build
  lipo -create -output "$BIN" \
    "$(swift build -c release --triple arm64-apple-macosx14.2 --show-bin-path)/ABreak" \
    "$(swift build -c release --triple x86_64-apple-macosx14.2 --show-bin-path)/ABreak"
else
  swift build -c release
  BIN="$(swift build -c release --show-bin-path)/ABreak"
fi

APP=build/ABreak.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ABreak"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -n "$VERSION" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
codesign --force --sign - "$APP"
echo "built $APP ($(lipo -archs "$APP/Contents/MacOS/ABreak"))"

for arg in "$@"; do
  case "$arg" in
    --zip)
      V=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
      ZIP="build/ABreak-$V.zip"
      rm -f "$ZIP"
      ditto -c -k --keepParent "$APP" "$ZIP"
      echo "zipped $ZIP"
      ;;
    --install)
      pkill -x ABreak || true
      rm -rf /Applications/ABreak.app
      cp -R "$APP" /Applications/
      open /Applications/ABreak.app
      echo "installed /Applications/ABreak.app"
      ;;
  esac
done
