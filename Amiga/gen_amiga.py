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
    (36, 1, 'KATTENE', 'DE LEKER SEG', 'MED MOTORSAG'),
    (39, 0, '( OOHH )', '', ''),
    (40, 1, 'HESTENE', 'DE SOEKER', 'ARKITEKTOPPDRAG'),
    (43, 0, '( OOHH )', '', ''),
    (44, 0, 'HVORFOR DET?', '', ''),
    (45, 0, 'DET ER FAKTISK', 'IKKE GODT AA SI', ''),
    (47, 0, 'NEI NEI NEI', '', ''),
    (48, 0, 'MEN DET VI VET', 'ER AT ROMSKIP', ''),
    (49, 1, 'FANTASTISK', 'ER FANTASTISK!', ''),
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
# ---------------------------------------------------------------------------
#  The web version's ship, as a filled-vector mesh (Spaceships.ts scaled
#  x16): 6-segment squashed-cone fuselage, rear block, wing slab.  Faces
#  carry a colour class (0 dark / 1 mid / 2 bright) and CCW-outside
#  winding for backface culling.
# ---------------------------------------------------------------------------
def ship_mesh():
    verts = [(26, 0, 0)]                       # 0: nose (cone tip)
    for k in range(6):                         # 1-6: cone base ring
        a = k / 6 * 2 * math.pi
        verts.append((-26, round(8 * math.cos(a)), round(4 * math.sin(a))))
    # 7-14: rear block (x -28..-14, y -4..4, z -6..6)
    for x in (-14, -28):
        for y in (4, -4):
            for z in (-6, 6):
                verts.append((x, y, z))
    # 15-18: wing slab top corners (y -1), 19-22 bottom (y -2)
    for y in (-1, -2):
        for x, z in ((-2, -21), (-2, 21), (-20, 21), (-20, -21)):
            verts.append((x, y, z))

    faces = []
    for k in range(6):                         # cone sides
        a, b = 1 + k, 1 + (k + 1) % 6
        up = math.cos((k + 0.5) / 6 * 2 * math.pi)
        cls = 2 if up > 0.4 else (0 if up < -0.4 else 1)
        faces.append((cls, [0, b, a]))
    # rear block: +x face skipped (buried in the cone base region)
    faces.append((2, [7, 8, 12, 11]))          # top    (y+)
    faces.append((0, [9, 13, 14, 10]))         # bottom
    faces.append((1, [8, 10, 14, 12]))         # z+ side
    faces.append((1, [7, 11, 13, 9]))          # z- side
    faces.append((1, [11, 12, 14, 13]))        # back   (x-)
    faces.append((1, [15, 16, 17, 18]))        # wing top
    faces.append((0, [19, 22, 21, 20]))        # wing bottom
    return verts, faces


# per-ship path constants (the web update() formulas, angle steps in
# 8.8 fixed 256-per-turn units at 50 fps)
def ship_paths():
    ships = []
    for i, speed in enumerate((0.4, 0.55)):
        def step(w):
            return round(w * speed / 50 * 256 / (2 * math.pi) * 256)
        ships.append(dict(s1=step(0.5), s2=step(0.8), s3=step(0.4),
                          p2=round(i * 1.7 * 256 / (2 * math.pi)) & 255,
                          lane=round((i - 0.5) * 2.2 * 0.3 * 16),
                          amp=round((1.2 + 0.5 * i) * 16),
                          depth=round((-2 - i * 1.5) * 16)))
    return ships


def scale_table():
    """Perspective scale (<<7) for camera distance 144, z -96..+8."""
    return [max(40, min(160, round(144 * 128 / (144 - z))))
            for z in range(-96, 9, 2)]


def atan_table():
    """atan(i/32) in 256-per-turn units, i = 0..32 (for octant atan2)."""
    return [round(math.atan(i / 32) * 256 / (2 * math.pi)) for i in range(33)]


# ---------------------------------------------------------------------------
#  Copper list v3: one COLOR00 write on EVERY line (smooth 4096-colour
#  gradients, plasma, and the CRT scanline pass all ride on this), and
#  a COLOR01 gradient write every second line through the text zone.
# ---------------------------------------------------------------------------
Y0 = 0x2C

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
    for i in range(256):
        events.append((Y0 + i, 0x0180, 0, ('c00', i)))
    for j in range(85):
        events.append((Y0 + 16 + j * 2, 0x0182, 0x0FFF, ('c01', j)))
    events.sort(key=lambda e: (e[0], e[1]))

    c00 = [0] * 256
    c01 = [0] * 85
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
#  Colour tables — smooth 4096-colour ramps this time
# ---------------------------------------------------------------------------
def rgb(r, g, b):
    return (max(0, min(15, round(r))) << 8 | max(0, min(15, round(g))) << 4
            | max(0, min(15, round(b))))


def lerp3(c0, c1, t):
    return tuple(a + (b - a) * t for a, b in zip(c0, c1))


def gradient(stops, n):
    """stops: [(pos0..1, (r,g,b)), ...] -> n RGB12 words, smooth."""
    out = []
    for i in range(n):
        t = i / max(1, n - 1)
        for (p0, col0), (p1, col1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                f = 0 if p1 == p0 else (t - p0) / (p1 - p0)
                out.append(rgb(*lerp3(col0, col1, f)))
                break
        else:
            out.append(rgb(*stops[-1][1]))
    return out


def bar_ramp(hue):
    """32-line smooth glow bar (sin-shaped) toward white, per hue."""
    out = []
    for i in range(32):
        t = math.sin(i / 31 * math.pi)
        r = lerp3((0, 0, 0), hue, t)
        w_ = lerp3(r, (15, 15, 15), max(0, t - 0.72) * 3.2)
        out.append(rgb(*w_))
    return out


def plasma_tables():
    """Two sine fields + a 32-entry web-plasma palette (pink-purple-cyan)."""
    s1 = [round(60 + 59 * math.sin(i / 256 * 2 * math.pi * 3)) for i in range(256)]
    s2 = [round(60 + 59 * math.sin(i / 256 * 2 * math.pi * 5 + 1.3)) for i in range(256)]
    pal = []
    for i in range(32):
        t = i / 32 * 2 * math.pi
        r = 8 + 6.5 * math.sin(t)
        g = 4.5 + 3.5 * math.sin(t + 2.6)
        b = 9 + 5.5 * math.sin(t + 4.2)
        pal.append(rgb(r, g, b))
    return s1, s2, pal


def sunset_lines():
    """Per-line sky gradient down to the horizon (104 lines)."""
    return gradient([(0.0, (0.5, 0.2, 2)), (0.45, (4, 0.5, 7)),
                     (0.75, (11, 1, 7)), (0.92, (15, 4, 4)),
                     (1.0, (15, 9, 3))], 104)


def persp96():
    """Grid-line y offsets below the horizon, accelerating (96 phases)."""
    return [min(151, round(2 + 149 * (t / 96) ** 2.4)) for t in range(96)]


def rainbow64():
    out = []
    for i in range(64):
        t = i / 64 * 2 * math.pi
        out.append(rgb(8 + 7 * math.sin(t), 8 + 7 * math.sin(t + 2.1),
                       8 + 7 * math.sin(t + 4.2)))
    return out


def logo_gradient():
    """96-entry smooth metallic gradient for the letter colour."""
    out = []
    for i in range(96):
        t = (math.sin(i / 96 * math.pi * 2 * 3) + 1) / 2
        out.append(rgb(6 + 9 * t, 6 + 8 * t, 9 + 6 * (1 - t)))
    return out


def build_drop_overlay():
    """Plane-0 overlay for the drop: banded sun above the horizon and
    the converging grid verticals below (rows 16..186, 44 bytes/row)."""
    H0, H1 = 16, 187
    plane = bytearray(PLANE_W * (H1 - H0))

    def dot(x, y):
        if 0 <= x < 320 and H0 <= y < H1:
            plane[(y - H0) * PLANE_W + (x >> 3)] |= 0x80 >> (x & 7)

    # sun: upper disc, gap bands widening toward the horizon
    for y in range(60, 104):
        dy = y - 102
        if y > 84 and y % 6 in (4, 5):
            continue
        w = 42 * 42 - dy * dy
        if w <= 0:
            continue
        w = int(math.sqrt(w))
        for x in range(160 - w, 160 + w):
            dot(x, y)
    # horizon line
    for x in range(0, 320):
        dot(x, 104)
        dot(x, 105)
    # converging verticals from the vanishing point
    for k in range(-5, 6):
        xb = 160 + k * 58
        for y in range(108, H1):
            t = (y - 107) / (198 - 107)
            x = round(160 + (xb - 160) * t * 2.2)
            dot(x, y)
            dot(x + 1, y)
    return bytes(plane)


def sun_c01():
    """The drop/finale COLOR01 per-2-line palette: sun gradient above
    the horizon, cyan-to-pink grid verticals below (85 slots)."""
    out = []
    for j in range(85):
        line = 16 + j * 2
        if line < 58:
            out.append(0x334)
        elif line < 105:
            t = (line - 58) / 47
            out.append(rgb(15, 14 - 8 * t, 3 - 3 * t))
        else:
            t = (line - 105) / 80
            out.append(rgb(3 + 11 * t, 11 - 6 * t, 13 - 4 * t))
    return out


def circle64():
    """Four 64x64 frames of the web-style magic circle: two rings and
    counter-rotating tick marks (1 bitplane, 8 bytes/row)."""
    frames = []
    for ph in range(4):
        rows = []
        for y in range(64):
            wbits = 0
            for x in range(64):
                dx, dy = x - 31.5, y - 31.5
                d = math.hypot(dx, dy)
                on = 30.0 <= d <= 31.6 or 23.6 <= d <= 24.8
                ang = math.atan2(dy, dx)
                if 26 <= d <= 30 and int((ang / (2 * math.pi) + ph / 96 + 2)
                                         * 24) % 2 == 0:
                    on = True
                if 17 <= d <= 23 and int((ang / (2 * math.pi) - ph / 48 + 2)
                                         * 12) % 2 == 0:
                    on = True
                if 10.6 <= d <= 12.0:          # small inner ring
                    on = True
                if on:
                    wbits |= 1 << (63 - x)
            rows.append(wbits.to_bytes(8, 'big'))
        frames.append(b''.join(rows))
    return frames


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
    with open(os.path.join(HERE, 'dropovl.raw'), 'wb') as f:
        f.write(build_drop_overlay())

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

        for hue, name in (((2, 11, 15), 'cyan'), ((15, 4, 11), 'pink'),
                          ((15, 12, 4), 'gold'), ((5, 15, 9), 'green')):
            f.write(fmt_words('bar32_' + name, bar_ramp(hue)))
        s1, s2, ppal = plasma_tables()
        f.write(fmt_bytes('plasma_s1', bytes(s1)))
        f.write(fmt_bytes('plasma_s2', bytes(s2)))
        f.write(fmt_words('plasma_pal', ppal))
        f.write(fmt_words('sunset', sunset_lines()))
        f.write(fmt_bytes('persp96', bytes(persp96())))
        f.write('\teven\n')
        f.write(fmt_words('rainbow64', rainbow64()))
        f.write(fmt_words('logo_grad', logo_gradient()))
        f.write(fmt_words('sun_c01', sun_c01()))
        f.write(fmt_bytes('sine64', bytes(s64)))
        f.write(fmt_bytes('dycp_sine', bytes(dycp)))
        f.write(fmt_bytes('rot_sine', bytes(b & 0xff for b in rot)))
        f.write(fmt_bytes('scene_of_bar', bytes(
            [0] * 4 + [1] * 16 + [2] * 14 + [3] * 17 + [4] * 10 + [5] * 3)))
        f.write('\teven\n\n')

        # scene palettes for colours 2..7 (patched at scene switch)
        f.write(fmt_words('pal_cats',   [0x112, 0x9CF, 0xF80, 0xFB6,
                                         0x9CF, 0xBEF]))
        f.write(fmt_words('pal_horses', [0x4DF, 0x9CF, 0x92E, 0xB6F,
                                         0x6BF, 0xBEF]))
        f.write(fmt_words('pal_ships',  [0x235, 0x9CF, 0x67C, 0xACE,
                                         0xBDF, 0xFFF]))   # shaded hull
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
        for i, fr in enumerate(circle64()):
            f.write(fmt_bytes(f'circle64_{i}', fr))
        f.write('\teven\n')

        # the web ship: mesh, per-face lists, path constants, LUTs
        verts, faces = ship_mesh()
        f.write(f'SHIP_NVERT = {len(verts)}\n')
        f.write(fmt_words('ship_verts',
                          [c & 0xffff for v in verts for c in v], 12))
        f.write(f'SHIP_NFACE = {len(faces)}\n')
        f.write('ship_faces:\n')
        for cls, idx in faces:
            f.write(f'\tdc.b {cls},{len(idx)},' +
                    ','.join(str(i) for i in idx) + '\n')
        f.write('\teven\n')
        for i, p in enumerate(ship_paths()):
            f.write(f'; ship {i}: steps + path constants\n')
            f.write(f'ship{i}_c: dc.w {p["s1"]},{p["s2"]},{p["s3"]},'
                    f'{p["p2"]},{p["lane"] & 0xffff},{p["amp"]},'
                    f'{p["depth"] & 0xffff}\n')
        f.write(fmt_words('scale_tab', scale_table()))
        f.write(f'SCALE_TAB_N = {len(scale_table())}\n')
        f.write(fmt_bytes('atan_tab', bytes(atan_table())))
        f.write('\teven\n')

    print(f'amiga_data.i written: copper {len(cop)} words, '
          f'bobs {total} bytes, logo.raw {len(logo)} bytes')


if __name__ == '__main__':
    main()
