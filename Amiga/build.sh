#!/usr/bin/env bash
# Build the Motorsag Arkitekt Amiga 500 demo.
#
# Requires vasm (m68k, motorola syntax): http://sun.hasenbraten.de/vasm/
#   build:  make CPU=m68k SYNTAX=mot   -> put vasmm68k_mot on your PATH
# Python 3 + numpy regenerate the data files (committed, so optional).
#
# Outputs: motorsag      - Amiga hunk executable
#          motorsag.adf  - bootable floppy image (needs amitools' xdftool:
#                          pip install amitools) — insert into FS-UAE /
#                          WinUAE / a real A500 with a Gotek and boot
set -e
cd "$(dirname "$0")"

if command -v python3 >/dev/null 2>&1 && python3 -c 'import numpy' 2>/dev/null; then
    echo "[1/2] regenerating data (song, samples, copper, screen)"
    python3 gen_amiga.py
else
    echo "[1/2] python3/numpy not found - using committed data files"
fi

echo "[2/3] assembling -> motorsag"
VASM="${VASM:-vasmm68k_mot}"
if ! command -v "$VASM" >/dev/null 2>&1; then
    echo "error: vasmm68k_mot not found (set VASM=/path/to/vasmm68k_mot)"
    exit 1
fi
# -kick1hunks keeps the executable loadable on Kickstart 1.x (no
# reloc32short etc., which 1.3's LoadSeg rejects with error 121)
"$VASM" -Fhunkexe -kick1hunks -o motorsag motorsag.s

echo "[3/3] building bootable disk -> motorsag.adf"
XDF="${XDF:-xdftool}"
if command -v "$XDF" >/dev/null 2>&1; then
    rm -f motorsag.adf
    "$XDF" motorsag.adf create + format "MOTORSAG" ofs + boot install
    "$XDF" motorsag.adf makedir s
    "$XDF" motorsag.adf write startup-sequence s/startup-sequence
    "$XDF" motorsag.adf write motorsag
else
    echo "   (xdftool not found - skipping the .adf; pip install amitools)"
fi

echo
ls -l motorsag motorsag.adf 2>/dev/null
echo "boot motorsag.adf in FS-UAE/WinUAE (A500, PAL) - or run 'motorsag' from a CLI"
