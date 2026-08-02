# MOTORSAG ARKITEKT — C64 edition

A real Commodore 64 **trackmo** version of the web production, written from
scratch in **6510 assembly**. It mirrors the browser demo scene for scene and
plays the actual song as a **3-voice SID arrangement** (no vocals — pure chip
music), transcribed from `music.mp3`: E minor, **129 BPM**, with the
"fantastisk" hook resolving to E major, exactly like the original.

It runs on a real breadbox C64 (PAL) or any emulator (VICE, etc.).

```
bars  0-3   INTRO   big KATTENE / MOTORSAG ARKITEKT logo, starfield
bars  4-7   VERSE A glowing copper bars bobbing on sines, six chainsaw
                    cats (4-frame saw animation), big lyric words
bars  8-19  VERSE B the architect horses take over, "magic circle"
                    rune-ring sprites drift by, credits scroller
bars 20-33  DROP    outrun grid: banded sun, city skyline, horizon
                    lines rushing at you — spaceships only, engine
                    flares pulsing
bars 34-50  TUNNEL  colour-cycled ring tunnel, dancer silhouettes,
                    glowing bobs, verse 2 words, greetings
bars 51-60  FINALE  grid + rainbow copper sky + the whole cast
bars 61-63  OUTRO   TUSEN TAKK end card, fade out ... and loop
```

On top of the SID score the demo **actually sings**: the key vocal phrases
of the original track are played as 4-bit digi samples through the classic
`$d418` volume-DAC trick, bar-synced to where the vocals sit in the song
(clearest on a 6581 SID — the trick that made Arkanoid and Turbo Outrun
talk).

The whole show is driven by the music: one bar = 93 PAL frames = 129.03 BPM,
64 bars ≈ 119 s, and every scene change / word cue fires on a bar boundary —
the same timeline the WebGL version uses.

## Build

Needs the **ACME** cross-assembler; Python 3 regenerates the data files and
the `.sid`; VICE's `c1541` builds the disk image (both optional).

```bash
sudo apt-get install acme vice      # Debian/Ubuntu
# or:  brew install acme vice       # macOS

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
motorsag.asm     main demo: VIC setup, raster-IRQ chain, the scenes,
                 big-font engine, sprite paths, scroller, digi player
music.asm        the SID driver (arps, PWM sweeps, vibrato, drums)
gen_music.py     generates music_data.inc — the transcribed 64-bar song
gen_assets.py    generates gfx_*.inc — sprites, outrun screen, tunnel map,
                 grid animation, sine tables (+ preview PNGs in preview/)
gen_samples.py   generates samples.inc — the 4-bit vocal digis (feed it
                 an AI-separated vocal stem of music.mp3)
music_data.inc   generated: the song event streams (3 voices)
samples.inc      generated: packed vocal samples + bar/frame cue list
gfx_sprites.inc  generated: the cast (ships, chainsaw cats, architect
                 horses, bobs, dancers, magic circles) at $2000
gfx_chars.inc    generated: custom charset half (stars, blocks, sun,
                 skyline, grid diagonals) at $3400
gfx_tables.inc   generated: outrun screen/colour maps, tunnel ring map,
                 grid line animation, sky gradients, sine tables
vocals/          the trimmed vocal phrases as reference WAVs
notes.inc        PAL note→frequency table + note-name constants
tables.inc       sine / vibrato lookup tables
sid.asm          thin wrapper that builds the tune as a standalone PSID
build.sh         regenerates data, assembles everything
make_sid.py      wraps the music payload into a .sid header
```

---

## How the effects work (the "demoscene research")

Everything is done the authentic C64 way — character graphics, colour RAM,
hardware sprites and the SID, all driven from a raster-interrupt chain.
No bitmap tricks.

### The engine

A "main" interrupt fires once per frame in the lower border (line 251) and
does the per-frame work: advance the SID player, count frames→bars, copy the
sprite shadow registers, move the scroller, decay the border flash, then arm
a chain of up to 48 tiny raster interrupts — one every 4 lines — that each
write one colour to the background register `$d021`. The KERNAL is banked out
(`$01 = $35`) so interrupts go straight through the hardware vectors. Heavy
work (tunnel colour cycling, copper table building, screen redraws) runs in
the main loop, synced to a per-frame flag.

The demo's clock **is** the music: 93 frames per bar. A 64-byte table maps
bar → scene; scene switches blank the display for a frame or two (a clean
beat-synced cut, like the browser demo's flashes) and a cue list pops the big
lyric words on the right bars.

### Copper bars (verse)

Four glowing bars, each a 7-colour ramp (cyan / hot pink / gold / green with
white cores), bob up and down on sine paths — two slow, two double-speed —
rebuilt every frame into the 48-entry colour table the raster chain reads.
This mirrors the browser's `CopperBars` shader (bars on stacked sines) rather
than the usual static stripes.

### Outrun grid (drop + finale)

The whole backdrop is one character screen generated by `gen_assets.py`:
a blocky banded sun (cell-quantised circle with gap bands on the char grid),
a black city silhouette with window holes that let the pink sky glow through,
and a fan of perspective diagonals built from a small library of quantised
slope characters (54 unique chars for the whole picture). The sky gradient is
26 static raster splits; the **horizontal grid lines are pure raster**: 22
ground splits whose colours come from a pre-computed 96-phase table, so pink
lines accelerate toward the viewer at 50 Hz — no screen writes at all. In the
finale the sky splits switch to rolling rainbow glow ramps: copper bars and
the grid at the same time.

### Tunnel (part 2)

The screen is filled with full-block characters and a 1000-byte pre-computed
ring-index map (rings denser toward the centre, like the browser tunnel's
`1/r` mapping). Each frame half the colour RAM is rewritten through a rotating
16-colour palette — full-screen colour animation at 25 Hz for the price of a
few hundred stores. On every snare the palette swaps to a hot variant, so the
whole tunnel pulses with the music. Dancer silhouettes (double-size hires
sprites) flip pose on the beat; six glowing bobs fly Lissajous figures.

### The big-font lyric words

KATTENE, HESTENE, OOHH, ROMSKIP, FANTASTISK... are drawn in a 2×-scaled font
that is generated **at runtime**: the ROM glyph is pixel-doubled into four
custom characters via a nibble-expansion lookup table, allocated from a
48-char pool on first use. Word cues fire on bar boundaries, matching where
the vocals sit in the original track.

### Sprites

The cast is 9 hardware sprites generated from ASCII art in `gen_assets.py`:
spaceships (grey hull, light-blue cockpit and ion flare), **chainsaw cats**
(black with a neon rim, orange saw), **architect horses** (purple, light-blue
mane, blueprint tube on the back), glowing bobs and two dancer poses.
A little path engine gives each scene its own configuration: walk/fly with
sine bob (9-bit X wrap at 384), Lissajous, dance (pose on beat) or bob in
place — two animation frames each.

### The big scroller

Rows 23-24 are a 16-pixel-tall scroller in true 90s style: at boot every ROM
glyph is pixel-doubled into a second 2KB charset at `$2800`, and a raster
split swaps `$d018` to it for just those two rows (swapping back in the
border). Hardware fine scroll (low 3 bits of `$d016`, 38-column trick) moves
it 2 px/frame while each message character feeds in as two glyph columns,
under a rolling rainbow wash. Credits during the verse, greetings from the
tunnel onward.

### The vocal digis

The demo's party trick: the actual vocal phrases play as **4-bit samples
through the SID master volume register** (`$d418`) — the classic volume-DAC
digi technique. CIA 2's timer A fires an NMI at ~5.2 kHz; the handler feeds
one nibble per tick from packed sample data while the 3-voice score keeps
playing "through" the volume register. Cues are (bar, frame) pairs generated
together with the samples, so KATTENE / OOHH / HESTENE / the "fantastisk"
hook land exactly where the singer does. Loud and clear on a 6581; on an
8580 you'll want the usual digiboost.

### Border flash

The border strobes on the snare backbeat (flagged by the music driver),
decaying over 5 frames through a grey→white ramp — the C64 cousin of the
browser demo's beat flashes.

---

## The SID music

Three voices at 50 Hz, one bar = 93 frames (= 129.03 BPM — the measured tempo
of `music.mp3`). The song data is generated by `gen_music.py` from a
transcription of the original track and validated so all three voices stay
bar-locked for the whole 64 bars:

- **Voice 1** — drums *and* lead, sharing the channel the classic SID way:
  noise snare/hats and a triangle kick with a pitch-drop; the lead carries the
  verse vocal melody instrumentally, and in the drop/finale the snare backbeat
  is punched in between the lead notes.
- **Voice 2** — chord **arpeggios** (minor / major / dominant-7th tables) that
  shimmer through the changes, an octave up in the drop and finale; held
  shimmer pads in the breaks.
- **Voice 3** — an octave-jumping eighth-note **bass** whose fast pitch-thump
  doubles as the kick.

The harmony follows the real song: **E minor**, circle progression
`Em Em Am Am | D D G B7 | C C Am Am | C B7` with the hook resolving to
**E major** (bars 18, 49, 59) and the outro ringing out on E — verified by
rendering the SID to audio and chord-matching it bar-by-bar against the mp3
(51/64 bars match template roots; the rest are voicing ambiguities).

Structure: intro build → verse 1 (lead = vocal line) → instrumental drop →
break ("oohh" pad swell) → verse 2 → hook tail → finale (lead an octave up) →
fading outro, then the whole demo loops.

The music is byte-for-byte the same code and data in the demo and in
`motorsag.sid`, so you can audition it in any SID player.

*Original song "Motorsag Arkitekt" by kim_jensen; SID arrangement written for
this C64 port.*
