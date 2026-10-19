#!/bin/sh
# Builds build/Stretch.app (ad-hoc signed). Pass --install to copy it into /Applications.
set -e
cd "$(dirname "$0")/.."
swift build -c release
APP=build/Stretch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Stretch" "$APP/Contents/MacOS/Stretch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP"
if [ "$1" = "--install" ]; then
  pkill -x Stretch || true
  rm -rf /Applications/Stretch.app
  cp -R "$APP" /Applications/
  open /Applications/Stretch.app
  echo "installed /Applications/Stretch.app"
fi
