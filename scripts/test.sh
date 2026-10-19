#!/bin/sh
# Command Line Tools ship swift-testing outside the default search path.
set -e
cd "$(dirname "$0")/.."
D=/Library/Developer/CommandLineTools/Library/Developer
F=$D/Frameworks
if [ -d "$F/Testing.framework" ]; then
  exec swift test -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$D/usr/lib" "$@"
fi
exec swift test "$@"
