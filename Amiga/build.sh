#!/usr/bin/env bash
# Build the Motorsag Arkitekt Amiga 500 demo (v2: SoundTracker module,
# DYCP scroller, bobs, vector ships).
#
# Tools: vasm (m68k/mot: http://sun.hasenbraten.de/vasm/) — required.
#        python3 + numpy regenerate the data files (all committed).
#        amitools' xdftool packs the bootable disk (pip install amitools).
#
# The MOD only regenerates when the ST-xx sample packs are present
# (ST_DIR=... ./build.sh to point at them); the committed motorsag.mod
# is used otherwise — it is also a standalone, tracker-playable module.
set -e
cd "$(dirname "$0")"

STDIR="${ST_DIR:-/Users/einari/Library/Mobile Documents/com~apple~CloudDocs/Amiga/ST-xx Sample Packs}"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import numpy' 2>/dev/null; then
    if [ -r "$STDIR/ST-01" ]; then
        echo "[1/4] rebuilding motorsag.mod from the ST-xx packs"
        # the packs may live on iCloud Drive and be unreadable at times;
        # the committed module is used if that happens
        python3 gen_mod.py "$STDIR" || \
            echo "   (sample packs unreadable - keeping committed motorsag.mod)"
    else
        echo "[1/4] ST-xx packs not found - keeping committed motorsag.mod"
    fi
    echo "[2/4] regenerating graphics data"
    python3 gen_amiga.py
else
    echo "[1-2/4] python3/numpy not found - using committed data files"
fi

echo "[3/4] assembling -> motorsag"
VASM="${VASM:-vasmm68k_mot}"
if ! command -v "$VASM" >/dev/null 2>&1; then
    echo "error: vasmm68k_mot not found (set VASM=/path/to/vasmm68k_mot)"
    exit 1
fi
"$VASM" -Fhunkexe -kick1hunks -o motorsag motorsag.s

echo "[4/4] building bootable disk -> motorsag.adf"
XDF="${XDF:-xdftool}"
if command -v "$XDF" >/dev/null 2>&1; then
    rm -f motorsag.adf
    "$XDF" motorsag.adf create + format "MOTORSAG" ofs + boot install
    "$XDF" motorsag.adf makedir s
    "$XDF" motorsag.adf write startup-sequence s/startup-sequence
    "$XDF" motorsag.adf write motorsag
    "$XDF" motorsag.adf write motorsag.mod
else
    echo "   (xdftool not found - skipping the .adf; pip install amitools)"
fi

echo
ls -l motorsag motorsag.adf motorsag.mod 2>/dev/null
echo "boot motorsag.adf in FS-UAE/WinUAE (A500, PAL, Kickstart 1.3)"
