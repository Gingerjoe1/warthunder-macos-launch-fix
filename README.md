# War Thunder macOS launch fix

Steam War Thunder on some Macs (especially Apple Silicon + Rosetta) never gets
past a dead launcher: **exit -1**, tiny RSS (~16KB), no `aces` process. Full
reinstall / verify often does **not** fix it — Steam just puts the same zips
and broken first-run path back.

This is **not** a crack, cheat, or game recode. It restores install layout and
extracts binaries that **already ship** inside Gaijin’s own zips, then tells
you to clear Gatekeeper if macOS blocks the app.

## What is actually wrong

1. **Primary:** the launcher should unpack `aces` + CEF from those zips. On
   affected installs it dies before that finishes. Reinstall reprints this.
2. **Then:** macOS may still block until **Privacy & Security → Open Anyway**.
3. **OS Error 259:** nest path incomplete (often `WarThunder.app.work` left
   beside the launcher). Layout problem — clears when nest is restored. Not
   the root of (1).

Steam’s `wt_mac_install.vdf` backslash installscript error is cosmetic. Ignore it.

## Proper fix (in order)

1. Restore nest if needed:
   `WarThunderLauncher.app/Contents/WarThunder.app`
2. Unpack `aces` + CEF from the shipped zips if missing.
   Unzip keeps Gaijin’s **Developer ID** signatures (no resign required in the
   normal path).
3. Quit Steam, Play, then **Open Anyway** if macOS blocked the app.
4. Confirm a real client: `aces` RSS tens/hundreds of MB (often GB), not a
   ~16KB launcher stub.

`fix-warthunder-mac.sh` does 1–2. Step 3 is human-only.

Nest restores write an undo script under `$WT/.wt-fix-backup/<timestamp>/`
before moving (no default full-tree copy — that would duplicate ~80GB). Set
`WT_FIX_BACKUP=1` for a full copy first, or `WT_FIX_YES=1` to skip the
interactive confirm when stdin is a TTY.

### About code signing

- **You should not need to re-sign** for the usual fix. The working payload on
  a corrected install is still Gaijin-signed from the zip.
- Blind `codesign --force --sign -` is a **don’t** — it strips the secure
  timestamp and breaks the outer notarized seal.
- The script only ad-hoc signs if `codesign --verify` fails after unpack
  (fallback). Skip that path if verify already passes.

## Do not

- Reinstall hoping for a different outcome.
- Treat OS Error 259 as the root bug if nest restore isn’t finished.
- Move `WarThunder.app` out of the launcher “to fix the seal.”
- Blind ad-hoc re-sign everything.
- Claim Done on a ~16KB launcher with no `aces` child.
- Call this hacking the game — it isn’t.

## Usage

```bash
git clone https://github.com/Gingerjoe1/warthunder-macos-launch-fix.git
cd warthunder-macos-launch-fix
chmod +x fix-warthunder-mac.sh play-warthunder.sh
./fix-warthunder-mac.sh
```

```bash
./fix-warthunder-mac.sh "/path/to/Steam/steamapps/common/War Thunder"
```

### After the script

1. Quit Steam fully, relaunch, hit Play.
2. **System Settings → Privacy & Security → Security → Open Anyway** if blocked.
3. Confirm:

```bash
ps -axo pid,rss,etime,command | grep -i "MacOS/aces" | grep -v grep
```

Fallback if Steam still won’t spawn `aces` after Open Anyway:

```bash
./play-warthunder.sh "/path/to/Steam/steamapps/common/War Thunder"
```

## Disclaimer

Not affiliated with Gaijin Entertainment or Valve. Layout restore + extract of
files already inside the official Mac bundle only. Use at your own risk.
