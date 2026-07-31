# MOTORSAG ARKITEKT — C64 edition

A real Commodore 64 demo version of the web production, written from scratch in
**6510 assembly**, with the soundtrack re-arranged as a proper **3-voice SID
tune** (no vocals — pure chip music).

It runs on a real breadbox C64 (PAL) or any emulator (VICE, etc.).

```
┌────────────────────────────────────────┐
│   full-screen animated COPPER BARS      │
│      ▓▓ M O T O R S A G ▓▓  (rainbow)   │
│      ▓▓ A R K I T E K T ▓▓              │
│        kattene presenterer              │
│     a claude demoscene production       │
│                                         │
│    ✦  ships & cats bob on sine waves ✦  │
│  ✦        (8 hardware sprites)        ✦  │
│                                         │
│  ◄ smooth sine-washed scroller ...      │
└────────────────────────────────────────┘
        + driving SID score @ 125 BPM
```

## Build

Needs the **ACME** cross-assembler (and, optionally, VICE's `c1541` for the
disk image).

```bash
sudo apt-get install acme vice      # Debian/Ubuntu
# or:  brew install acme            # macOS

cd C64
./build.sh
```

That produces:

| file | what |
|------|------|
| `motorsag.prg` | the runnable demo (load address `$0801`, `SYS 2064`) |
| `motorsag.d64` | a disk image for real hardware / emulators |
| `motorsag.sid` | **just the music** — a standard PSID file for any SID player or DAW |

## Run

```bash
x64sc motorsag.prg          # VICE, accurate model
# or drag motorsag.d64 onto your emulator, then:  LOAD"*",8,1  :  RUN
vsid motorsag.sid           # just listen to the tune
```

On a real C64: put `motorsag.prg` / `motorsag.d64` on an SD2IEC / 1541-Ultimate
and `LOAD"MOTORSAG",8,1` then `RUN`.

## Files

```
motorsag.asm   main demo: VIC setup, raster-IRQ chain, copper bars,
               logo, sprites, hardware scroller, per-frame logic
music.asm      the SID player (driver) + the composed song data
notes.inc      PAL note→frequency table + note-name constants   (generated)
tables.inc     sine / vibrato lookup tables                     (generated)
sprites.inc    24×21 hi-res sprite bitmaps (spaceship + cat)     (generated)
sid.asm        thin wrapper that builds the tune as a standalone PSID
build.sh       assembles everything
make_sid.py    wraps the music payload into a .sid header
```

---

## How the effects work (the "demoscene research")

Everything below is done the authentic C64 way — no bitmap tricks, just the
VIC-II and SID registers driven from a raster interrupt.

### Raster-interrupt chain

The whole demo is timed off the VIC-II raster beam. A "main" interrupt fires
once per frame in the lower border (raster line 250) and does all the heavy
per-frame work (music, scroller, sprites, palette rotation). It then arms a
chain of ~48 tiny interrupts down the visible screen — one every 4 raster
lines — by repeatedly re-programming `$d012` (raster compare) and the IRQ
vector at `$fffe/$ffff`. KERNAL is banked out (`$01 = $35`) so the CPU takes
interrupts straight through the hardware vectors with no KERNAL overhead.

### Copper bars

Each of the ~48 chained interrupts just writes one colour to the background
register `$d021`. Because the background colour changes on every few raster
lines, the screen fills with horizontal colour bands. A ring buffer of
"glow ramp" colours is copied into the live table each frame at a moving
offset, so the bands scroll smoothly downward — the classic Amiga/C64 copper
bar look. The text logo and scroller sit *on top* of these bars (their
character cells show `$d021` as their background), so the letters glow.

### Logo

Plain text in screen RAM using the ROM uppercase font. A moving rainbow is
rolled across the two title rows every frame by writing a shifting palette
into Colour RAM (`$d800`).

### Sprites

Eight hardware sprites (`$d000…`), four spaceships and four cats, drawn as
24×21 hi-res bitmaps. Each frame every sprite's Y is looked up from a 256-byte
sine table (with a per-sprite phase offset) to make them bob, and X gets a
small sine "sway". The 9-bit X coordinate (with the `$d010` MSB) is handled so
sprites can roam the full width of the screen.

### Sine scroller

A smooth hardware scroller on the bottom text row. Fine scrolling uses the
low 3 bits of `$d016`; a raster split turns it on only for row 24 (and drops to
38-column mode to hide the edge characters). Every 8 pixels the whole row is
shifted one character to the left and the next character of the message is
pulled in from a 16-bit pointer. A moving rainbow ("sine wash") is rolled
through the row's Colour RAM for extra life.

### Border flash

The border strobes on the snare backbeat (a flag the music driver raises on
beats 2 & 4), decaying over a few frames through a colour ramp.

---

## The SID music

Three voices, a tracker-style driver called once per PAL frame (50 Hz). The
arrangement is an A-minor synthwave loop at **125 BPM**:

- **Voice 1** — lead melody over the second half of the loop; noise-based
  **snare & hi-hats** over the first half (drums and lead share the voice, the
  classic 3-channel trick).
- **Voice 2** — **arpeggios**: one held note per beat whose pitch is cycled
  through the chord (`0-3-7-12` for minor, `0-4-7-12` for major) every frame —
  the shimmering chord sound the SID is famous for.
- **Voice 3** — a driving eighth-note **bass** with a fast pitch-thump on each
  note so it doubles as the kick.

Chord progression: `Am – F – C – G | Am – F – G – E`.

What gives it the real SID character (all done per-frame in the driver):

- **ADSR** envelopes per instrument (`$d405/$d406`) with a hard-restart gate
  retrigger for punchy attacks.
- **Pulse-width modulation**: the pulse duty (`$d402/$d403`) is swept and
  ping-ponged every frame for that moving, breathing lead/pad.
- **Arpeggios** as described above.
- **Vibrato** on the lead — a delayed, table-driven pitch wobble.

The music is byte-for-byte the same code in the demo and in `motorsag.sid`, so
you can audition it in any SID player. It was verified by rendering the SID to
audio with `libsidplayfp`: continuous, no drift, a clear 125 BPM groove, and
the arrangement audibly opening up when the lead enters halfway through the
loop.

*Original song "Motorsag Arkitekt" by kim_jensen; SID arrangement written for
this C64 port.*
