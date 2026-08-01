#!/usr/bin/env python3
"""
Generate the graphics/data includes for the C64 demo:

  gfx_sprites.inc  - hardware sprites at $2000 (multicolor cast + hires extras)
  gfx_chars.inc    - custom charset half at $3400 (chars 128-255)
  gfx_tables.inc   - big data tables at $3800 (drop screen, tunnel map,
                     grid animation, stars, sine tables)

Also renders preview PNGs (via ffmpeg) into ./preview/ so the art can be
checked without an emulator.

Char map (chars 0-127 are copied from the ROM font at runtime):
  128-175  big-font pool (48 chars, expanded from ROM glyphs at runtime)
  176-179  star chars
  182      full block (tunnel)
  190-255  drop-scene chars (sun, skyline, grid diagonals) - deduped
"""
import math
import os
import struct
import subprocess

OUT = os.path.dirname(os.path.abspath(__file__))
PREVIEW = os.path.join(OUT, 'preview')
os.makedirs(PREVIEW, exist_ok=True)

# C64 (Pepto-ish) palette for previews
PAL = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x6F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]

BLACK, WHITE, RED, CYAN = 0, 1, 2, 3
PURPLE, GREEN, BLUE, YELLOW = 4, 5, 6, 7
ORANGE, BROWN, PINK, DGREY = 8, 9, 10, 11
MGREY, LGREEN, LBLUE, LGREY = 12, 13, 14, 15

# ---------------------------------------------------------------------------
#  tiny PPM->PNG preview writer
# ---------------------------------------------------------------------------
def save_png(name, pixels, w, h, scale=3):
    ppm = os.path.join(PREVIEW, name + '.ppm')
    with open(ppm, 'wb') as f:
        f.write(b'P6\n%d %d\n255\n' % (w * scale, h * scale))
        for y in range(h):
            row = bytearray()
            for x in range(w):
                r, g, b = pixels[y * w + x]
                row += bytes((r, g, b)) * scale
            f.write(bytes(row) * scale)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', ppm,
                    os.path.join(PREVIEW, name + '.png')], check=True)
    os.remove(ppm)

# ===========================================================================
#  SPRITES
# ===========================================================================
# Multicolor sprites: 12x21 wide pixels.  Legend:
#   '.' transparent   'K' black ($d025)   'C' light blue ($d026)
#   'I' the sprite's individual colour ($d027+n)
MC_BITS = {'.': 0b00, 'K': 0b01, 'I': 0b10, 'C': 0b11}

def mc_sprite(rows):
    assert len(rows) == 21, len(rows)
    data = bytearray()
    for r in rows:
        assert len(r) == 12, r
        bits = 0
        for ch in r:
            bits = (bits << 2) | MC_BITS[ch]
        data += struct.pack('>I', bits)[1:]        # 24 bits -> 3 bytes
    data.append(0)                                  # pad to 64
    return bytes(data)

def hires_sprite(rows):
    assert len(rows) == 21
    data = bytearray()
    for r in rows:
        assert len(r) == 24, r
        bits = int(''.join('1' if ch != '.' else '0' for ch in r), 2)
        data += struct.pack('>I', bits)[1:]
    data.append(0)
    return bytes(data)

# --- chainsaw cat: black body w/ neon rim, orange saw, 4 animation ---
# --- frames (teeth run along the blade, motor shakes, sparks fly)   ---
CAT_BODY = [
    '..K......K..',
    '..KK....KK..',
    '..KKKKKKKK..',
    '.CKKKKKKKKC.',
    '.CKCKKKKCKC.',
    '.CKKKKKKKKC.',
    '..KKKIKKKK..',
    '...KKKKKK...',
    '..KKKKKKK...',
    '.CKKKKKKKC..',
    'CKKKKKKKKKC.',
    'CKKKKKKKKKC.',
    'K.KKKKKKKK..',
    'K..KKKKKK...',
]

def cat_frame(phase):
    """Compose body + walking legs + an animated chainsaw (4 phases)."""
    rows = [list(r) for r in CAT_BODY]
    # legs alternate stance
    legs = list('...KK..KK...') if phase % 2 == 0 else list('..KK....KK..')
    rows.append(legs)
    # neon rim: outline the black body so the cat reads on a dark background
    for y in range(len(rows)):
        for x in range(12):
            if rows[y][x] != '.':
                continue
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < len(rows) and 0 <= xx < 12 and rows[yy][xx] == 'K':
                    rows[y][x] = 'C'
                    break
    # saw block, shaking horizontally with the motor
    shake = phase % 2
    saw = [list('............') for _ in range(6)]
    mx = 1 + shake
    for c in range(mx, mx + 3):
        saw[0][c] = 'I'                            # motor top
    for c in range(mx, mx + 4):
        saw[1][c] = 'I'                            # motor body
        saw[2][c] = 'I'
    saw[1][mx + 1] = 'K'                           # pull-cord detail
    for c in range(5, 12):                         # blade
        saw[1][c] = 'C'
        saw[2][c] = 'C'
    for k in range(4):                             # teeth race along the bar
        t = 5 + (k * 2 + phase) % 7
        saw[0][t] = 'K'
        saw[3][t] = 'K'
    if phase == 1:                                 # sparks off the tip
        saw[0][11] = 'C'
    if phase == 3:
        saw[3][11] = 'I'
    rows += saw[:6]
    rows = [''.join(r) for r in rows]
    return (rows + ['............'] * 21)[:21]

# --- architect horse (purple body, light-blue mane, blueprint tube) ---
HORSE_A = [
    '.........KK.',
    '........KIIK',
    '......CCKIII',
    '......CIIIK.',
    '.....CIIII..',
    '.CCC.CIII...',
    '.CCCCIIII...',
    '.IIIIIIII...',
    'IIIIIIIIII..',
    'IIIIIIIIII..',
    'IIIIIIIIII..',
    '.IIIIIIII...',
    '..II...II...',
    '..II...II...',
    '..II...II...',
    '..KK...KK...',
    '............',
    '............',
    '............',
    '............',
    '............',
]
HORSE_B = [
    '.........KK.',
    '........KIIK',
    '......CCKIII',
    '......CIIIK.',
    '.....CIIII..',
    '.CCC.CIII...',
    '.CCCCIIII...',
    '.IIIIIIII...',
    'IIIIIIIIII..',
    'IIIIIIIIII..',
    'IIIIIIIIII..',
    '.IIIIIIII...',
    '.II.....II..',
    '.II.....II..',
    '..II...II...',
    '..KK...KK...',
    '............',
    '............',
    '............',
    '............',
    '............',
]

# --- spaceship: sleek delta shuttle, nose right — grey hull, light-blue
# --- canopy / ion drive; 4 frames of pulsing engine flare like the    ---
# --- browser demo's flickering exhaust                                ---
SHIP_HULL = [
    '............',
    '............',
    '............',
    '....K.......',
    '....KK......',
    '....KIK.....',
    '....KIIK....',
    '....KIIK....',
    '.....KIIKKK.',
    '...KKIICCIK.',
    '..KIIIICCIIK',
    '..KIIIIIIIII',
    '.KIIIIIIIIIK',
    '..KIIIIIIIK.',
    '...KICCCIK..',
    '....KIIK....',
    '...KIIK.....',
    '...KIK......',
    '...KK.......',
    '...K........',
    '............',
]

def ship_frame(phase):
    """Hull + a pulsing ion flare streaming left from the engine."""
    rows = [list(r) for r in SHIP_HULL]
    flare = [1, 2, 3, 2][phase]
    for k in range(flare):                         # centre exhaust row
        rows[12][1 - k if 1 - k >= 0 else 0] = 'C'
        if k == 0:
            rows[11][1] = 'C'
            rows[13][1] = 'C'
    if flare >= 2:
        rows[11][0] = 'C'
        rows[13][0] = 'C'
    if flare == 3:
        rows[12][0] = 'C'
        rows[10][1] = 'C'
    return [''.join(r) for r in rows]

# --- glowing ball (hires circle w/ highlight) + dancers (hires silhouettes)
def ball_rows(radius=9, cx=11.5, cy=10):
    rows = []
    for y in range(21):
        row = ''
        for x in range(24):
            d = math.hypot((x - cx) * 0.98, y - cy)
            on = d <= radius and not (math.hypot(x - cx + 3, y - cy + 3) < 2.2)
            row += 'X' if on else '.'
        rows.append(row)
    return rows

DANCER_A = [
    '.....XX.................',
    '....XXXX................',
    '....XXXX................',
    'X....XX....X............',
    'XX..XXXX..XX............',
    '.XX.XXXX.XX.............',
    '..XXXXXXXX..............',
    '...XXXXXX...............',
    '....XXXX................',
    '....XXXX................',
    '....XXXX................',
    '...XXXXXX...............',
    '...XX..XX...............',
    '...XX..XX...............',
    '..XX....XX..............',
    '..XX....XX..............',
    '.XX......XX.............',
    '.XX......XX.............',
    'XXX......XXX............',
    '........................',
    '............................'[:24],
]
DANCER_B = [
    '........XX..............',
    '.......XXXX.............',
    '.......XXXX.............',
    '.......XXX..............',
    '..XXXXXXXXXXXXX.........',
    '.XX...XXXX....XX........',
    'XX....XXXX.....XX.......',
    '......XXXX..............',
    '......XXXX..............',
    '.....XXXXXX.............',
    '.....XXXXXX.............',
    '....XXX..XXX............',
    '....XX....XX............',
    '...XXX....XXX...........',
    '...XX......XX...........',
    '..XXX......XXX..........',
    '..XX........XX..........',
    '..XX........XX..........',
    '.XXX........XXX.........',
    '............................'[:24],
    '............................'[:24],
]

# --- "architect" magic circle: rune ring w/ rotating tick marks (2 frames,
# --- shown x+y expanded on screen so it reads big and translucent-ish) ---
def circle_rows(phase):
    rows = [['.'] * 24 for _ in range(21)]
    cx, cy = 11.5, 10.0
    for y in range(21):
        for x in range(24):
            d = math.hypot((x - cx) * 0.95, y - cy)
            if 8.0 <= d <= 9.3:                      # outer ring
                rows[y][x] = 'X'
            elif 4.6 <= d <= 5.4 and (x + y) % 2 == 0:   # dashed inner ring
                rows[y][x] = 'X'
    for k in range(8):                               # rotating tick marks
        a = (k / 8 + phase / 16) * 2 * math.pi
        for rr in (6.4, 7.0):
            x = int(round(cx + math.cos(a) * rr * 1.05))
            y = int(round(cy + math.sin(a) * rr))
            if 0 <= x < 24 and 0 <= y < 21:
                rows[y][x] = 'X'
    return [''.join(r) for r in rows]

SPRITE_DEFS = [
    # (name, rows, multicolor, individual colour for the preview)
    ('spr_ship_a', ship_frame(0), True, LGREY),
    ('spr_ship_b', ship_frame(1), True, LGREY),
    ('spr_ship_c', ship_frame(2), True, LGREY),
    ('spr_ship_d', ship_frame(3), True, LGREY),
    ('spr_cat_a', cat_frame(0), True, ORANGE),
    ('spr_cat_b', cat_frame(1), True, ORANGE),
    ('spr_cat_c', cat_frame(2), True, ORANGE),
    ('spr_cat_d', cat_frame(3), True, ORANGE),
    ('spr_horse_a', HORSE_A, True, PURPLE),
    ('spr_horse_b', HORSE_B, True, PURPLE),
    ('spr_ball_a', ball_rows(), False, LGREEN),
    ('spr_ball_b', ball_rows(cx=12.5, cy=11), False, LGREEN),
    ('spr_dancer_a', DANCER_A, False, BLACK),
    ('spr_dancer_b', DANCER_B, False, BLACK),
    ('spr_circle_a', circle_rows(0), False, CYAN),
    ('spr_circle_b', circle_rows(1), False, CYAN),
]
SPRITES = [(name, mc_sprite(rows) if mc else hires_sprite(rows))
           for name, rows, mc, _ in SPRITE_DEFS]

def preview_sprites():
    """Render all sprites side by side (MC pixels doubled horizontally)."""
    w, h = len(SPRITE_DEFS) * 28, 24
    px = [PAL[BLUE]] * (w * h)
    for si, (name, rows, mc, indiv) in enumerate(SPRITE_DEFS):
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch == '.':
                    continue
                col = {'K': BLACK, 'C': LBLUE, 'I': indiv, 'X': indiv}[ch]
                if mc:
                    for dx in (0, 1):
                        px[(y + 1) * w + si * 28 + x * 2 + dx + 1] = PAL[col]
                else:
                    px[(y + 1) * w + si * 28 + x + 1] = PAL[col]
    save_png('sprites', px, w, h, scale=6)

# ===========================================================================
#  CUSTOM CHARS + DROP SCREEN
# ===========================================================================
STAR_CHARS = [
    bytes([0, 0, 0, 0x08, 0, 0, 0, 0]),                       # 176 tiny dot
    bytes([0, 0, 0x18, 0x18, 0, 0, 0, 0]),                    # 177 dot
    bytes([0x08, 0x08, 0x2A, 0x1C, 0x2A, 0x08, 0x08, 0]),     # 178 plus-star
    bytes([0, 0x10, 0x38, 0x7C, 0x38, 0x10, 0, 0]),           # 179 diamond
]
FULL_BLOCK = bytes([0xFF] * 8)                                 # 182

HORIZON_Y = 104
SUN_CX, SUN_CY, SUN_R = 160, 100, 42
VP = (160, 107)

def build_drop_layers():
    """Layer masks (sun / skyline / grid) for the outrun scene.

    Everything is quantised so that cells repeat: sun gap-bands on the 8px
    char grid, buildings snapped to whole cells with an 8px window pattern,
    grid diagonals rasterised from a small library of quantised slopes.
    """
    sun = [[0] * 320 for _ in range(200)]
    sky = [[0] * 320 for _ in range(200)]
    grid = [[0] * 320 for _ in range(200)]

    # ---- sun: stepped dome (per-row span snapped to 4px) with gap bands ----
    for y in range(SUN_CY - SUN_R, HORIZON_Y):
        dy = (y - SUN_CY) * 1.05
        if abs(dy) > SUN_R:
            continue
        if y > SUN_CY - 14 and y % 8 in (5, 6):
            continue                               # gap bands on the char grid
        w = int(math.sqrt(SUN_R * SUN_R - dy * dy) / 4) * 4
        for x in range(SUN_CX - w, SUN_CX + w):
            sun[y][x] = 1

    # ---- skyline silhouette (cell-snapped, shared window pattern) ----
    #      (x0 cells, width cells, height px multiple of 4)
    bldgs = [(0, 3, 8), (3, 2, 16), (5, 2, 4), (7, 3, 12), (10, 2, 8),
             (12, 2, 20), (14, 3, 12), (17, 2, 8), (19, 2, 16), (21, 3, 12),
             (24, 2, 4), (26, 2, 16), (28, 3, 8), (31, 2, 12), (33, 2, 20),
             (35, 3, 8), (38, 2, 12)]
    for c0, cw, bh in bldgs:
        for y in range(HORIZON_Y - bh, HORIZON_Y):
            for x in range(c0 * 8, min(320, (c0 + cw) * 8)):
                # window holes on the char grid (pink sky glows through)
                if (x % 8) in (2, 3) and (y % 8) in (3, 4) and (HORIZON_Y - y) > 5:
                    continue
                sky[y][x] = 1

    # ---- perspective grid diagonals: quantised slope library ----
    for k in range(-4, 5):
        xb = VP[0] + k * 76
        x = float(VP[0] + (xb - VP[0]) * (112 - VP[1]) / (199 - VP[1]))
        for r in range(14, 25):                    # start one row below horizon
            y0, y1 = r * 8, r * 8 + 8
            x1 = VP[0] + (xb - VP[0]) * (y1 - VP[1]) / (199 - VP[1])
            xin = round(x / 8) * 8                 # snap entry to the cell grid
            dx = round((x1 - x) / 8) * 8           # snap slope to 8px/8rows
            for yy in range(8):
                xx = xin + round(dx * yy / 8)
                for d in (0, 1):
                    if 0 <= xx + d < 320:
                        grid[y0 + yy][xx + d] = 1
            x = xin + dx
    return sun, sky, grid

def cell_has(mask, r, c):
    return any(mask[r * 8 + yy][c * 8 + xx] for yy in range(8) for xx in range(8))

def build_drop_screen():
    sun, sky, grid = build_drop_layers()
    pix = [[sun[y][x] | sky[y][x] | grid[y][x] for x in range(320)]
           for y in range(200)]

    chars = {}                                     # bitmap -> char code
    order = []
    screen = [[32] * 40 for _ in range(25)]        # space
    color = [[BLUE] * 40 for _ in range(25)]

    for r in range(25):
        for c in range(40):
            cell = bytes(
                int(''.join(str(pix[r * 8 + yy][c * 8 + xx]) for xx in range(8)), 2)
                for yy in range(8))
            if cell == bytes(8):
                continue
            if cell not in chars:
                chars[cell] = 190 + len(order)
                order.append(cell)
            screen[r][c] = chars[cell]
            # colour priority: skyline silhouette > sun glow > grid gradient
            if cell_has(sky, r, c):
                color[r][c] = BLACK
            elif cell_has(sun, r, c):
                color[r][c] = YELLOW if r <= 9 else (ORANGE if r <= 10 else PINK)
            else:
                d = abs(c - 19.5)
                color[r][c] = CYAN if d < 8 else (LBLUE if d < 14 else PINK)

    assert 190 + len(order) <= 256, f'too many drop chars: {len(order)}'

    star_cells = [(0, 3), (1, 11), (0, 24), (1, 33), (2, 6), (2, 19), (2, 37),
                  (3, 14), (3, 28), (4, 2), (4, 22), (4, 35), (5, 9), (5, 30),
                  (1, 17), (3, 5), (5, 38), (0, 30)]
    for i, (r, c) in enumerate(star_cells):
        if screen[r][c] == 32:
            screen[r][c] = 176 + (i & 3)
            color[r][c] = (WHITE, LGREY, DGREY, MGREY)[i & 3]

    return screen, color, order, star_cells

# ===========================================================================
#  TUNNEL RING MAP
# ===========================================================================
def build_tunnel():
    """Ring index 0-15 per cell; rings get denser toward the centre."""
    m = []
    for r in range(25):
        row = []
        for c in range(40):
            d = math.hypot(c - 19.5, (r - 12.5) * 1.35)
            row.append(int(44.0 / (d + 1.0)) & 15)
        m.append(row)
    return m

# ===========================================================================
#  GRID LINE ANIMATION  (22 ground splits of 4 raster lines x 96 phases)
# ===========================================================================
def build_grid_anim():
    NPHASE, NSPLIT, NLINES = 96, 22, 6
    tab = []
    for t in range(NPHASE):
        row = [0x00] * NSPLIT
        row[0] = PURPLE                            # horizon haze
        for k in range(NLINES):
            z = ((k * (NPHASE // NLINES) + t) % NPHASE) / NPHASE
            s = int(1 + 20.99 * (z ** 2.4))
            col = PINK if s >= 15 else (PURPLE if s >= 8 else BLUE)
            if s < NSPLIT:
                row[s] = max(row[s], col, key=lambda v: (v == PINK, v == PURPLE, v))
        tab.append(row)
    return tab

# ===========================================================================
#  MISC TABLES
# ===========================================================================
def sine_ctr():
    """Copper-bar centre position (split index 5..40) from a sine."""
    return [round(22.5 + 17.5 * math.sin(i * 2 * math.pi / 256)) for i in range(256)]

# stars for the runtime-built scenes (intro / verse / outro)
RUNTIME_STARS = [
    (0, 5, 176, WHITE), (0, 21, 177, LGREY), (0, 35, 176, DGREY),
    (1, 12, 178, WHITE), (1, 29, 176, MGREY), (2, 2, 177, LGREY),
    (2, 17, 176, DGREY), (2, 38, 178, WHITE), (4, 8, 176, LGREY),
    (4, 25, 179, WHITE), (5, 1, 176, MGREY), (5, 33, 177, LGREY),
    (11, 6, 176, DGREY), (11, 36, 176, LGREY), (12, 15, 177, MGREY),
    (13, 27, 176, DGREY), (14, 3, 178, LGREY), (15, 20, 176, MGREY),
    (16, 31, 177, DGREY), (18, 8, 176, LGREY), (18, 38, 176, MGREY),
    (20, 14, 179, LGREY), (20, 27, 176, DGREY), (21, 2, 177, MGREY),
    (22, 21, 176, LGREY), (23, 33, 176, DGREY), (6, 15, 176, LGREY),
    (7, 37, 176, MGREY),
]

def sky_gradient():
    """26 static sky splits (4 raster lines each) for the drop scene."""
    return [BLACK] * 5 + [BLUE] * 6 + [PURPLE] * 9 + [PINK] * 6

def rainbow32():
    """glow ramps for the finale sky cycling."""
    return [BLUE, LBLUE, CYAN, WHITE, CYAN, LBLUE, BLUE, BLACK,
            PURPLE, PINK, LGREY, WHITE, LGREY, PINK, PURPLE, BLACK,
            BROWN, ORANGE, YELLOW, WHITE, YELLOW, ORANGE, BROWN, BLACK,
            GREEN, LGREEN, WHITE, LGREEN, GREEN, BLACK, BLUE, PURPLE]

# ===========================================================================
#  PREVIEWS
# ===========================================================================
def render_screen_preview(name, screen, color, charset, bg_per_row):
    """Compose a 320x200 preview from screen codes + colour + bg colours."""
    px = [PAL[BLACK]] * (320 * 200)
    for r in range(25):
        for c in range(40):
            code = screen[r][c]
            glyph = charset.get(code)
            fg = PAL[color[r][c] & 15]
            bg = PAL[bg_per_row(r * 8) & 15]
            for yy in range(8):
                bits = 0 if glyph is None else glyph[yy]
                for xx in range(8):
                    on = (bits >> (7 - xx)) & 1
                    px[(r * 8 + yy) * 320 + c * 8 + xx] = fg if on else bg
    save_png(name, px, 320, 200, scale=2)

def preview_drop(screen, color, order):
    charset = {190 + i: b for i, b in enumerate(order)}
    for i, b in enumerate(STAR_CHARS):
        charset[176 + i] = b
    sky = sky_gradient()
    ganim = build_grid_anim()[20]

    def bg(y):
        if y < HORIZON_Y:
            return sky[min(25, y // 4)]
        gs = (y - HORIZON_Y) // 4
        return ganim[gs] if 0 <= gs < 22 else 0
    render_screen_preview('drop_screen', screen, color, charset, bg)

def preview_tunnel(tmap):
    ringpal = [BLACK, BLUE, PURPLE, PINK, LGREY, WHITE, CYAN, LBLUE,
               BLUE, BLACK, PURPLE, PINK, WHITE, LBLUE, CYAN, BLUE]
    screen = [[182] * 40 for _ in range(25)]
    color = [[ringpal[tmap[r][c]] for c in range(40)] for r in range(25)]
    render_screen_preview('tunnel', screen, color, {182: FULL_BLOCK}, lambda y: 0)

# ===========================================================================
#  EMIT
# ===========================================================================
def fmt(label, data, per=16):
    lines = [label]
    for i in range(0, len(data), per):
        lines.append('        !byte ' + ','.join(f'${b:02x}' for b in data[i:i + per]))
    return '\n'.join(lines) + '\n'

def main():
    screen, color, order, _ = build_drop_screen()
    tmap = build_tunnel()
    ganim = build_grid_anim()

    # ---- sprites at $2000 ----
    with open(os.path.join(OUT, 'gfx_sprites.inc'), 'w') as f:
        f.write('; --- Auto-generated by gen_assets.py --- sprites ($2000) ---\n')
        f.write('        * = $2000\n')
        for name, data in SPRITES:
            f.write(fmt(name + ':', data))
        f.write('\n; sprite pointer values (addr/64)\n')
        for name, _ in SPRITES:
            f.write(f'SP_{name[4:].upper()} = ({name} & $3fff) / 64\n')

    # ---- custom chars at $3400 (chars 128-255 of the $3000 charset) ----
    with open(os.path.join(OUT, 'gfx_chars.inc'), 'w') as f:
        f.write('; --- Auto-generated by gen_assets.py --- charset $3400+ ---\n')
        f.write('        * = $3400\n')
        f.write('        !fill 48*8, 0            ; 128-175 big-font pool\n')
        f.write(fmt('star_chars:  ; chars 176-179', b''.join(STAR_CHARS)))
        f.write('        !fill 2*8, 0             ; 180-181 spare\n')
        f.write(fmt('char_block:  ; char 182', FULL_BLOCK))
        f.write('        !fill 7*8, 0             ; 183-189 spare\n')
        f.write(fmt('drop_chars:  ; chars 190+', b''.join(order)))
        f.write(f'\n; {len(order)} drop chars used (190-{189 + len(order)})\n')

    # ---- big tables at $3800 ----
    with open(os.path.join(OUT, 'gfx_tables.inc'), 'w') as f:
        f.write('; --- Auto-generated by gen_assets.py --- data tables ($3800) ---\n')
        f.write('        * = $3800\n')
        f.write(fmt('drop_screen:', bytes(b for row in screen for b in row), 20))
        f.write(fmt('drop_color:', bytes(b for row in color for b in row), 20))
        f.write(fmt('tunnel_map:', bytes(b for row in tmap for b in row), 20))
        f.write(fmt('grid_anim:  ; 96 phases x 22 ground splits',
                    bytes(b for row in ganim for b in row), 22))
        f.write(fmt('sky_grad:   ; 26 sky splits', bytes(sky_gradient())))
        f.write(fmt('rainbow32:', bytes(rainbow32())))
        f.write(fmt('sine_ctr:   ; copper bar centre 5..40', bytes(sine_ctr())))
        stars = bytes(b for s in RUNTIME_STARS for b in s)
        f.write(f'NUM_STARS = {len(RUNTIME_STARS)}\n')
        f.write(fmt('star_table: ; row,col,char,colour', stars, 16))

    preview_sprites()
    preview_drop(screen, color, order)
    preview_tunnel(tmap)
    print(f'ok: {len(order)} drop chars, sprites={len(SPRITES)}, previews in preview/')

if __name__ == '__main__':
    main()
