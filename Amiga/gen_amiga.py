#!/usr/bin/env python3
"""
Generate the data for the Amiga 500 (OCS, PAL) version:

  amiga_data.i  - song streams for the 4-channel Paula player, instruments,
                  waveforms, the generated copper list + patch-offset tables,
                  colour animation tables, the big scroller font + text
  logo.raw      - the 320x256 one-bitplane title screen
  samples.raw   - drums + the vocal phrases as 8-bit signed PCM (chip RAM)

The arrangement is imported straight from the C64 build (../C64/gen_music.py)
so both ports play the identical 64-bar score; on the Amiga the drums get
their own channel and the vocals play as proper Paula samples on channel 3.

Run:  python3 gen_amiga.py
"""
import math
import os
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
C64 = os.path.join(HERE, '..', 'C64')
sys.path.insert(0, C64)
import gen_music as gm                    # noqa: E402  (builds the song)

PAULA = 3546895                           # PAL Paula clock
FRAMES = 64 * gm.BAR                      # 5952 frames = the whole song
VOICE_PERIOD = 444                        # vocals/drums: 7988 Hz
MIN_PERIOD = 124

# ---------------------------------------------------------------------------
#  The "Kattene" 8x8 font (own pixel work — chunky uppercase)
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
}
GLYPHS = list(FONT.keys())


def note_freq(n):
    """C64 note number (1..96, a4=58) -> Hz."""
    return 440.0 * 2 ** ((n - 58) / 12)


def period(n, loop_len):
    p = round(PAULA / (note_freq(n) * loop_len))
    assert MIN_PERIOD <= p <= 65535, (n, loop_len, p)
    return p


# ---------------------------------------------------------------------------
#  Instruments
# ---------------------------------------------------------------------------
def synth_waves():
    def clamp(a):
        return np.clip(np.round(a), -127, 127).astype(np.int8).tobytes()

    sq16 = clamp(np.where(np.arange(16) < 8, 90, -90))
    saw16 = clamp(np.linspace(-90, 90, 16))
    saw32 = clamp(np.linspace(-90, 90, 32))
    pulse32 = clamp(np.where(np.arange(32) < 8, 100, -100))
    tri32 = clamp(np.concatenate([np.linspace(-80, 80, 16),
                                  np.linspace(80, -80, 16)]))

    sr = PAULA / VOICE_PERIOD
    t = np.arange(int(sr * 0.09)) / sr
    kick = np.sin(2 * np.pi * (90 * t - 300 * t * t)) * np.exp(-t * 28) * 120
    rng = np.random.default_rng(1)
    t2 = np.arange(int(sr * 0.11)) / sr
    snare = rng.standard_normal(len(t2)) * np.exp(-t2 * 34) * 90
    t3 = np.arange(int(sr * 0.04)) / sr
    hat = np.diff(rng.standard_normal(len(t3) + 1)) * np.exp(-t3 * 70) * 70
    return {'sq16': sq16, 'saw16': saw16, 'saw32': saw32, 'pulse32': pulse32,
            'tri32': tri32, 'kick': clamp(kick), 'snare': clamp(snare),
            'hat': clamp(hat)}


# id, wave, loop_len (0 = one-shot), volume
INSTS = [
    ('lead', 'sq16', 16, 44),
    ('arp', 'saw16', 16, 26),
    ('bass', 'pulse32', 32, 50),
    ('pad', 'tri32', 32, 34),
    ('kick', 'kick', 0, 62),
    ('snare', 'snare', 0, 48),
    ('hat', 'hat', 0, 26),
    ('voc_kattene', 'voc0', 0, 64),
    ('voc_oohh', 'voc1', 0, 60),
    ('voc_hestene', 'voc2', 0, 64),
    ('voc_fantastisk', 'voc3', 0, 64),
]
INST_ID = {n: i for i, (n, *_entries) in enumerate(INSTS)}

ARPS = {gm.ARPM: [0, 3, 7, 12], gm.ARPJ: [0, 4, 7, 12], gm.ARP7: [0, 4, 7, 10]}


# ---------------------------------------------------------------------------
#  Song translation: C64 Voice events -> Amiga channel streams
# ---------------------------------------------------------------------------
def stream_bass():
    out = bytearray()
    for e in gm.v3.ev:
        if e[0] == 'inst':
            continue
        if e[0] == 'rest':
            out += bytes([0, min(255, e[1])])
        elif e[0] == 'tie':
            out += bytes([2, min(255, e[1])])
        else:
            out += bytes([1, INST_ID['bass'], e[2]]) + \
                period(e[1], 32).to_bytes(2, 'big')
    out.append(0xFF)
    return bytes(out)


def stream_arps():
    out = bytearray()
    cur = gm.ARPM
    for e in gm.v2.ev:
        if e[0] == 'inst':
            cur = e[1]
        elif e[0] == 'rest':
            out += bytes([0, min(255, e[1])])
        elif e[0] == 'tie':
            out += bytes([2, min(255, e[1])])
        else:
            offs = ARPS.get(cur, [0, 0, 0, 0])
            out += bytes([3, INST_ID['arp'], e[2]])
            for o in offs:
                out += period(e[1] + o, 16).to_bytes(2, 'big')
    out.append(0xFF)
    return bytes(out)


def stream_lead():
    """v1 with the C64's interleaved drum hits replaced by rests."""
    out = bytearray()
    cur = gm.LEAD
    for e in gm.v1.ev:
        if e[0] == 'inst':
            cur = e[1]
        elif e[0] == 'rest':
            out += bytes([0, min(255, e[1])])
        elif e[0] == 'tie':
            out += bytes([2, min(255, e[1])])
        else:
            if cur in (gm.KICK, gm.SNARE, gm.HAT):
                out += bytes([0, min(255, e[2])])      # drum -> rest here
            else:
                out += bytes([1, INST_ID['lead'], e[2]]) + \
                    period(e[1], 16).to_bytes(2, 'big')
    out.append(0xFF)
    return bytes(out)


def vocal_lengths(sample_bytes):
    return [int(len(b) / (PAULA / VOICE_PERIOD) * 50) + 2 for b in sample_bytes]


def stream_drums(voc_len):
    """Channel 3: a real drum track, with the vocal phrases composed in."""
    E8 = gm.E8
    hits = {}                                  # frame -> inst name
    for bar in range(64):
        base = bar * gm.BAR
        if bar in (2,):
            pat = ['hat', None, 'hat', None, 'hat', None, 'hat', None]
        elif bar == 3:
            pat = ['hat', 'hat', 'snare', 'hat',
                   'snare', 'snare', 'snare', 'snare']
        elif 4 <= bar <= 33 or 36 <= bar <= 49 or 51 <= bar <= 60:
            pat = ['kick', 'hat', 'snare', 'hat',
                   'kick', 'hat', 'snare', 'hat']
        else:
            pat = [None] * 8
        f = base
        for slot, name in zip(E8, pat):
            if name:
                hits[f] = name
            f += slot
    # vocals override the drums for their duration
    voc_cues = [(3, 73, 0), (6, 62, 1), (8, 1, 2), (16, 37, 3),
                (35, 73, 0), (38, 62, 1), (40, 1, 2), (48, 37, 3),
                (58, 0, 3)]
    vocs = {}
    for bar, fr, sid in voc_cues:
        start = bar * gm.BAR + fr
        vocs[start] = sid
        for f in list(hits):
            if start <= f < start + voc_len[sid]:
                del hits[f]
    # merge into one ordered event list
    events = sorted([(f, 'drum', n) for f, n in hits.items()] +
                    [(f, 'voc', s) for f, s in vocs.items()])
    out = bytearray()
    pos = 0

    def rest_until(f):
        nonlocal pos
        while pos < f:
            d = min(255, f - pos)
            out.extend([0, d])
            pos += d

    for f, kind, val in events:
        rest_until(f)
        if kind == 'drum':
            iid = INST_ID[val]
            dur = 8
        else:
            iid = INST_ID['voc_kattene'] + val
            dur = voc_len[val]
        # duration until the next event caps the nominal one
        out.extend([4, iid, 0])                # dur patched below
        nxt = min(255, dur)
        out[-1] = nxt
        pos += nxt
    rest_until(FRAMES)
    out.append(0xFF)
    return bytes(out)


# ---------------------------------------------------------------------------
#  Vocals from the C64 build's reference wavs
# ---------------------------------------------------------------------------
def load_vocals():
    rate = PAULA / VOICE_PERIOD
    blobs = []
    for name in ('kattene', 'oohh', 'hestene', 'fantastisk'):
        path = os.path.join(C64, 'vocals', name + '.wav')
        w = wave.open(path)
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()),
                          dtype=np.int16).astype(np.float64) / 32768.0
        pos = np.linspace(0, len(x), int(len(x) * rate / sr) + 1).astype(int)
        seg = np.array([x[a:b].mean() if b > a else 0.0
                        for a, b in zip(pos[:-1], pos[1:])])
        seg /= (np.abs(seg).max() + 1e-9)
        seg = np.sign(seg) * np.abs(seg) ** 0.8
        blobs.append(np.clip(np.round(seg * 120), -127, 127)
                     .astype(np.int8).tobytes())
    return blobs


# ---------------------------------------------------------------------------
#  Logo bitplane + big font
# ---------------------------------------------------------------------------
def render_text(plane, text, x, y, scale):
    for ch in text:
        g = FONT.get(ch, FONT[' '])
        for gy in range(8):
            for gx in range(8):
                if not (g[gy] >> (7 - gx)) & 1:
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        px = x + gx * scale + sx
                        py = y + gy * scale + sy
                        if 0 <= px < 320 and 0 <= py < 256:
                            plane[py * 40 + (px >> 3)] |= 0x80 >> (px & 7)
        x += 8 * scale


def build_logo():
    plane = bytearray(40 * 256)
    render_text(plane, 'KATTENE', 48, 24, 4)
    render_text(plane, 'PRESENTERER', 116, 66, 2)
    render_text(plane, 'MOTORSAG', 32, 96, 4)
    render_text(plane, 'ARKITEKT', 32, 138, 4)
    render_text(plane, 'A CLAUDE DEMOSCENE PRODUCTION', 44, 180, 1)
    return bytes(plane)


def build_bigfont():
    """Each glyph pre-scaled x4 as two 16px-wide column blocks
    (32 rows x 2 bytes per block) for the scroller feeder."""
    out = bytearray()
    for ch in GLYPHS:
        g = FONT[ch]
        for half in range(2):
            for gy in range(8):
                row = bytearray(2)
                for gx in range(4):
                    if (g[gy] >> (7 - (half * 4 + gx))) & 1:
                        row[gx >> 1] |= (0xF0 >> ((gx & 1) * 4))
                for _ in range(4):
                    out += row
    return bytes(out)


SCROLLTEXT = ('   MOTORSAG ARKITEKT - EN KATTENE PRODUKSJON 2026 - '
              'MUSIKK: KIM JENSEN - AMIGA 500 OCS VERSJON - '
              'KODE OG PIXELS: CLAUDE - PROMPTMASTER: EINAR - '
              'KATTER MED MOTORSAG, HESTER MED ARKITEKTDROEMMER, '
              'OG SELVFOELGELIG: ROMSKIP! - '
              'GREETINGS TO FAIRLIGHT, RAZOR 1911, THE BLACK LOTUS, '
              'FARBRAUSCH, SPACEBALLS, MELON DEZIGN, SCOOPEX, KEFRENS, '
              'ANDROMEDA, SANITY AND YOU!      ')


# ---------------------------------------------------------------------------
#  Copper list + colour tables
# ---------------------------------------------------------------------------
Y0 = 0x2C                                   # first display line
BAND_Y = 200                                # scroller band rows 200-231


def build_copper(logo_words):
    """Returns (words, c00_offsets, c01_offsets, scroll_offset, bpl_offset)."""
    w = []

    def emit(*vals):
        w.extend(vals)

    emit(0x008E, 0x2C81, 0x0090, 0x2CC1)     # DIWSTRT/STOP
    emit(0x0092, 0x0038, 0x0094, 0x00D0)     # DDFSTRT/STOP
    emit(0x0102, 0x0000, 0x0104, 0x0000)     # BPLCON1/2
    emit(0x0108, 0x0000, 0x010A, 0x0000)     # modulos
    bpl_off = len(w) * 2 + 2
    emit(0x00E0, 0x0000, 0x00E2, 0x0000)     # BPL1PT (patched at init)
    emit(0x0100, 0x1200)                     # 1 bitplane, colour on
    emit(0x0180, 0x0000, 0x0182, 0x0FFF)     # COLOR00/01

    events = []                              # (line, reg, val, tag)
    for i in range(64):
        events.append((Y0 + i * 4, 0x0180, 0x0000, ('c00', i)))
    for j, ly in enumerate((46, 54, 62, 70, 140, 156, 172, 188)):
        events.append((Y0 + ly, 0x0182, 0x0FFF, ('c01', j)))
    events.append((Y0 + BAND_Y, 0x0102, 0x0000, ('scr', 0)))
    events.append((Y0 + BAND_Y, 0x0182, 0x0FFF, ('c01', 8)))
    events.append((Y0 + BAND_Y + 32, 0x0102, 0x0000, ('nul', 0)))
    events.sort(key=lambda e: (e[0], e[1]))

    c00 = [0] * 64
    c01 = [0] * 9
    scr = 0
    crossed = False
    for line, reg, val, tag in events:
        if line >= 256 and not crossed:
            emit(0xFFDF, 0xFFFE)             # cross the y=256 boundary
            crossed = True
        emit(((line & 0xFF) << 8) | 0x07, 0xFFFE)
        off = len(w) * 2 + 2
        emit(reg, val)
        if tag[0] == 'c00':
            c00[tag[1]] = off
        elif tag[0] == 'c01':
            c01[tag[1]] = off
        elif tag[0] == 'scr':
            scr = off
    emit(0xFFFF, 0xFFFE)
    return w, c00, c01, scr, bpl_off


def rgb_ramps():
    """Copper bar glow ramps, 8 words each (7 used) — RGB12 this time."""
    return {
        'cyan': [0x023, 0x067, 0x0BD, 0x5FF, 0x0BD, 0x067, 0x023, 0],
        'pink': [0x304, 0x717, 0xC3C, 0xF7F, 0xC3C, 0x717, 0x304, 0],
        'gold': [0x420, 0x840, 0xC81, 0xFE6, 0xC81, 0x840, 0x420, 0],
        'green': [0x032, 0x074, 0x2C6, 0xAFC, 0x2C6, 0x074, 0x032, 0],
    }


def sky_gradient():
    """26 slots of OCS sunset (top -> horizon)."""
    g = []
    for i in range(26):
        t = i / 25
        r = int(1 + 12 * t ** 1.6)
        gg = int(0 + 3 * t ** 2)
        b = int(4 + 6 * (1 - t) * t + 4 * t)
        g.append(min(15, r) << 8 | min(15, gg) << 4 | min(15, b))
    return g


def grid_anim():
    """96 phases x 38 ground slots of accelerating horizon lines."""
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
    """96 phases x 64 slots of breathing ring colours."""
    pal = [0x000, 0x114, 0x228, 0x33C, 0x55F, 0x99F, 0xEEF, 0xFFF,
           0xEEF, 0xB6F, 0x84D, 0x62A, 0x417, 0x214, 0x102, 0x000]
    tab = []
    for t in range(96):
        row = []
        for s in range(64):
            d = abs(s - 32)
            row.append(pal[(int(44 / (d + 2.2)) + t // 2) & 15])
        tab.append(row)
    return tab


def rainbow():
    return [0x137, 0x25B, 0x4AF, 0x8DF, 0xCFF, 0x8DF, 0x4AF, 0x25B,
            0x519, 0x92D, 0xD5E, 0xFAF, 0xFFF, 0xFAF, 0xD5E, 0x92D,
            0x841, 0xC72, 0xFB3, 0xFE8, 0xFFC, 0xFE8, 0xFB3, 0xC72,
            0x152, 0x2A4, 0x6E8, 0xCFC, 0x6E8, 0x2A4, 0x137, 0x114]


def sine64():
    return [round(20.5 + 17.5 * math.sin(i * 2 * math.pi / 64))
            for i in range(64)]


# ---------------------------------------------------------------------------
#  Emit
# ---------------------------------------------------------------------------
def fmt_words(label, vals, per=8):
    lines = [label + ':']
    for i in range(0, len(vals), per):
        lines.append('\tdc.w ' + ','.join(f'${v:04x}' for v in vals[i:i + per]))
    return '\n'.join(lines) + '\n'


def fmt_bytes(label, data, per=16):
    lines = [label + ':']
    for i in range(0, len(data), per):
        lines.append('\tdc.b ' + ','.join(f'${b & 0xff:02x}'
                                          for b in data[i:i + per]))
    return '\n'.join(lines) + '\n'


def main():
    waves = synth_waves()
    vocals = load_vocals()
    for i, v in enumerate(vocals):
        waves[f'voc{i}'] = v
    voc_len = vocal_lengths(vocals)

    ch = [stream_bass(), stream_arps(), stream_lead(), stream_drums(voc_len)]
    logo = build_logo()
    cop, c00, c01, scr_off, bpl_off = build_copper(len(logo) // 2)

    # samples.raw = all waves/samples concatenated, word-aligned
    blob = bytearray()
    offs = {}
    for name, data in waves.items():
        if len(blob) & 1:
            blob.append(0)
        offs[name] = len(blob)
        blob += data
    with open(os.path.join(HERE, 'samples.raw'), 'wb') as f:
        f.write(bytes(blob))
    with open(os.path.join(HERE, 'logo.raw'), 'wb') as f:
        f.write(logo)

    with open(os.path.join(HERE, 'amiga_data.i'), 'w') as f:
        f.write('; --- Auto-generated by gen_amiga.py — DO NOT EDIT ---\n')
        f.write(f'; song: 64 bars x {gm.BAR} frames, 4-channel Paula\n\n')
        f.write(f'NUM_INSTS = {len(INSTS)}\n')
        f.write(f'VOICE_PERIOD = {VOICE_PERIOD}\n\n')

        for i, s in enumerate(ch):
            f.write(fmt_bytes(f'stream{i}', s))
            f.write('\teven\n')
        f.write('\n; instrument table: ptr.l, len_words.w, period.w, '
                'vol.w, oneshot.w\n')
        f.write('insts:\n')
        for name, wav, loop, vol in INSTS:
            data = waves[wav]
            lw = len(data) // 2
            per = 0 if loop else VOICE_PERIOD
            oneshot = 0 if loop else 1
            f.write(f'\tdc.l samples+{offs[wav]}\n')
            f.write(f'\tdc.w {lw},{per},{vol},{oneshot}\t; {name}\n')

        f.write('\n' + fmt_words('coplist', cop))
        f.write('\teven\n')
        f.write(fmt_words('copoff_c00', c00))
        f.write(fmt_words('copoff_c01', c01))
        f.write(f'COPOFF_SCR = {scr_off}\n')
        f.write(f'COPOFF_BPL = {bpl_off}\n\n')

        ramps = rgb_ramps()
        f.write(fmt_words('ramp_cyan', ramps['cyan']))
        f.write(fmt_words('ramp_pink', ramps['pink']))
        f.write(fmt_words('ramp_gold', ramps['gold']))
        f.write(fmt_words('ramp_green', ramps['green']))
        f.write(fmt_words('sky_grad', sky_gradient()))
        f.write(fmt_words('grid_anim', [v for r in grid_anim() for v in r], 19))
        f.write(fmt_words('tunnel_anim',
                          [v for r in tunnel_anim() for v in r], 16))
        f.write(fmt_words('rainbow32', rainbow()))
        f.write(fmt_bytes('sine64', bytes(sine64())))
        f.write(fmt_bytes('scene_of_bar', bytes(
            [0] * 4 + [1] * 16 + [2] * 14 + [3] * 17 + [4] * 10 + [5] * 3)))
        f.write('\teven\n')

        f.write(fmt_bytes('bigfont', build_bigfont()))
        f.write('\teven\n')
        text_ids = bytes(GLYPHS.index(c) for c in SCROLLTEXT) + b'\xff'
        f.write(fmt_bytes('scrolltext', text_ids))
        f.write('\teven\n')

    sizes = ', '.join(f'ch{i}={len(s)}B' for i, s in enumerate(ch))
    print(f'amiga_data.i written: {sizes}')
    print(f'samples.raw: {len(blob)} bytes chip, logo.raw: {len(logo)} bytes')
    print(f'copper: {len(cop)} words')


if __name__ == '__main__':
    main()
