#!/usr/bin/env python3
"""
Build motorsag.mod — the song as a standalone ProTracker module.

Instruments come from the classic ST-01 sample pack (point ST_DIR at it),
the vocals from the project's separated stems (../C64/vocals). The
arrangement is imported from ../C64/gen_music.py, so the MOD plays the same
64 bars as both demo ports: 16 rows per bar at speed 6 (125 BPM), 16
patterns of 4 bars, channels = bass / arps / lead / drums+vocals.

Tracker niceties: chords use the 0xy arpeggio effect, all periods are
snapped to the ProTracker tuning table (so 0xy works in real trackers),
sustained instruments get synthesized loop points, and the backing ducks
(Cxx) while a vocal phrase sings.

Run:  python3 gen_mod.py ["/path/to/ST-xx Sample Packs"]
"""
import math
import os
import sys
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
C64 = os.path.join(HERE, '..', 'C64')
sys.path.insert(0, C64)
import gen_music as gm                    # noqa: E402

ST_DIR = sys.argv[1] if len(sys.argv) > 1 else \
    '/Users/einari/Library/Mobile Documents/com~apple~CloudDocs/Amiga/' \
    'ST-xx Sample Packs'

PAULA = 3546895
ROWS_PER_BAR = 16
E8_CUM = [0, 12, 23, 35, 47, 59, 70, 82]      # 8th-slot frame offsets in a bar

# ProTracker period table, finetune 0, C-1..B-3
PT_PERIODS = [856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
              428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
              214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113]


def note_semi(n):
    """C64 note number -> absolute semitone (a4=58 -> 57 in 0-based C0)."""
    return n - 1


def load_wav(path):
    w = wave.open(path)
    sr, n, ch, sw = (w.getframerate(), w.getnframes(),
                     w.getnchannels(), w.getsampwidth())
    raw = w.readframes(n)
    if sw == 2:
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768
    else:
        x = (np.frombuffer(raw, dtype=np.uint8).astype(np.float64) - 128) / 128
    if ch == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    return x, sr


def fundamental(x, sr):
    seg = x[:min(len(x), sr)] - x[:min(len(x), sr)].mean()
    p = np.abs(np.fft.rfft(seg, 2 * len(seg))) ** 2
    ac = np.fft.irfft(p)[:len(seg)]
    ac /= ac[0] + 1e-12
    lo, hi = int(sr / 1200), min(int(sr / 30), len(ac) - 1)
    lag = lo + int(np.argmax(ac[lo:hi]))
    if lag >= 2 * lo and ac[int(lag / 2)] > ac[lag] * 0.92:
        lag = int(lag / 2)
    return sr / lag


def resample(x, factor):
    """Decimate by `factor` (linear interpolation)."""
    n_out = int(len(x) / factor)
    idx = np.arange(n_out) * factor
    i0 = idx.astype(int)
    fr = idx - i0
    i1 = np.minimum(i0 + 1, len(x) - 1)
    return x[i0] * (1 - fr) + x[i1] * fr


def to8(x, gain=1.0):
    x = x * gain
    peak = np.abs(x).max() + 1e-9
    if peak > 1:
        x = x / peak
    return np.clip(np.round(x * 127), -127, 127).astype(np.int8)


def find_loop(x8, cycle):
    """Find a loop of ~4 cycles near the tail with minimal seam."""
    ln = max(2, int(round(4 * cycle)) & ~1)
    best, bs = None, 1e9
    lo = max(0, int(len(x8) * 0.45)) & ~1
    hi = len(x8) - ln - 2
    for s in range(lo, max(lo + 2, hi), 2):
        seam = abs(int(x8[s]) - int(x8[s + ln])) + \
            abs(int(x8[s + 1]) - int(x8[s + ln - 1]))
        if seam < bs:
            bs, best = seam, s
    if best is None:
        return 0, 1
    return best // 2, ln // 2                   # words


class Instrument:
    def __init__(self, name, data8, volume, loop=(0, 1), root_idx=None):
        self.name = name
        self.data = data8
        self.volume = volume
        self.loop = loop
        self.root_idx = root_idx                # PT table idx of its root


def make_melodic(name, fname, root_pt_idx, notes_semis, volume, loop=False):
    """Tune an ST sample so its root sits on PT index `root_pt_idx` and
    all `notes_semis` (absolute semitones, C0=0) land inside the table.

    Playing at period P outputs PAULA/P samples/sec, so a stored waveform
    with `spc` samples per cycle sounds at (PAULA/P)/spc Hz.  We decimate
    the source so that at the root's table period it plays the root's
    equal-tempered frequency exactly — then every other table entry is
    automatically the right semitone (the PT table is 2^(1/12)-spaced).
    """
    x, sr = load_wav(os.path.join(ST_DIR, 'ST-01', fname))
    f0 = fundamental(x, sr)
    root_semi = round(12 * math.log2(f0 / 440.0)) + 57   # a4 = semi 57
    s_lo, s_hi = min(notes_semis), max(notes_semis)
    span = s_hi - s_lo
    assert span <= 35, \
        f'{name}: {span} semitone range does not fit the PT table'
    # centre the note range around table index 17 (period ~320, i.e. a
    # healthy ~11 kHz playback) so no note plays at a muddy crawl
    pos = min(max(17 - span // 2, 0), 35 - span)
    f_lo = 440.0 * 2 ** ((s_lo - 57) / 12)
    want_spc = (PAULA / PT_PERIODS[pos]) / f_lo
    have_spc = sr / f0
    k = have_spc / want_spc
    data = to8(resample(x, k))
    ls, ll = find_loop(data, want_spc) if loop else (0, 1)
    inst = Instrument(name, data, volume, (ls, ll), root_idx=pos)
    inst.semi_off = s_lo - pos                  # our semitone -> PT index
    rate_lo = PAULA / PT_PERIODS[pos]
    rate_hi = PAULA / PT_PERIODS[pos + span]
    note = ' <-- SLOW' if rate_lo < 6000 else ''
    print(f'  {name:12s} {fname:16s} f0={f0:6.1f}Hz k={k:5.2f} '
          f'{len(data):5d}B rates {rate_lo/1000:.1f}-{rate_hi/1000:.1f}kHz'
          f'{note}')
    return inst


def make_oneshot(name, fname, volume, gain=1.0, folder='ST-01'):
    x, sr = load_wav(os.path.join(ST_DIR, folder, fname))
    y = resample(x, sr / (PAULA / 428.0))       # store at period-428 rate
    data = to8(y, gain)
    data[:2] = 0                                # PT convention: silent loop
    inst = Instrument(name, data, volume)
    print(f'  {name:12s} {fname:16s} {len(inst.data):5d}B (one-shot)')
    return inst


def make_vocal(name, volume):
    x, sr = load_wav(os.path.join(C64, 'vocals', name + '.wav'))
    # audibility: high-pass 120 Hz, compress, hard normalize
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    X[freqs < 120] = 0
    x = np.fft.irfft(X, len(x))
    x = x / (np.abs(x).max() + 1e-9)
    x = np.sign(x) * np.abs(x) ** 0.6
    y = resample(x, sr / (PAULA / 428.0))
    data = to8(y)
    data[:2] = 0                                # PT convention: silent loop
    inst = Instrument('v_' + name, data, volume)
    print(f'  v_{name:10s} {len(inst.data):6d}B (vocal)')
    return inst


# ---------------------------------------------------------------------------
#  Compose the patterns
# ---------------------------------------------------------------------------
class Cell:
    __slots__ = ('smp', 'per', 'fx', 'par')

    def __init__(self):
        self.smp = 0
        self.per = 0
        self.fx = 0
        self.par = 0


BASS_FLOOR = 17                 # e1: lower bass notes transpose up an octave


def bass_note(n):
    while n < BASS_FLOOR:
        n += 12
    return n


def frame_to_row(f):
    bar, off = divmod(f, gm.BAR)
    if off in E8_CUM:
        return bar * ROWS_PER_BAR + E8_CUM.index(off) * 2
    return bar * ROWS_PER_BAR + int(round(off / gm.BAR * ROWS_PER_BAR))


def walk(voice):
    """Yield (row, kind, value, inst) from a C64 Voice's event list."""
    f = 0
    cur = None
    for e in voice.ev:
        if e[0] == 'inst':
            cur = e[1]
        elif e[0] in ('rest', 'tie'):
            f += e[1]
        else:
            yield frame_to_row(f), e[1], cur
            f += e[2]


def build_patterns(insts, voc_rows):
    rows = [[Cell() for _ in range(4)] for _ in range(64 * ROWS_PER_BAR)]

    def put(ch, row, inst, pt_idx, fx=0, par=0):
        c = rows[row][ch]
        c.smp = inst
        c.per = PT_PERIODS[max(0, min(35, pt_idx))] if pt_idx >= 0 else 0
        c.fx = fx
        c.par = par

    def melodic_idx(inst, n):
        return note_semi(n) - insts[inst - 1].semi_off

    ARPFX = {gm.ARPM: 0x37, gm.ARPJ: 0x47, gm.ARP7: 0x4A}

    # ch0: bass (sub-E1 notes transpose up; intro/outro pulses play soft)
    for row, n, cur in walk(gm.v3):
        soft = 0x28 if cur == gm.PAD else 0
        put(0, row, I_BASS, melodic_idx(I_BASS, bass_note(n)),
            0xC if soft else 0, soft)
    # ch1: arps / pads
    for row, n, cur in walk(gm.v2):
        if cur in ARPFX:
            put(1, row, I_ARP, melodic_idx(I_ARP, n), 0x0, ARPFX[cur])
        else:
            put(1, row, I_PAD, melodic_idx(I_PAD, n))
    # ch2: lead (the C64 drum interjections are dropped)
    for row, n, cur in walk(gm.v1):
        if cur in (gm.KICK, gm.SNARE, gm.HAT):
            continue
        i = I_PAD if cur == gm.PAD else I_LEAD
        put(2, row, i, melodic_idx(i, n))
    # ch3: drums, then the vocals stamped over them
    for bar in range(64):
        base = bar * ROWS_PER_BAR
        if bar == 2:
            pat = {0: I_HAT, 4: I_HAT, 8: I_HAT, 12: I_HAT}
        elif bar == 3:
            pat = {0: I_HAT, 4: I_SNARE, 8: I_SNARE, 10: I_SNARE,
                   12: I_SNARE, 14: I_SNARE}
        elif 4 <= bar <= 33 or 36 <= bar <= 49 or 51 <= bar <= 60:
            pat = {0: I_KICK, 2: I_HAT, 4: I_SNARE, 6: I_HAT,
                   8: I_KICK, 10: I_HAT, 12: I_SNARE, 14: I_HAT}
        else:
            pat = {}
        for r, i in pat.items():
            put(3, base + r, i, 12)             # one-shots play at C-2 (428)
    for row, n_rows, smp in voc_rows:
        for r in range(row, min(row + n_rows, 64 * ROWS_PER_BAR)):
            rows[r][3] = Cell()                 # silence the kit under it
        put(3, row, smp, 12)
        # duck bass + lead while the vocal sings
        for r in range(row, min(row + n_rows, 64 * ROWS_PER_BAR)):
            for ch, vol in ((0, 0x20), (2, 0x1c)):
                c = rows[r][ch]
                if c.smp or r == row:
                    if c.fx == 0 and c.par == 0:
                        c.fx, c.par = 0xC, vol
    # tempo on the very first row
    rows[0][3].fx, rows[0][3].par = 0xF, 6
    return rows


def encode(rows, insts_list):
    npat = 64 * ROWS_PER_BAR // 64
    pats = b''
    for p in range(npat):
        chunk = bytearray()
        for r in range(64):
            for ch in range(4):
                c = rows[p * 64 + r][ch]
                s, per = c.smp, c.per
                chunk += bytes([(s & 0x10) | (per >> 8),
                                per & 0xFF,
                                ((s & 0x0F) << 4) | c.fx,
                                c.par])
        pats += bytes(chunk)

    hdr = bytearray()
    hdr += b'motorsag arkitekt'.ljust(20, b'\0')
    for inst in insts_list:
        data = inst.data
        lw = len(data) // 2
        ls, ll = inst.loop
        hdr += inst.name.encode()[:22].ljust(22, b'\0')
        hdr += lw.to_bytes(2, 'big')
        hdr += bytes([0, inst.volume])
        hdr += ls.to_bytes(2, 'big') + max(1, ll).to_bytes(2, 'big')
    for _ in range(31 - len(insts_list)):
        hdr += b'\0' * 22 + (0).to_bytes(2, 'big') + bytes([0, 0]) + \
            (0).to_bytes(2, 'big') + (1).to_bytes(2, 'big')
    hdr += bytes([npat, 127])
    hdr += bytes(range(npat)) + b'\0' * (128 - npat)
    hdr += b'M.K.'

    body = b''
    for inst in insts_list:
        d = inst.data.tobytes()
        if len(d) & 1:
            d += b'\0'
        body += d
    return bytes(hdr) + pats + body


# ---------------------------------------------------------------------------
def main():
    global I_BASS, I_ARP, I_LEAD, I_PAD, I_KICK, I_SNARE, I_HAT

    # collect every note each instrument must reach (absolute semitones)
    need = {'bass': [], 'arp': [], 'lead': [], 'pad': []}
    for e in gm.v3.ev:
        if e[0] == 'note':
            need['bass'].append(note_semi(bass_note(e[1])))
    cur = None
    for e in gm.v2.ev:
        if e[0] == 'inst':
            cur = e[1]
        elif e[0] == 'note':
            if cur in (gm.ARPM, gm.ARPJ, gm.ARP7):
                # the 0xy arpeggio adds at most 10 semitones (dom7)
                need['arp'] += [note_semi(e[1]), note_semi(e[1]) + 10]
            else:
                need['pad'].append(note_semi(e[1]))
    cur = None
    for e in gm.v1.ev:
        if e[0] == 'inst':
            cur = e[1]
        elif e[0] == 'note' and cur not in (gm.KICK, gm.SNARE, gm.HAT):
            key = 'pad' if cur == gm.PAD else 'lead'
            need[key].append(note_semi(e[1]))

    print('instruments:')
    ins = []
    ins.append(make_melodic('bass', 'SyntheBass.wav', 17, need['bass'], 58,
                            loop=True))
    ins.append(make_melodic('arp', 'Squares.wav', 17, need['arp'], 32))
    ins.append(make_melodic('lead', 'Leader.wav', 17, need['lead'], 52,
                            loop=True))
    ins.append(make_melodic('strings', 'AnalogString.wav', 17,
                            need['pad'], 40, loop=True))
    ins.append(make_oneshot('bassdrum2', 'BassDrum2.wav', 62, gain=1.2))
    ins.append(make_oneshot('snare1', 'Snare1.wav', 50))
    ins.append(make_oneshot('hihat1', 'HiHat1.wav', 26))
    for nm in ('kattene', 'oohh', 'hestene', 'fantastisk'):
        ins.append(make_vocal(nm, 64))

    I_BASS, I_ARP, I_LEAD, I_PAD = 1, 2, 3, 4
    I_KICK, I_SNARE, I_HAT = 5, 6, 7
    V0 = 8                                     # first vocal instrument

    # vocal cues -> (row, rows_held, sample)
    voc = []
    for bar, fr, sid in ((3, 73, 0), (6, 62, 1), (8, 1, 2), (16, 37, 3),
                         (35, 73, 0), (38, 62, 1), (40, 1, 2), (48, 37, 3),
                         (58, 0, 3)):
        smp = ins[V0 - 1 + sid + 0]             # list is 0-based
        frames = len(smp.data) / (PAULA / 428) * 50
        row = frame_to_row(bar * gm.BAR + fr)
        voc.append((row, int(frames / 6) + 1, V0 + sid))

    rows = build_patterns(ins, voc)
    mod = encode(rows, ins)
    out = os.path.join(HERE, 'motorsag.mod')
    with open(out, 'wb') as f:
        f.write(mod)
    total = sum(len(i.data) for i in ins)
    print(f'motorsag.mod written: {len(mod)} bytes '
          f'({total} sample bytes, {64 * ROWS_PER_BAR // 64} patterns)')


if __name__ == '__main__':
    main()
