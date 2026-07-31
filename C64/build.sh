#!/usr/bin/env bash
# Build the Motorsag Arkitekt C64 demo (and a standalone .sid of the music).
#
# Requires ACME (https://sourceforge.net/projects/acme-crossass/).
#   Debian/Ubuntu:  sudo apt-get install acme
#   macOS (brew):   brew install acme
#
# Outputs:
#   motorsag.prg       - the runnable demo   (LOAD"*",8,1 : RUN  /  x64sc motorsag.prg)
#   motorsag.sid       - the tune only, for any SID player / DAW
set -e
cd "$(dirname "$0")"

echo "[1/3] assembling demo -> motorsag.prg"
acme motorsag.asm

echo "[2/3] assembling standalone music payload"
acme sid.asm

echo "[3/4] wrapping music -> motorsag.sid"
python3 make_sid.py motorsag_sid.prg motorsag.sid
rm -f motorsag_sid.prg

echo "[4/4] building disk image -> motorsag.d64 (if c1541 is present)"
if command -v c1541 >/dev/null 2>&1; then
    c1541 -format "motorsag,ma" d64 motorsag.d64 -write motorsag.prg motorsag >/dev/null
else
    echo "   (c1541 not found - skipping .d64; the .prg still runs everywhere)"
fi

echo
echo "done:"
ls -l motorsag.prg motorsag.sid motorsag.d64 2>/dev/null
echo
echo "run the demo:   x64sc motorsag.prg      (or drag the .d64 onto any C64 emulator)"
echo "play the tune:  vsid motorsag.sid       (or load it in any SID player)"
