#!/usr/bin/env bash
# Direct-launch fallback for War Thunder on macOS, bypassing Steam's own
# launcher wrapper. Use only if the normal Steam launcher still will not spawn
# an "aces" child after fix-warthunder-mac.sh and clearing any Gatekeeper block.
#
# Usage:
#   ./play-warthunder.sh "/path/to/Steam/steamapps/common/War Thunder"

set -euo pipefail

BASE="${1:?Usage: $0 \"/path/to/Steam/steamapps/common/War Thunder\"}"
INNER="$BASE/WarThunderLauncher.app/Contents/WarThunder.app"
GAME="$INNER/Contents/Resources/game"

if [[ ! -x "$INNER/Contents/MacOS/aces" ]]; then
  echo "aces binary not found or not executable at:"
  echo "  $INNER/Contents/MacOS/aces"
  echo "Run fix-warthunder-mac.sh first."
  exit 1
fi

export DYLD_FRAMEWORK_PATH="$INNER/Contents/Frameworks"
export DYLD_LIBRARY_PATH="$INNER/Contents/Frameworks:$INNER/Contents/MacOS"

cd "$GAME"
# Drop the script's own args; pass through only extra args after BASE.
shift
exec arch -x86_64 "$INNER/Contents/MacOS/aces" "$@"
