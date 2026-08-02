#!/usr/bin/env python3
"""Wrap the assembled SID payload (a C64 .prg) into a PSID v2 file."""
import struct, sys

INIT = 0x1000
PLAY = 0x1003
NAME = b"Motorsag Arkitekt"
AUTH = b"kim_jensen / arr. Claude"
REL  = b"2026 Kattene"

def main(prg_path, out_path):
    with open(prg_path, "rb") as f:
        prg = f.read()                 # starts with 2-byte little-endian load addr
    # PSID v2 header (0x7C bytes). loadAddress=0 -> load addr is first 2 data bytes.
    hdr = bytearray(0x7C)
    hdr[0:4]   = b"PSID"
    struct.pack_into(">H", hdr, 0x04, 0x0002)   # version 2
    struct.pack_into(">H", hdr, 0x06, 0x007C)   # data offset
    struct.pack_into(">H", hdr, 0x08, 0x0000)   # loadAddress (0 => in data)
    struct.pack_into(">H", hdr, 0x0A, INIT)     # initAddress
    struct.pack_into(">H", hdr, 0x0C, PLAY)     # playAddress
    struct.pack_into(">H", hdr, 0x0E, 0x0001)   # songs
    struct.pack_into(">H", hdr, 0x10, 0x0001)   # startSong
    struct.pack_into(">I", hdr, 0x12, 0x00000000)  # speed: 0 = 50Hz/vsync
    hdr[0x16:0x16+len(NAME)] = NAME
    hdr[0x36:0x36+len(AUTH)] = AUTH
    hdr[0x56:0x56+len(REL)]  = REL
    # flags: PAL (bits2-3 = 01), 6581 (bits4-5 = 01)
    struct.pack_into(">H", hdr, 0x76, (0b01 << 2) | (0b01 << 4))
    hdr[0x78] = 0   # startPage
    hdr[0x79] = 0   # pageLength
    hdr[0x7A] = 0   # second SID
    hdr[0x7B] = 0   # third SID
    with open(out_path, "wb") as f:
        f.write(hdr)
        f.write(prg)
    print("wrote %s (%d bytes)" % (out_path, 0x7C + len(prg)))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
