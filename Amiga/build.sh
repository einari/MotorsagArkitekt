#!/usr/bin/env bash
# Build the Motorsag Arkitekt Amiga 500 demo.
#
# Requires vasm (m68k, motorola syntax): http://sun.hasenbraten.de/vasm/
#   build:  make CPU=m68k SYNTAX=mot   -> put vasmm68k_mot on your PATH
# Python 3 + numpy regenerate the data files (committed, so optional).
#
# Output:  motorsag  - Amiga hunk executable (run from CLI/Workbench on
#                      a PAL A500 or any Amiga emulator; takes over the
#                      machine and loops forever)
set -e
cd "$(dirname "$0")"

if command -v python3 >/dev/null 2>&1 && python3 -c 'import numpy' 2>/dev/null; then
    echo "[1/2] regenerating data (song, samples, copper, screen)"
    python3 gen_amiga.py
else
    echo "[1/2] python3/numpy not found - using committed data files"
fi

echo "[2/2] assembling -> motorsag"
VASM="${VASM:-vasmm68k_mot}"
if ! command -v "$VASM" >/dev/null 2>&1; then
    echo "error: vasmm68k_mot not found (set VASM=/path/to/vasmm68k_mot)"
    exit 1
fi
"$VASM" -Fhunkexe -o motorsag motorsag.s

echo
ls -l motorsag
echo "run it on a PAL A500 (or FS-UAE/WinUAE): execute 'motorsag' from CLI"
