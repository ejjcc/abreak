#!/bin/sh
# Builds build/ABreak.app (ad-hoc signed). Pass --install to copy it into /Applications.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/ABreak.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/ABreak" "$APP/Contents/MacOS/ABreak"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP"
if [ "$1" = "--install" ]; then
  pkill -x ABreak || true
  rm -rf /Applications/ABreak.app
  cp -R "$APP" /Applications/
  open /Applications/ABreak.app
  echo "installed /Applications/ABreak.app"
fi
