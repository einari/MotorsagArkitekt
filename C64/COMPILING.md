# Compiling MOTORSAG ARKITEKT (C64)

Everything here compiles to a **proper C64 `.prg`** — a program file that loads
to `$0801` with a BASIC autostart stub, so `LOAD"*",8,1` + `RUN` (or a double
click in an emulator) just works.

---

## 1. What you need

| Tool | Needed for | Required? |
|------|-----------|-----------|
| **ACME** cross-assembler | building `motorsag.prg` | **Yes** — this is the only hard requirement |
| **Python 3** | wrapping the music into `motorsag.sid` | optional |
| **VICE** (`c1541`, `x64sc`, `vsid`) | making a `.d64` disk image and running/playing | optional |

If all you want is the runnable program, **ACME alone is enough.**

### Install the tools

**Debian / Ubuntu / WSL**
```bash
sudo apt-get update
sudo apt-get install acme          # the assembler (required)
sudo apt-get install vice          # emulator + c1541 + vsid (optional)
# python3 is already present on these systems
```

**macOS (Homebrew)**
```bash
brew install acme                  # required
brew install vice                  # optional
```

**Windows**
- ACME: download from <https://sourceforge.net/projects/acme-crossass/> and put
  `acme.exe` on your `PATH`.
- VICE (optional): <https://vice-emu.sourceforge.io/>.
- Python (optional): <https://www.python.org/downloads/>.

Check ACME is ready:
```bash
acme --version
# -> This is ACME, release 0.97 ...
```

---

## 2. Compile to a `.prg`

### The one command that matters
From inside the `C64/` folder:
```bash
acme motorsag.asm
```
That's it. It reads `motorsag.asm` (which `!source`-includes `notes.inc`,
`tables.inc`, `music.asm` and `sprites.inc`) and writes **`motorsag.prg`**.

> The output name and CBM format are set *inside* the source with
> `!to "motorsag.prg", cbm`, so you don't pass any `-o`/`-f` flags. If you want a
> different name you can override it: `acme --outfile mydemo.prg motorsag.asm`.

### Or build everything at once
```bash
./build.sh
```
This runs ACME and additionally produces:
- `motorsag.sid` — the tune as a standalone PSID (needs Python 3)
- `motorsag.d64` — a disk image for real hardware (needs VICE's `c1541`)

Missing optional tools are skipped; the `.prg` is always built.

---

## 3. Check it built correctly

A proper `.prg` starts with the two-byte load address `01 08` (little-endian
`$0801`):
```bash
# Linux/macOS - first bytes should be: 01 08 0b 08 ...
od -An -tx1 -N4 motorsag.prg          # -> 01 08 0b 08
ls -l motorsag.prg                    # ~6 KB
```
Load address `$0801` + the BASIC stub means it autostarts with `SYS 2064`.

---

## 4. Run it

**Emulator (VICE):**
```bash
x64sc motorsag.prg                    # or:  x64sc motorsag.d64
```
Or drag `motorsag.prg` / `motorsag.d64` onto any C64 emulator window.

**Real C64:**
Copy `motorsag.prg` (or `motorsag.d64`) to an SD2IEC / 1541-Ultimate / Kung Fu
Flash, then:
```
LOAD"MOTORSAG",8,1
RUN
```

**Just the music:**
```bash
vsid motorsag.sid                     # or load it in any SID player / DAW
```

---

## 5. Regenerating the included data (only if you change it)

The generated includes are committed, so ACME alone can always build the demo.
`build.sh` reruns the generators automatically when Python 3 is present:

| generator       | output                                                | edit it to change                                         |
|-----------------|-------------------------------------------------------|-----------------------------------------------------------|
| `gen_music.py`  | `music_data.inc`                                      | the song: melody, chords, drums, structure                |
| `gen_assets.py` | `gfx_sprites.inc`, `gfx_chars.inc`, `gfx_tables.inc`  | sprites, the outrun screen, tunnel map, animation tables  |

`gen_assets.py` also renders preview PNGs into `preview/` so you can check the
art without an emulator. `notes.inc` and `tables.inc` (note frequencies, sine
tables) are static and rarely need touching. For a plain compile you can
ignore this section entirely.
