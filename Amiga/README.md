# MOTORSAG ARKITEKT — Amiga 500 edition

The OCS/PAL Amiga port of the Kattene demo, written in **68000 assembly**.
It plays the *identical* 64-bar arrangement as the C64 version (93 frames
per bar = 129.03 BPM — the score is imported straight from
`../C64/gen_music.py`), but on Paula every voice gets room to breathe:

| channel | plays |
|---------|-------|
| 0       | the octave-jumping synthwave bass |
| 1       | the chord arpeggios (sawtooth shimmer) |
| 2       | the sung lead melody (square lead) |
| 3       | a real drum kit **and the actual vocals** as 8-bit samples |

Where the C64 squeezes 4-bit vocal digis through the SID volume register,
the Amiga simply *sings*: the AI-separated vocal phrases of the original
track play as proper 8 kHz Paula samples, composed into the drum channel
exactly on the bars where the singer lands (KATTENE — OOHH — HESTENE —
"…ER FANTASTISK!").

## Visuals

One-bitplane title screen ("KATTENE presenterer MOTORSAG ARKITEKT" in the
project's own chunky font) over a full-height **copper colour show** — the
timeline patches 64 copper colour slots every frame:

```
bars  0-3   black + rainbow-cycling title
bars  4-19  four sine-bobbing copper bars (cyan/pink/gold/green ramps)
bars 20-33  4096-colour sunset gradient + horizon lines rushing at you
bars 34-50  breathing tunnel rings
bars 51-60  rolling rainbow sky over the grid
bars 61-63  fade to black ... and the whole show loops
```

Underneath runs a **32-pixel-tall scroller** (the font pre-scaled 4×),
moved by hardware fine scroll (`BPLCON1` patched mid-frame by the copper)
with a 16px coarse step feeding one glyph half at a time.

## Build

Needs [vasm](http://sun.hasenbraten.de/vasm/) (m68k cpu, motorola syntax):

```bash
make CPU=m68k SYNTAX=mot        # inside the vasm source tree
export PATH=$PATH:path/to/vasm  # so vasmm68k_mot is found

cd Amiga
./build.sh                      # -> motorsag (hunk executable)
```

Python 3 + numpy regenerate `amiga_data.i`, `samples.raw` and `logo.raw`,
and [amitools](https://pypi.org/project/amitools/)' `xdftool`
(`pip install amitools`) packs the bootable disk. All generated files and
both build products are committed, so vasm alone can rebuild the
executable, and nothing at all is needed just to run it.

## Run

**Boot `motorsag.adf`** — it's a bootable floppy. In
[FS-UAE](https://fs-uae.net/) (or WinUAE) pick an **A500, PAL** config,
insert `motorsag.adf` as DF0, start — the demo boots straight from the
disk. Same story on a real A500 via a Gotek. (You still need a Kickstart
1.3 ROM configured in the emulator, as with any Amiga software.)

Alternatively, run the plain `motorsag` executable from any CLI/shell.

Either way it takes over the machine (interrupts off, own copper list)
and loops the full show forever — reset to exit, like the old days.

## Files

```
motorsag.s     the demo: takeover, copper show, 4-channel Paula player,
               big scroller
gen_amiga.py   generates everything below (imports the song from ../C64)
amiga_data.i   generated: event streams, instruments, copper list +
               patch-offset tables, colour animation tables, big font
samples.raw    generated: waveforms, drums and vocal phrases (chip RAM)
logo.raw       generated: the 320x256 one-bitplane title screen
build.sh       assembles it
```

## Roadmap

This is the first cut of the port. On the list: the sprite cast (chainsaw
cats and architect horses as Amiga sprites/bobs), the big lyric words,
beat flashes, a bootable ADF, and dual-playfield scenes to bring over the
outrun grid and tunnel bitmaps properly.
