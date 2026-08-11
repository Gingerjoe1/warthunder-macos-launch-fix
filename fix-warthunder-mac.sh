#!/usr/bin/env bash
# War Thunder macOS: restore nest + unpack aces/CEF from shipped zips.
# Not a crack/recode. Unzip keeps Gaijin signatures — resign is NOT the normal fix.
#
# Order:
#   1. Restore nest if missing / .work   (clears OS Error 259)
#   2. Unpack aces + CEF if missing
#   3. Ad-hoc sign ONLY if codesign --verify fails (usually skip)
#   4. Human: Privacy & Security -> Open Anyway if blocked
#
# Do not: reinstall-loop; move nest out; blind force-sign; Done on 16KB launcher.
#
# Usage:
#   ./fix-warthunder-mac.sh
#   ./fix-warthunder-mac.sh "/path/to/Steam/steamapps/common/War Thunder"
#

set -euo pipefail

find_wt_dir() {
  local vdf="$HOME/Library/Application Support/Steam/steamapps/libraryfolders.vdf"
  local candidates=("$HOME/Library/Application Support/Steam/steamapps/common/War Thunder")

  if [[ -f "$vdf" ]]; then
    while IFS= read -r path; do
      candidates+=("$path/steamapps/common/War Thunder")
    done < <(grep -Eo '"path"[[:space:]]+"[^"]+"' "$vdf" | sed -E 's/.*"path"[[:space:]]+"([^"]+)"/\1/')
  fi

  for c in "${candidates[@]}"; do
    if [[ -d "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

needs_adhoc_sign() {
  local target="$1"
  [[ -e "$target" ]] || return 1
  # Missing / invalid signature → candidate for ad-hoc. Valid Developer ID → leave alone.
  if codesign --verify --quiet "$target" 2>/dev/null; then
    return 1
  fi
  return 0
}

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE="$(find_wt_dir || true)"
fi

if [[ -z "$BASE" || ! -d "$BASE" ]]; then
  echo "Could not find your War Thunder install directory automatically."
  echo "Usage: $0 \"/path/to/Steam/steamapps/common/War Thunder\""
  exit 1
fi

LAUNCHER="$BASE/WarThunderLauncher.app"
INNER="$LAUNCHER/Contents/WarThunder.app"
GAME="$INNER/Contents/Resources/game"

echo "War Thunder dir: $BASE"

echo
echo "== Step 0: restore nest if broken =="
echo "(Incomplete nest (missing/.work) causes OS Error 259; restore clears it. Primary bug is failed aces+CEF unpack.)"

if [[ ! -d "$INNER" && -d "$BASE/WarThunder.app.work" ]]; then
  echo "Nest missing; moving WarThunder.app.work into launcher Contents..."
  mkdir -p "$LAUNCHER/Contents"
  mv "$BASE/WarThunder.app.work" "$INNER"
  echo "Nest restored from .work"
elif [[ ! -d "$INNER" && -d "$BASE/WarThunder.app" ]]; then
  echo "Nest missing; moving top-level WarThunder.app into launcher Contents..."
  mkdir -p "$LAUNCHER/Contents"
  mv "$BASE/WarThunder.app" "$INNER"
  echo "Nest restored from top-level WarThunder.app"
elif [[ -d "$INNER" ]]; then
  echo "Nest path present - skipping."
else
  echo "ERROR: no WarThunder.app nest and no .work restore candidate under:"
  echo "  $BASE"
  echo "Stop and inspect the install layout before continuing."
  exit 1
fi

if [[ ! -d "$GAME" ]]; then
  echo "ERROR: expected payload directory not found at:"
  echo "  $GAME"
  echo "Your install layout may differ from what this script expects. Stop here"
  echo "and inspect \"$BASE\" manually before proceeding."
  exit 1
fi

echo
echo "== Step 1: unpack CEF + aces if missing =="
echo "(Unzip preserves Gaijin Developer ID signatures from the shipped zips.)"

mkdir -p "$INNER/Contents/Frameworks"
mkdir -p "$INNER/Contents/MacOS"

if [[ ! -f "$INNER/Contents/Frameworks/cef.framework/cef" ]]; then
  echo "Unpacking CEF framework from shipped payload..."
  unzip -oq "$GAME/mac_cef_framework.zip" -d "$INNER/Contents/Frameworks"
  unzip -oq "$GAME/frameworks.zip" -d "$INNER/Contents/Frameworks"
  unzip -oq "$GAME/mac_cef_bin.zip" -d "$INNER/Contents/MacOS"
  echo "CEF unpacked."
else
  echo "CEF already present - skipping."
fi

if [[ ! -x "$INNER/Contents/MacOS/aces" ]]; then
  echo "Unpacking aces binary from shipped payload..."
  TMP_DIR="$(mktemp -d)"
  unzip -oq "$GAME/mac.zip" -d "$TMP_DIR"
  cp "$TMP_DIR/aces" "$INNER/Contents/MacOS/"
  chmod +x "$INNER/Contents/MacOS/aces"
  rm -rf "$TMP_DIR"
  echo "aces unpacked."
else
  echo "aces already present - skipping."
fi

echo
echo "== Step 2: ad-hoc sign ONLY if a payload binary fails codesign --verify =="
echo "(Skip healthy Developer ID binaries. Blind --force ad-hoc breaks the outer seal.)"

SIGNED_ANY=0
for target in \
  "$INNER/Contents/MacOS/aces" \
  "$INNER/Contents/Frameworks/cef.framework/cef" \
  "$INNER/Contents/Frameworks/libsteam_api.dylib"
do
  if [[ -e "$target" ]] && needs_adhoc_sign "$target"; then
    echo "Ad-hoc signing (verify failed): $target"
    codesign --force --sign - "$target"
    SIGNED_ANY=1
  elif [[ -e "$target" ]]; then
    echo "Signature OK - leaving alone: $target"
  fi
done

if [[ "$SIGNED_ANY" -eq 0 ]]; then
  echo "No ad-hoc signing needed."
fi

echo
echo "== Step 3: check for a stuck partial Steam update =="

STEAMAPPS_DIR="$(dirname "$(dirname "$BASE")")"
MANIFEST="$(find "$STEAMAPPS_DIR" -maxdepth 1 -iname "appmanifest_236390.acf" 2>/dev/null | head -1)"

if [[ -n "$MANIFEST" ]]; then
  echo "Found manifest: $MANIFEST"
  echo "If Steam ever tries to redownload the whole ~85GB game instead of just"
  echo "launching it, back this file up first, then check/zero these keys:"
  echo "  BytesToDownload, BytesDownloaded, BytesToStage, BytesStaged"
else
  echo "Could not auto-locate appmanifest_236390.acf - check your steamapps/ folder if needed."
fi

cat <<EOF

== Step 4: launch ==

Fully quit Steam, relaunch it, and hit Play.

Then: System Settings -> Privacy & Security -> Security -> Open Anyway
if macOS blocked the app. Do not skip that step.

If the launcher sits at ~16KB RSS with no "aces" child, that is usually still
signature trust (or missing unpack) — not a reason to reinstall.

Sanity check:

  ps -axo pid,rss,etime,command | grep -i "MacOS/aces" | grep -v grep

Real game: RSS tens/hundreds of MB and climbing. Zombie launcher: ~16KB stuck.

If Steam still will not spawn aces after Open Anyway:

  ./play-warthunder.sh "$BASE"
EOF
