; ===================================================================
;  Standalone SID build of the Motorsag Arkitekt score.
;  Produces a raw C64 image (load $1000) with the PSID entry points:
;      init = $1000   (jsr music_init)
;      play = $1003   (jsr music_play)  - call once per PAL frame
;  build.sh wraps this into a proper .sid (PSID v2) file.
; ===================================================================

        !to "motorsag_sid.prg", cbm

        * = $1000
        jmp music_init          ; $1000  init
        jmp music_play          ; $1003  play (50 Hz)

        !source "notes.inc"
        !source "tables.inc"
        !source "music.asm"
