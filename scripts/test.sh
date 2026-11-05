#!/bin/sh
# Command Line Tools ship swift-testing outside the default search path.
set -e
cd "$(dirname "$0")/.."
D="$(xcode-select -p)/Library/Developer"
F=$D/Frameworks
# Full Xcode supplies its own matching Testing runtime and macro plugin.
if [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ] && [ -d "$F/Testing.framework" ]; then
  exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$D/usr/lib" "$@"
fi
exec swift test "$@"
