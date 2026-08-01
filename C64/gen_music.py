#!/usr/bin/env python3
"""
Generate music_data.inc — the full "Motorsag Arkitekt" arrangement as data for
the 3-voice SID driver in music.asm.

The song was transcribed from music.mp3 (see ../../prompt/demo.md):
  * ~129 BPM, first beat 0.408s, 63.25 bars total -> arranged as 64 bars
  * key: E minor, circle progression  Em Am D G/B7 C Am C B7 -> Em
  * the "fantastisk" hook resolves to E MAJOR (Picardy third)
  * structure: intro(0-3) verse1(4-18,fill 19) drop(20-33) break(34-35)
               verse2(36-49) hook-tail(50) finale(51-60) outro(61-63)

Timing: PAL 50 Hz. One bar = 93 frames => 50*60*4/93 = 129.03 BPM (exact
match).  Eighth-note slot durations [12,11,12,12,12,11,12,11] sum to 93.

Voices:
  1: drums (kick/snare/hat) and lead melody, sharing the channel the classic
     SID way — the snare backbeat is punched into the lead lines
  2: chord arpeggios / pads
  3: octave-jumping eighth-note bass (its pitch-thump doubles as the kick)

Run:  python3 gen_music.py   -> writes music_data.inc
"""

E8 = [12, 11, 12, 12, 12, 11, 12, 11]          # eighth-note frame durations
BAR = sum(E8)                                   # 93 frames = 1 bar
assert BAR == 93

NOTE_IDX = {n: i for i, n in enumerate(
    ['c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b'])}

def N(name):
    """'f#4' -> driver note number (1..96, c0=1)."""
    if name[1] == '#':
        pc, octv = name[:2], int(name[2:])
    else:
        pc, octv = name[0], int(name[1:])
    v = 1 + octv * 12 + NOTE_IDX[pc]
    assert 1 <= v <= 96, name
    return v

# instrument ids — must match the table order in music.asm
LEAD, ARPM, ARPJ, BASS, KICK, SNARE, HAT, LEAD2, PAD, ARP7 = range(10)

TIE, INST, END = 0xFD, 0xFE, 0xFF
DRUM_NOTES = {'K': ('c2', KICK), 'S': ('a4', SNARE), 'H': ('g#5', HAT)}


class Voice:
    """Accumulates (note,dur) events; merges '-' ties and '.' rests."""

    def __init__(self):
        self.ev = []          # list of (kind, note, dur, inst)
        self.frames = 0
        self.cur_inst = None

    def _emit(self, note, dur, inst=None):
        if inst is not None and inst != self.cur_inst:
            self.ev.append(('inst', inst))
            self.cur_inst = inst
        self.ev.append(('note', note, dur))
        self.frames += dur

    def rest(self, dur):
        # merge consecutive rests
        if self.ev and self.ev[-1][0] == 'rest':
            self.ev[-1] = ('rest', self.ev[-1][1] + dur)
        else:
            self.ev.append(('rest', dur))
        self.frames += dur

    def tie(self, dur):
        self.ev.append(('tie', dur))
        self.frames += dur

    def bar8(self, slots, inst):
        """One bar from 8 eighth-note tokens:
        note name | 'K'/'S'/'H' drums | '-' extend previous | '.' rest."""
        assert len(slots) == 8
        i = 0
        while i < 8:
            tok = slots[i]
            dur = E8[i]
            j = i + 1
            while j < 8 and slots[j] == '-':
                dur += E8[j]
                j += 1
            if tok == '.':
                self.rest(dur)
            elif tok == '-':
                raise ValueError("dangling '-' at slot %d" % i)
            elif tok in DRUM_NOTES:
                nm, di = DRUM_NOTES[tok]
                self._emit(N(nm), dur, di)
            else:
                self._emit(N(tok), dur, inst)
            i = j

    def hold(self, name, bars, inst):
        """A note held over N bars (tie events keep it un-retriggered)."""
        self._emit(N(name), BAR, inst)
        for _ in range(bars - 1):
            self.tie(BAR)

    def encode(self):
        out = []
        for e in self.ev:
            if e[0] == 'inst':
                out += [INST, e[1]]
            elif e[0] == 'note':
                out += [e[1], self._dur(e[2], out)]
            elif e[0] == 'rest':
                out += self._long(0x00, e[1])
            elif e[0] == 'tie':
                out += self._long(TIE, e[1])
        out.append(END)
        return out

    def _dur(self, d, out):
        assert 1 <= d <= 255, d
        return d

    @staticmethod
    def _long(kind, dur):
        """Split rests/ties longer than 255 frames into chained events."""
        out = []
        while dur > 255:
            out += [kind, 255]
            dur -= 255
            kind = TIE if kind == TIE else 0x00
            # a chained rest re-gates-off, which is harmless
        out += [kind, dur]
        return out


# ---------------------------------------------------------------------------
#  Harmony: chord per bar (64 bars)
# ---------------------------------------------------------------------------
# chord -> (bass root, arp root, arp instrument)
CHORDS = {
    'Em': ('e1', 'e3', ARPM), 'Am': ('a1', 'a3', ARPM),
    'D':  ('d2', 'd3', ARPJ), 'G':  ('g1', 'g3', ARPJ),
    'B7': ('b1', 'b3', ARP7), 'C':  ('c2', 'c4', ARPJ),
    'E':  ('e1', 'e3', ARPJ), 'Bm': ('b1', 'b3', ARPM),
}

VERSE = ['Em', 'Em', 'Am', 'Am', 'D', 'D', 'G', 'B7',
         'C', 'C', 'Am', 'Am', 'C', 'B7', 'E']                 # 15 bars
DROP = ['Em', 'Em', 'Am', 'Am', 'D', 'D', 'G', 'G',
        'C', 'C', 'Am', 'Am', 'C', 'B7']                       # 14 bars
FINALE = ['Em', 'Em', 'Am', 'Am', 'D', 'D', 'G', 'B7', 'E', 'E']  # 10 bars

SONG = (['Bm', 'Bm', 'Em', 'Em'] +          # 0-3   intro
        VERSE + ['E'] +                      # 4-19  verse 1 + fill bar
        DROP +                               # 20-33 drop
        ['Em', 'Em'] +                       # 34-35 break
        VERSE[:12] + ['C', 'E'] +            # 36-49 verse 2 (C/B7 squeezed)
        ['E'] +                              # 50    hook tail rings out
        FINALE +                             # 51-60 finale
        ['E', 'E', 'E'])                     # 61-63 outro
assert len(SONG) == 64, len(SONG)

# ---------------------------------------------------------------------------
#  Voice 1 — drums + lead melody
# ---------------------------------------------------------------------------
# The sung verse melody, transcribed with the autocorrelation tracker
# (see prompt: contour and pitch classes follow the recorded vocal):
#   "Kattene"      F#4 G4 F#4 -> B3      "motorsag" lands on a held C4
#   "(oohh)"       high held C5->B4 / B4
#   "Hestene"      F#4 G4 F#4 -> D4      "...oppdrag" held B3 over G
#   "hvorfor det"  C5 C5 B4
#   "nei nei nei"  repeated B3
#   hook "er fan-tas-tisk" = stepwise DESCENT A4 G4 F#4 -> E4 (E major)
VERSE_LEAD = [
    ['f#4', '-', 'g4', 'f#4',  'b3', '-',  '-',  '-'],   # Em  "Kat-te-ne"
    ['.',  'b3', 'c4', 'b3',   'g3', 'b3', 'd4', 'c4'],  # Em  "de leker seg med mo-tor-"
    ['c4', '-',  '-',  '-',    '-',  '-',  'S',  '.'],   # Am  "-sag" (held)
    ['c5', '-',  '-',  '-',    'b4', '-',  '-',  '-'],   # Am  "(oohh)" high
    ['f#4', '-', 'g4', 'f#4',  'd4', '-',  '-',  '-'],   # D   "Hes-te-ne"
    ['.',  'd4', 'd4', 'd4',   'e4', 'f#4', 'e4', 'd4'], # D   "de soeker arki-"
    ['b3', '-',  '-',  '-',    '-',  '-',  'S',  '.'],   # G   "-tektoppdrag" (held)
    ['b4', '-',  '-',  '-',    '-',  '-',  '-',  '-'],   # B7  "(oohh)" high
    ['c5', '-',  'c5', '-',    'b4', '-',  '-',  '-'],   # C   "hvor-for det"
    ['.',  '.',  'a4', 'a4',   'a4', 'g4', 'e4', 'd4'],  # C   "det er faktisk..."
    ['b3', '-',  '-',  '.',    '.',  '.',  'S',  '.'],   # Am  "...aa si"
    ['b3', '-',  'b3', '-',    'b3', '-',  'S',  '.'],   # Am  "nei nei nei"
    ['c4', 'c4', 'c4', 'b3',   'c4', 'c4', 'b3', 'b3'],  # C   "men det vi vet..."
    ['a4', '-',  'g4', '-',    'f#4', '-', '-',  '-'],   # B7  "er fan-tas-"
    ['e4', '-',  '-',  '-',    '-',  '-',  '-',  '-'],   # E   "-tisk!" (held)
]
DRUM_BAR = ['K', 'H', 'S', 'H', 'K', 'H', 'S', 'H']
DRUM_FILL = ['K', 'H', 'S', 'H', 'S', 'S', 'S', 'S']

DROP_LEAD = [
    ['c5', 'b4', 'S', 'g4',  'e5', 'c5', 'S', 'b4'],     # C
    ['g4', 'a4', 'S', 'b4',  'c5', 'd5', 'S', 'e5'],     # C
    ['a4', 'e4', 'S', 'a4',  'c5', 'a4', 'S', 'e5'],     # Am
    ['e5', 'd5', 'S', 'c5',  'b4', 'c5', 'S', 'd5'],     # Am
    ['e5', 'c5', 'S', 'b4',  'a4', 'g4', 'S', 'a4'],     # C
    ['f#4', 'd#4', 'S', 'b3', 'f#4', 'a4', 'S', 'b4'],   # B7
]
FINALE_LEAD = [
    ['f#5', '-', 'S', 'g5',  'e5', '-',  'S', '-'],      # Em
    ['e5', 'd5', 'S', 'b4',  'g4', 'b4', 'S', 'd5'],     # Em
    ['a4', 'c5', 'S', 'e5',  'a5', '-',  'S', '-'],      # Am
    ['e5', 'c5', 'S', 'b4',  'a4', 'b4', 'S', 'c5'],     # Am
    ['d5', 'd5', 'S', 'e5',  'f#5', '-', 'S', '-'],      # D
    ['f#5', 'e5', 'S', 'd5', 'a4', 'd5', 'S', 'e5'],     # D
    ['g5', '-',  'S', 'd5',  'b4', 'd5', 'S', 'g4'],     # G
    ['a5', '-',  'S', 'g5',  'f#5', '-', 'S', '-'],      # B7  hook descent, big
    ['e5', '-',  'S', '-',   'e5', '-',  'S', '-'],      # E   "-tisk!"
    ['b4', 'e5', 'S', 'g#5', 'b5', '-',  'S', '-'],      # E
]

v1 = Voice()
v1.rest(BAR * 2)                                   # 0-1  intro pads only
v1.bar8(['H', '.', 'H', '.', 'H', '.', 'H', '.'], LEAD)  # 2 hats sneak in
v1.bar8(['H', 'H', 'S', 'H', 'S', 'S', 'S', 'S'], LEAD)  # 3 fill
for b in VERSE_LEAD:                               # 4-18 verse 1 (lead)
    v1.bar8(b, LEAD)
v1.bar8(['b4', 'g#4', 'e4', 'b3', 'S', 'S', 'S', 'S'], LEAD)  # 19 fill
for _ in range(8):                                 # 20-27 drop: drums
    v1.bar8(DRUM_BAR, LEAD)
for b in DROP_LEAD:                                # 28-33 drop lead + snare
    v1.bar8(b, LEAD2)
v1.hold('e4', 2, PAD)                              # 34-35 break "oohh"
for b in VERSE_LEAD[:12]:                          # 36-47 verse 2
    v1.bar8(b, LEAD)
v1.bar8(['c4', 'c4', 'b3', 'c4', 'a4', '-', 'g4', 'f#4'], LEAD)  # 48 C/B7 hook
v1.bar8(['e4', '-', '-', '-', '-', '-', '-', '-'], LEAD)         # 49 E "-tisk!"
v1.hold('b4', 1, PAD)                              # 50 hook rings out
for b in FINALE_LEAD:                              # 51-60 finale
    v1.bar8(b, LEAD2)
v1.hold('e5', 3, PAD)                              # 61-63 outro

# ---------------------------------------------------------------------------
#  Voice 2 — arpeggios / pads
# ---------------------------------------------------------------------------
v2 = Voice()
v2.hold('b3', 2, ARPM)                             # 0-1 Bm intro shimmer
for bar in SONG[2:4]:                              # 2-3 Em arps build
    root, arp, inst = CHORDS[bar][0], CHORDS[bar][1], CHORDS[bar][2]
    v2.bar8([arp] * 8, inst)

def arp_bars(bars, octave_up=False):
    for bar in bars:
        _, arp, inst = CHORDS[bar]
        note = arp if not octave_up else arp[:-1] + str(int(arp[-1]) + 1)
        v2.bar8([note] * 8, inst)

arp_bars(SONG[4:20])                               # verse 1 + fill
arp_bars(SONG[20:34], octave_up=True)              # drop: arps scream higher
v2.hold('e3', 2, ARPM)                             # break swell (Em shimmer)
arp_bars(SONG[36:50])                              # verse 2
v2.hold('e3', 1, ARPJ)                             # 50 (E major rings)
arp_bars(SONG[51:61], octave_up=True)              # finale
v2.hold('e3', 3, ARPJ)                             # outro (E major shimmer)

# ---------------------------------------------------------------------------
#  Voice 3 — bass
# ---------------------------------------------------------------------------
v3 = Voice()
v3.bar8(['b1', '-', '-', '-', 'b1', '-', '-', '-'], PAD)   # 0 soft pulses
v3.bar8(['b1', '-', '-', '-', 'b1', '-', 'b1', '-'], PAD)  # 1
v3.bar8(['e1', '-', 'e1', '-', 'e1', '-', 'e1', '-'], BASS)  # 2 quarters
v3.bar8(['e1', '-', 'e1', '-', 'e1', 'e1', 'e2', 'e1'], BASS)  # 3 run-up

def bass_bar(root):
    """Octave-jumping synthwave eighths: R R r R R r R r (r = +1 octave)."""
    up = root[:-1] + str(int(root[-1]) + 1)
    return [root, root, up, root, root, up, root, up]

for bar in SONG[4:34]:                             # verse 1 + drop
    v3.bar8(bass_bar(CHORDS[bar][0]), BASS)
v3.hold('e1', 2, PAD)                              # break: held root
for bar in SONG[36:50]:                            # verse 2
    v3.bar8(bass_bar(CHORDS[bar][0]), BASS)
v3.hold('e1', 1, PAD)                              # 50
for bar in SONG[51:61]:                            # finale
    v3.bar8(bass_bar(CHORDS[bar][0]), BASS)
v3.bar8(['e1', '-', '-', '-', 'e1', '-', '-', '-'], PAD)   # 61-63 outro
v3.bar8(['e1', '-', '-', '-', 'e1', '-', '-', '-'], PAD)
v3.bar8(['e0', '-', '-', '-', '-', '-', '-', '-'], PAD)

# ---------------------------------------------------------------------------
#  Validate + emit  (the Voice objects above are importable — the Amiga
#  port's generator reuses this exact arrangement)
# ---------------------------------------------------------------------------
TOTAL = 64 * BAR
for name, v in (('v1', v1), ('v2', v2), ('v3', v3)):
    assert v.frames == TOTAL, f'{name}: {v.frames} frames, want {TOTAL}'

def fmt_bytes(data, label):
    lines = [f'{label}']
    for i in range(0, len(data), 16):
        lines.append('        !byte ' + ','.join(f'${b:02x}' for b in data[i:i+16]))
    return '\n'.join(lines)

def emit():
    streams = {n: v.encode() for n, v in
               (('song_v1', v1), ('song_v2', v2), ('song_v3', v3))}
    write_include(streams)

def write_include(streams):
    with open('music_data.inc', 'w') as f:
        f.write('; --- Auto-generated by gen_music.py — DO NOT EDIT BY HAND ---\n')
        f.write('; "Motorsag Arkitekt" arranged for 3-voice SID, 64 bars of 93\n')
        f.write('; frames (129.03 BPM @ PAL 50Hz). Key E minor; the hook lands\n')
        f.write('; on E major. Each voice is one long event stream ending in $ff\n')
        f.write('; (the driver treats $ff as "loop this voice from its start").\n\n')
        for name, data in streams.items():
            f.write(fmt_bytes(data, name + ':') + '\n\n')
        sizes = ', '.join(f'{n}={len(d)}B' for n, d in streams.items())
        f.write(f'; sizes: {sizes}\n')
    print('music_data.inc written:',
          ', '.join(f'{n}={len(d)} bytes' for n, d in streams.items()))
    print(f'song: 64 bars x {BAR} frames = {TOTAL} frames = {TOTAL/50:.2f}s')

if __name__ == '__main__':
    emit()
