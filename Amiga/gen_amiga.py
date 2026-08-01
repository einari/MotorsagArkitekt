#!/usr/bin/env python3
"""
Generate the data for the Amiga 500 (OCS, PAL) demo, take two:

  amiga_data.i  - copper list + patch tables, colour animations, the
                  scale4x DYCP font, bob images (cats/horses/balls/
                  dancers/circles from the C64 art), ship polygon,
                  sine tables, scroll text, scene timeline
  logo.raw      - 320x256 plane-0 title screen (scale4x font + stars)

The music is motorsag.mod (see gen_mod.py) — the demo embeds and plays
the module itself, so there is no separate sample/stream data any more.

Run:  python3 gen_amiga.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
C64 = os.path.join(HERE, '..', 'C64')
sys.path.insert(0, C64)
import gen_assets as ga                   # noqa: E402  (the C64 pixel art)

# ---------------------------------------------------------------------------
#  The "Kattene" font (8x8 source) + scale2x smoothing
# ---------------------------------------------------------------------------
FONT = {
    'A': [0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00],
    'B': [0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00],
    'C': [0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00],
    'D': [0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00],
    'E': [0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x7E, 0x00],
    'F': [0x7E, 0x60, 0x60, 0x78, 0x60, 0x60, 0x60, 0x00],
    'G': [0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3E, 0x00],
    'H': [0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00],
    'I': [0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00],
    'J': [0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x6C, 0x38, 0x00],
    'K': [0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00],
    'L': [0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00],
    'M': [0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00],
    'N': [0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66, 0x00],
    'O': [0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
    'P': [0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00],
    'Q': [0x3C, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x0E, 0x00],
    'R': [0x7C, 0x66, 0x66, 0x7C, 0x78, 0x6C, 0x66, 0x00],
    'S': [0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00],
    'T': [0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00],
    'U': [0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00],
    'V': [0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00],
    'W': [0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00],
    'X': [0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00],
    'Y': [0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00],
    'Z': [0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00],
    '0': [0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00],
    '1': [0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00],
    '2': [0x3C, 0x66, 0x06, 0x0C, 0x30, 0x60, 0x7E, 0x00],
    '3': [0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00],
    '4': [0x06, 0x0E, 0x1E, 0x66, 0x7F, 0x06, 0x06, 0x00],
    '5': [0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00],
    '6': [0x3C, 0x66, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00],
    '7': [0x7E, 0x66, 0x0C, 0x18, 0x18, 0x18, 0x18, 0x00],
    '8': [0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00],
    '9': [0x3C, 0x66, 0x66, 0x3E, 0x06, 0x66, 0x3C, 0x00],
    ' ': [0] * 8,
    '.': [0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00],
    ',': [0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30],
    '!': [0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00],
    '?': [0x3C, 0x66, 0x06, 0x0C, 0x18, 0x00, 0x18, 0x00],
    '-': [0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00],
    ':': [0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00],
    '*': [0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00],
    '(': [0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x00],
    ')': [0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00],
}
GLYPHS = list(FONT.keys())


def glyph_grid(ch):
    g = FONT.get(ch, FONT[' '])
    return [[(g[y] >> (7 - x)) & 1 for x in range(8)] for y in range(8)]


def scale2x(src):
    """EPX/Scale2x: smooth 2x upscale (rounds the staircase corners)."""
    h, w = len(src), len(src[0])
    out = [[0] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            p = src[y][x]
            a = src[y - 1][x] if y > 0 else 0
            b = src[y][x + 1] if x < w - 1 else 0
            c = src[y][x - 1] if x > 0 else 0
            d = src[y + 1][x] if y < h - 1 else 0
            e0 = c if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != a and c != b) else p
            e3 = b if (b == d and b != a and d != c) else p
            out[y * 2][x * 2] = e0
            out[y * 2][x * 2 + 1] = e1
            out[y * 2 + 1][x * 2] = e2
            out[y * 2 + 1][x * 2 + 1] = e3
    return out


def font16(ch):
    return scale2x(glyph_grid(ch))


def font32(ch):
    return scale2x(scale2x(glyph_grid(ch)))


# ---------------------------------------------------------------------------
#  Logo screen: plane 0, 320x256
# ---------------------------------------------------------------------------
PLANE_W = 44                # 352 px wide planes (32 hidden spill pixels)
DYCP_Y = 190                # DYCP band: 190..255 (66 px)
CAST_Y0, CAST_Y1 = 96, 190  # bob region (planes 1-2)


def blit_grid(plane, grid, x0, y0):
    for y, row in enumerate(grid):
        for x, v in enumerate(row):
            if not v:
                continue
            px, py = x0 + x, y0 + y
            if 0 <= px < 320 and 0 <= py < 256:
                plane[py * PLANE_W + (px >> 3)] |= 0x80 >> (px & 7)


def text32(plane, text, x, y):
    for ch in text:
        blit_grid(plane, font32(ch), x, y)
        x += 32


def text16(plane, text, x, y):
    for ch in text:
        blit_grid(plane, font16(ch), x, y)
        x += 16


def build_logo():
    plane = bytearray(PLANE_W * 256)
    text32(plane, 'KATTENE', 48, 20)
    text16(plane, 'PRESENTERER', 72, 60)
    text32(plane, 'MOTORSAG', 32, 84)
    text32(plane, 'ARKITEKT', 32, 122)
    text16(plane, 'A CLAUDE DEMOSCENE PRODUCTION', 8, 164)
    # starfield sprinkles (deterministic)
    seed = 0x1234
    for i in range(90):
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        x = seed % 320
        y = (seed >> 9) % 250
        if 16 <= y <= 185 and 20 <= x <= 300:
            continue                       # keep the title block clean
        plane[y * PLANE_W + (x >> 3)] |= 0x80 >> (x & 7)
    return bytes(plane)


# ---------------------------------------------------------------------------
#  DYCP font: 32x32 glyphs, blitter-ready (2 words wide, 32 rows)
# ---------------------------------------------------------------------------
def build_dycp_font():
    out = bytearray()
    for ch in GLYPHS:
        g = font32(ch)
        for row in g:
            w = 0
            for x, v in enumerate(row):
                if v:
                    w |= 0x80000000 >> x
            out += w.to_bytes(4, 'big')
    return bytes(out)


def build_font16():
    """16x16 scale2x glyphs, 1 word per row (blitter source)."""
    out = bytearray()
    for ch in GLYPHS:
        g = font16(ch)
        for row in g:
            w = 0
            for x, v in enumerate(row):
                if v:
                    w |= 0x8000 >> x
            out += w.to_bytes(2, 'big')
    return bytes(out)


# ---------------------------------------------------------------------------
#  Lyric cues (bar-synced, same placement as the SID/MOD arrangement)
#  entry: (bar, big?, keyword, line1, line2)
# ---------------------------------------------------------------------------
LYRICS = [
    (4, 1, 'KATTENE', 'DE LEKER SEG', 'MED MOTORSAG'),
    (7, 0, '( OOHH )', '', ''),
    (8, 1, 'HESTENE', 'DE SOEKER', 'ARKITEKTOPPDRAG'),
    (11, 0, '( OOHH )', '', ''),
    (12, 0, 'HVORFOR DET?', '', ''),
    (13, 0, 'DET ER FAKTISK', 'IKKE GODT AA SI', ''),
    (15, 0, 'NEI NEI NEI', '', ''),
    (16, 0, 'MEN DET VI VET', 'ER AT ROMSKIP', ''),
    (17, 1, 'FANTASTISK', 'ER FANTASTISK!', ''),
    (20, 0, '', '', ''),                       # drop: clear the zone
    (36, 1, 'KATTENE', 'DE LEKER SEG', 'MED MOTORSAG'),
    (39, 0, '( OOHH )', '', ''),
    (40, 1, 'HESTENE', 'DE SOEKER', 'ARKITEKTOPPDRAG'),
    (43, 0, '( OOHH )', '', ''),
    (44, 0, 'HVORFOR DET?', '', ''),
    (45, 0, 'DET ER FAKTISK', 'IKKE GODT AA SI', ''),
    (47, 0, 'NEI NEI NEI', '', ''),
    (48, 0, 'MEN DET VI VET', 'ER AT ROMSKIP', ''),
    (49, 1, 'FANTASTISK', 'ER FANTASTISK!', ''),
    (51, 0, '', '', ''),                       # finale: instrumental
    (61, 1, 'TUSEN TAKK', 'ROMSKIP ER FANTASTISK', ''),
]


def build_lyrics():
    """lyr_bars (byte per cue, $ff end) + packed cue blob:
    per cue: size.b, kwlen.b, kw ids..., l1len.b, ids..., l2len.b, ids..."""
    bars = bytes(c[0] for c in LYRICS) + b'\xff'
    blob = bytearray()
    offs = []
    for _, big, kw, l1, l2 in LYRICS:
        offs.append(len(blob))
        blob.append(big)
        for txt in (kw, l1, l2):
            ids = bytes(GLYPHS.index(ch) for ch in txt)
            blob.append(len(ids))
            blob += ids
    return bars, bytes(blob), offs


SCROLLTEXT = ('KATTENE PRESENTERER: MOTORSAG ARKITEKT PAA AMIGA 500!   '
              'MUSIKK: KIM JENSEN, NAA SOM EKTE SOUNDTRACKER MODUL MED '
              'ST-01 LYDER OG VOKAL!   KODE, GRAFIKK OG 68000: CLAUDE   '
              'PROMPTMASTER: EINAR   KATTER MED MOTORSAG - HESTER PAA '
              'ARKITEKTJAKT - OG ROMSKIP SOM VEKTORGRAFIKK!   GREETINGS: '
              'FAIRLIGHT - RAZOR 1911 - THE BLACK LOTUS - SPACEBALLS - '
              'MELON DEZIGN - SCOOPEX - KEFRENS - ANDROMEDA - SANITY - '
              'CRYPTOBURNERS - AND YOU!      ')


# ---------------------------------------------------------------------------
#  Bobs from the C64 art: 2 bitplanes, 32 px wide
#  'K' -> plane1, 'I' -> plane2, 'C'/'X' -> both (colours 2 / 4 / 6)
# ---------------------------------------------------------------------------
def bob_from_art(rows, double=True):
    """C64 multicolour art (12 wide, 2:1 pixels) -> 32-wide bob, each art
    pixel becomes 2x2; hires art (24 wide) becomes 1x2."""
    h = len(rows)
    p1 = bytearray(4 * h * 2)
    p2 = bytearray(4 * h * 2)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            in1 = ch in ('K', 'C', 'X')
            in2 = ch in ('I', 'C', 'X')
            if double:
                xs = [x * 2 + 4, x * 2 + 5]
            else:
                xs = [x + 4]
            for py in (y * 2, y * 2 + 1):
                for px in xs:
                    if px >= 32:
                        continue
                    off = py * 4 + (px >> 3)
                    bit = 0x80 >> (px & 7)
                    if in1:
                        p1[off] |= bit
                    if in2:
                        p2[off] |= bit
    return bytes(p1), bytes(p2)


def build_bobs():
    frames = []
    for i in range(4):
        frames.append(('cat%d' % i, bob_from_art(ga.cat_frame(i))))
    frames.append(('horse0', bob_from_art(ga.HORSE_A)))
    frames.append(('horse1', bob_from_art(ga.HORSE_B)))
    frames.append(('ball0', bob_from_art(ga.ball_rows(), double=False)))
    frames.append(('ball1', bob_from_art(ga.ball_rows(cx=12.5, cy=11),
                                         double=False)))
    frames.append(('dancer0', bob_from_art(ga.DANCER_A, double=False)))
    frames.append(('dancer1', bob_from_art(ga.DANCER_B, double=False)))
    frames.append(('circle0', bob_from_art(ga.circle_rows(0), double=False)))
    frames.append(('circle1', bob_from_art(ga.circle_rows(1), double=False)))
    return frames


BOB_H = {'cat': 42, 'horse': 42, 'ball': 42, 'dancer': 42, 'circle': 42}


# ---------------------------------------------------------------------------
#  Vector ship polygon (nose right), 256-entry sine table for rotation
# ---------------------------------------------------------------------------
SHIP_POLY = [(28, 0), (10, -4), (-2, -14), (-10, -14), (-6, -4),
             (-22, -6), (-26, 0), (-22, 6), (-6, 4), (-10, 14),
             (-2, 14), (10, 4)]
SHIP_CANOPY = [(14, -2), (4, -6), (-4, -6), (-2, 2), (8, 2)]


# ---------------------------------------------------------------------------
#  Copper list v2
# ---------------------------------------------------------------------------
Y0 = 0x2C

# palette: 0 bg (copper), 1 text, 2/4/6 bob colours (+3/5/7 overlaps)
BASE_PAL = {1: 0xFFF, 2: 0x112, 3: 0x9CF, 4: 0xF80, 5: 0xFB6,
            6: 0x9CF, 7: 0xBEF}


def build_copper():
    w = []

    def emit(*v):
        w.extend(v)

    emit(0x008E, 0x2C81, 0x0090, 0x2CC1)
    emit(0x0092, 0x0038, 0x0094, 0x00D0)
    emit(0x0102, 0x0000, 0x0104, 0x0024)     # sprites behind playfield
    emit(0x0108, 0x0004, 0x010A, 0x0004)     # modulo: skip the spill words
    bpl_off = len(w) * 2 + 2
    for reg in (0x00E0, 0x00E2, 0x00E4, 0x00E6, 0x00E8, 0x00EA):
        emit(reg, 0x0000)                    # 3 bitplane pointers (patched)
    emit(0x0100, 0x3200)                     # 3 planes
    pal_off = len(w) * 2 + 2
    for i in range(1, 8):
        emit(0x0180 + i * 2, BASE_PAL[i])    # colours 1-7 (patched/scene)
    emit(0x0180, 0x0000)

    events = []
    for i in range(64):
        events.append((Y0 + i * 4, 0x0180, 0, ('c00', i)))
    # colour-1 gradient through the title block (every 4 lines, 16..188)
    for j in range(44):
        events.append((Y0 + 16 + j * 4, 0x0182, 0x0FFF, ('c01', j)))
    events.sort(key=lambda e: (e[0], e[1]))

    c00 = [0] * 64
    c01 = [0] * 44
    crossed = False
    for line, reg, val, tag in events:
        if line >= 256 and not crossed:
            emit(0xFFDF, 0xFFFE)
            crossed = True
        emit(((line & 0xFF) << 8) | 0x07, 0xFFFE)
        off = len(w) * 2 + 2
        emit(reg, val)
        if tag[0] == 'c00':
            c00[tag[1]] = off
        else:
            c01[tag[1]] = off
    emit(0xFFFF, 0xFFFE)
    return w, c00, c01, bpl_off, pal_off


# ---------------------------------------------------------------------------
#  Colour tables (RGB12) — shared look with v1
# ---------------------------------------------------------------------------
def rgb_ramps():
    return {'cyan': [0x023, 0x067, 0x0BD, 0x5FF, 0x0BD, 0x067, 0x023, 0],
            'pink': [0x304, 0x717, 0xC3C, 0xF7F, 0xC3C, 0x717, 0x304, 0],
            'gold': [0x420, 0x840, 0xC81, 0xFE6, 0xC81, 0x840, 0x420, 0],
            'green': [0x032, 0x074, 0x2C6, 0xAFC, 0x2C6, 0x074, 0x032, 0]}


def sky_gradient():
    g = []
    for i in range(26):
        t = i / 25
        r = int(1 + 12 * t ** 1.6)
        gg = int(3 * t ** 2)
        b = int(4 + 6 * (1 - t) * t + 4 * t)
        g.append(min(15, r) << 8 | min(15, gg) << 4 | min(15, b))
    return g


def grid_anim():
    tab = []
    for t in range(96):
        row = [0x0102] * 38
        row[0] = 0x408
        for k in range(6):
            z = ((k * 16 + t) % 96) / 96
            s = int(1 + 36.9 * z ** 2.4)
            if s < 38:
                row[s] = 0xF3B if s >= 26 else (0x92C if s >= 13 else 0x316)
        tab.append(row)
    return tab


def tunnel_anim():
    pal = [0x000, 0x114, 0x228, 0x33C, 0x55F, 0x99F, 0xEEF, 0xFFF,
           0xEEF, 0xB6F, 0x84D, 0x62A, 0x417, 0x214, 0x102, 0x000]
    tab = []
    for t in range(96):
        tab.append([pal[(int(44 / (abs(s - 32) + 2.2)) + t // 2) & 15]
                    for s in range(64)])
    return tab


def rainbow():
    return [0x137, 0x25B, 0x4AF, 0x8DF, 0xCFF, 0x8DF, 0x4AF, 0x25B,
            0x519, 0x92D, 0xD5E, 0xFAF, 0xFFF, 0xFAF, 0xD5E, 0x92D,
            0x841, 0xC72, 0xFB3, 0xFE8, 0xFFC, 0xFE8, 0xFB3, 0xC72,
            0x152, 0x2A4, 0x6E8, 0xCFC, 0x6E8, 0x2A4, 0x137, 0x114]


def logo_gradient():
    """44 slots of metallic copper-ish gradient for COLOR01."""
    g = []
    for i in range(44):
        t = (math.sin(i / 43 * math.pi * 3) + 1) / 2
        r = int(6 + 9 * t)
        gg = int(6 + 8 * t)
        b = int(9 + 6 * (1 - t))
        g.append(min(15, r) << 8 | min(15, gg) << 4 | min(15, b))
    return g


def sine_tabs():
    s64 = [round(20.5 + 17.5 * math.sin(i * 2 * math.pi / 64))
           for i in range(64)]
    dycp = [round(15 + 14 * math.sin(i * 2 * math.pi / 128))
            for i in range(128)]
    rot = [round(127 * math.sin(i * 2 * math.pi / 256)) for i in range(256)]
    return s64, dycp, rot


# ---------------------------------------------------------------------------
#  Emit
# ---------------------------------------------------------------------------
def fmt_words(label, vals, per=8):
    lines = [label + ':']
    for i in range(0, len(vals), per):
        lines.append('\tdc.w ' +
                     ','.join(f'${v & 0xffff:04x}' for v in vals[i:i + per]))
    return '\n'.join(lines) + '\n'


def fmt_bytes(label, data, per=16):
    lines = [label + ':']
    for i in range(0, len(data), per):
        lines.append('\tdc.b ' + ','.join(f'${b & 0xff:02x}'
                                          for b in data[i:i + per]))
    return '\n'.join(lines) + '\n'


def main():
    logo = build_logo()
    with open(os.path.join(HERE, 'logo.raw'), 'wb') as f:
        f.write(logo)

    cop, c00, c01, bpl_off, pal_off = build_copper()
    s64, dycp, rot = sine_tabs()

    with open(os.path.join(HERE, 'amiga_data.i'), 'w') as f:
        f.write('; --- Auto-generated by gen_amiga.py — DO NOT EDIT ---\n\n')
        f.write(fmt_words('coplist', cop))
        f.write('\teven\n')
        f.write(fmt_words('copoff_c00', c00))
        f.write(fmt_words('copoff_c01', c01))
        f.write(f'COPOFF_BPL = {bpl_off}\n')
        f.write(f'COPOFF_PAL = {pal_off}\n')
        f.write(f'DYCP_Y = {DYCP_Y}\n')
        f.write(f'CAST_Y0 = {CAST_Y0}\n')
        f.write(f'CAST_Y1 = {CAST_Y1}\n\n')

        r = rgb_ramps()
        f.write(fmt_words('ramp_cyan', r['cyan']))
        f.write(fmt_words('ramp_pink', r['pink']))
        f.write(fmt_words('ramp_gold', r['gold']))
        f.write(fmt_words('ramp_green', r['green']))
        f.write(fmt_words('sky_grad', sky_gradient()))
        f.write(fmt_words('grid_anim',
                          [v for row in grid_anim() for v in row], 19))
        f.write(fmt_words('tunnel_anim',
                          [v for row in tunnel_anim() for v in row], 16))
        f.write(fmt_words('rainbow32', rainbow()))
        f.write(fmt_words('logo_grad', logo_gradient()))
        f.write(fmt_bytes('sine64', bytes(s64)))
        f.write(fmt_bytes('dycp_sine', bytes(dycp)))
        f.write(fmt_bytes('rot_sine', bytes(b & 0xff for b in rot)))
        f.write(fmt_bytes('scene_of_bar', bytes(
            [0] * 4 + [1] * 16 + [2] * 14 + [3] * 17 + [4] * 10 + [5] * 3)))
        f.write('\teven\n\n')

        # scene palettes for colours 2..7 (patched at scene switch)
        f.write(fmt_words('pal_cats',   [0x112, 0x9CF, 0xF80, 0xFB6,
                                         0x9CF, 0xBEF]))
        f.write(fmt_words('pal_horses', [0x112, 0x9CF, 0x92E, 0xB6F,
                                         0x6BF, 0xBEF]))
        f.write(fmt_words('pal_ships',  [0x112, 0x8AC, 0x2BF, 0x6DF,
                                         0xACE, 0xDEF]))   # metallic hull
        f.write(fmt_words('pal_tunnel', [0x000, 0x9CF, 0xF4A, 0xF8C,
                                         0xFE6, 0xFFF]))
        f.write('\n')

        f.write(fmt_bytes('dycp_font', build_dycp_font()))
        f.write('\teven\n')
        f.write(fmt_bytes('font16', build_font16()))
        f.write('\teven\n')
        text_ids = bytes(GLYPHS.index(c) for c in SCROLLTEXT) + b'\xff'
        f.write(fmt_bytes('scrolltext', text_ids))
        f.write('\teven\n')
        lyr_bars, lyr_blob, lyr_offs = build_lyrics()
        f.write(fmt_bytes('lyr_bars', lyr_bars))
        f.write(fmt_words('lyr_offs', lyr_offs))
        f.write(fmt_bytes('lyr_blob', lyr_blob))
        f.write('\teven\n\n')

        total = 0
        for name, (p1, p2) in build_bobs():
            f.write(fmt_bytes(f'bob_{name}_1', p1))
            f.write(fmt_bytes(f'bob_{name}_2', p2))
            total += len(p1) + len(p2)
        f.write('\teven\n')

        f.write(fmt_words('ship_poly',
                          [v & 0xffff for pt in SHIP_POLY for v in pt]))
        f.write(f'SHIP_PTS = {len(SHIP_POLY)}\n')
        f.write(fmt_words('ship_canopy',
                          [v & 0xffff for pt in SHIP_CANOPY for v in pt]))
        f.write(f'CANOPY_PTS = {len(SHIP_CANOPY)}\n')

    print(f'amiga_data.i written: copper {len(cop)} words, '
          f'bobs {total} bytes, logo.raw {len(logo)} bytes')


if __name__ == '__main__':
    main()
