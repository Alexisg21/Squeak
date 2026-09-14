#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Installe d'abord les outils Apple avec : xcode-select --install"
  exit 1
fi
work="$(mktemp -d "${TMPDIR:-/tmp}/squeak-build.XXXXXX")"
app="$work/Squeak.app"
bash Build.command "$app"
mkdir -p "$HOME/Applications"
if [ -d "$HOME/Applications/Squeak.app" ]; then
  if pgrep -f "$HOME/Applications/Squeak.app/Contents/MacOS/Squeak" >/dev/null; then
    echo "Quitte Squeak puis relance cet installateur."; exit 1
  fi
  mv "$HOME/Applications/Squeak.app" "$HOME/Applications/Squeak-backup-$(date +%Y%m%d-%H%M%S).app"
fi
ditto "$app" "$HOME/Applications/Squeak.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$HOME/Applications/Squeak.app"
"$HOME/Applications/Squeak.app/Contents/MacOS/SqueakRegisterBrowsers" "$HOME/Applications/Squeak.app"
open "$HOME/Applications/Squeak.app"
echo "Squeak et son service Finder sont installés. Le menu se trouve dans Services > Intégrer à Squeak."
