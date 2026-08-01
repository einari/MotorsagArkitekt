; ===================================================================
;  M O T O R S A G   A R K I T E K T   -   C 6 4   D E M O
; -------------------------------------------------------------------
;  A bar-synced trackmo mirroring the WebGL demo, timed to the same
;  64-bar arrangement the SID player performs (93 frames/bar = 129 BPM):
;
;    bars  0-3   INTRO   big logo, twinkling starfield
;    bars  4-19  VERSE   sine-bobbing copper bars, chainsaw cats &
;                        architect horses, big lyric words, credits
;    bars 20-33  DROP    outrun grid: banded sun, skyline, raster-
;                        animated horizon lines, spaceships
;    bars 34-50  TUNNEL  colour-cycled ring tunnel, dancers, bobs,
;                        verse 2 words, greetings scroller
;    bars 51-60  FINALE  grid + rainbow copper sky + the whole cast
;    bars 61-63  OUTRO   TUSEN TAKK end card, fade, loop
;
;  Assemble with ACME:   acme motorsag.asm   ->  motorsag.prg
;  Run:                  x64sc motorsag.prg  (LOAD"*",8,1 : RUN)
;  PAL C64.  Everything runs off a chained raster interrupt.
; ===================================================================

        !to "motorsag.prg", cbm

; ---- hardware ----
VIC     = $d000
CIA1    = $dc00
CIA2    = $dd00
SCREEN  = $0400
COLRAM  = $d800
SPRPTR  = SCREEN + $3f8
CHARSET = $3000                 ; runtime ROM copy + custom half at $3400
BIGPOOL = $3400                 ; big-font pool chars 128-175

; ---- zero page (music driver uses $f8-$fe) ----
zp_src   = $02                  ; \ main-loop scratch pointers
zp_dst   = $04                  ; /
scrollx  = $06
tmp      = $07
msgptr   = $08                  ; 16-bit scroll message pointer
frame    = $0a                  ; rolling 8-bit frame counter
fr_bar   = $0b                  ; frame within bar (0-92)
bar      = $0c                  ; bar 0-63
scene    = $0d
pending  = $0e                  ; pending scene id ($ff = none)
frameflg = $0f                  ; vsync flag for the main loop
flash    = $10                  ; border flash decay counter
nsplits  = $11                  ; raster splits this scene (0 or 48)
scrollon = $12
wactive  = $13                  ; a big word is on screen
poolnext = $14                  ; next free big-font slot
dpose    = $15                  ; dancer pose (toggles on the beat)
gphase   = $16                  ; grid animation phase (0-95)
tunrot   = $17                  ; tunnel palette rotation
tunhalf  = $18                  ; which colram half to rewrite
vol      = $19                  ; outro fade volume
bardirty = $1a
cueidx   = $1b
splitidx = $1c
bgchar   = $1d                  ; char that "empty" cells use this scene
flashen  = $1e
wsn      = $1f                  ; active word-slot count
jvec     = $20                  ; 16-bit jump vector
spri     = $22                  ; sprite loop index
scnoff   = $23                  ; scene*8 table offset
msgid    = $24                  ; current scroll message (0 none/1 credits/2 greets)
fadecnt  = $25
vbar     = $26                  ; copper-bar builder scratch
vpos     = $27
curxlo   = $28                  ; 8 bytes: per-sprite x (16 bit)
curxhi   = $30                  ; 8 bytes
wrow     = $38                  ; big-word draw state
wcol     = $39
wcolor   = $3a
wlen     = $3b
widx     = $3c
tmp2     = $3d
exp_src  = $3e                  ; big-font expander pointers
exp_dst  = $40

SPLIT_TOP   = 50                ; first split raster line
SCROLL_LINE = 240               ; where the scroller split fires
MAIN_LINE   = 251               ; per-frame IRQ in the lower border
SCROLL_ROW  = 24

; ===================================================================
;  BASIC stub:  2026 SYS 2064
; ===================================================================
        * = $0801
        !byte $0b,$08,$ea,$07,$9e,$32,$30,$36,$34,$00,$00,$00

        * = $0810
; -------------------------------------------------------------------
;  Cold start
; -------------------------------------------------------------------
!zone
start:
        sei
        ; copy the ROM font (uppercase, chars 0-127) to RAM at $3000
        lda #$33                ; char ROM visible at $d000
        sta $01
        ldx #0
.fc:    lda $d000,x
        sta CHARSET,x
        lda $d100,x
        sta CHARSET+$100,x
        lda $d200,x
        sta CHARSET+$200,x
        lda $d300,x
        sta CHARSET+$300,x
        inx
        bne .fc
        lda #$35                ; RAM everywhere, keep I/O
        sta $01

        jsr init_vic
        jsr music_init

        lda #0
        sta frame
        sta fr_bar
        sta bar
        sta bardirty
        sta cueidx
        sta frameflg
        sta flash
        sta dpose
        lda #$ff
        sta pending
        sta scene               ; "no scene" -> intro init below

        lda #0
        jsr scene_switch        ; scene 0 = intro (also turns display on)

        jsr init_irq
        cli

; -------------------------------------------------------------------
;  Main loop: one heavy update per frame, scene switching, word cues
; -------------------------------------------------------------------
!zone
mainlp:
        lda frameflg
        beq mainlp
        lda #0
        sta frameflg

        lda pending             ; scene change queued by the IRQ?
        bmi +
        jsr scene_switch
        lda #$ff
        sta pending
+       lda bardirty            ; new bar -> maybe word cues
        beq +
        jsr do_cues
        lda #0
        sta bardirty
+       ldx scene               ; per-scene heavy update
        lda scn_upd_lo,x
        sta jvec
        lda scn_upd_hi,x
        sta jvec+1
        jsr jump_jvec
        jsr update_sprites
        jmp mainlp

!zone
jump_jvec:
        jmp (jvec)

; ===================================================================
;  VIC setup
; ===================================================================
!zone
init_vic:
        lda #$00
        sta VIC+$20             ; border black
        sta VIC+$21             ; background black
        sta VIC+$15             ; sprites off
        sta VIC+$17
        sta VIC+$1d
        sta VIC+$1c
        sta VIC+$25             ; sprite MC0 = black
        lda #$0e
        sta VIC+$26             ; sprite MC1 = light blue
        lda #$0b
        sta VIC+$11             ; display off during first init
        lda #$c8
        sta VIC+$16
        lda #$1c                ; screen $0400, charset $3000
        sta VIC+$18
        lda CIA2+0              ; VIC bank 0
        ora #$03
        sta CIA2+0
        rts

; ===================================================================
;  Raster IRQ setup (KERNAL banked out -> hardware vectors)
; ===================================================================
!zone
init_irq:
        lda #<irq_main
        sta $fffe
        lda #>irq_main
        sta $ffff
        lda #<nmi_rti
        sta $fffa
        lda #>nmi_rti
        sta $fffb
        lda #$7f                ; CIA IRQs off
        sta CIA1+$0d
        sta CIA2+$0d
        lda CIA1+$0d
        lda CIA2+$0d
        lda #$01
        sta VIC+$1a             ; raster IRQ on
        lda VIC+$11
        and #$7f
        sta VIC+$11             ; raster msb = 0
        lda #MAIN_LINE
        sta VIC+$12
        lda #$ff
        sta VIC+$19
        rts

!zone
nmi_rti:
        rti

; ===================================================================
;  MAIN IRQ (line 251): music, timing, sprite registers, scroller,
;  border flash, then arm the split chain for the next frame.
; ===================================================================
!zone
irq_main:
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta VIC+$19

        jsr music_play

        ; ---- timing: frames -> bars -> song restart ----
        inc frame
        inc fr_bar
        lda fr_bar
        cmp #93
        bcc .notbar
        lda #0
        sta fr_bar
        inc bar
        lda #1
        sta bardirty
        lda bar
        cmp #64
        bcc .nowrap
        ; song done -> restart everything
        lda #0
        sta bar
        sta cueidx
        jsr music_init
.nowrap:
        ; queue a scene switch when the timeline says so
        ldx bar
        lda scene_of_bar,x
        cmp scene
        beq .notbar
        sta pending
.notbar:

        ; ---- copy sprite shadow registers (set up by the main loop) ----
        ldx #0
        ldy #0
-       lda sh_xlo,x
        sta VIC+0,y
        lda sh_y,x
        sta VIC+1,y
        iny
        iny
        lda sh_ptr,x
        sta SPRPTR,x
        lda sh_col,x
        sta VIC+$27,x
        inx
        cpx #8
        bne -
        lda sh_msb
        sta VIC+$10
        lda sh_en
        sta VIC+$15
        lda sh_mc
        sta VIC+$1c
        lda sh_xe
        sta VIC+$1d
        lda sh_ye
        sta VIC+$17

        ; ---- default fine scroll for the top of the screen ----
        lda #$c8
        sta VIC+$16

        ; ---- scroller ----
        lda scrollon
        beq +
        jsr do_scroll
+
        ; ---- snare-driven bits: border flash + dancer pose ----
        lda beat_flag
        beq .noflash
        lda #0
        sta beat_flag
        lda dpose
        eor #1
        sta dpose
        lda flashen
        beq .noflash
        lda #5
        sta flash
.noflash:
        ldx flash
        lda flash_col,x
        sta VIC+$20
        lda flash
        beq +
        dec flash
+
        ; ---- arm the split chain ----
        lda nsplits
        beq .nochain
        lda #0
        sta splitidx
        lda #SPLIT_TOP
        sta VIC+$12
        lda #<irq_split
        sta $fffe
        lda #>irq_split
        sta $ffff
        jmp .armed
.nochain:
        lda #0                  ; no split chain -> keep the background
        sta VIC+$21             ; black (a previous scene may have left
        lda scrollon            ; its last split colour behind)
        beq .armed              ; nothing to do until next main irq
        lda #SCROLL_LINE
        sta VIC+$12
        lda #<irq_scroll
        sta $fffe
        lda #>irq_scroll
        sta $ffff
.armed:
        lda #1
        sta frameflg
        pla
        tay
        pla
        tax
        pla
        rti

; ===================================================================
;  SPLIT IRQ: one background colour write every 4 raster lines.
; ===================================================================
!zone
irq_split:
        pha
        txa
        pha
        lda #$ff
        sta VIC+$19
        ldx splitidx
        lda split_col,x
        sta VIC+$21
        inx
        stx splitidx
        cpx nsplits
        bcs .chain_done
        txa
        asl
        asl
        clc
        adc #SPLIT_TOP
        sta VIC+$12
        pla
        tax
        pla
        rti
.chain_done:
        lda scrollon
        beq .tomain
        lda #SCROLL_LINE
        sta VIC+$12
        lda #<irq_scroll
        sta $fffe
        lda #>irq_scroll
        sta $ffff
        pla
        tax
        pla
        rti
.tomain:
        lda #MAIN_LINE
        sta VIC+$12
        lda #<irq_main
        sta $fffe
        lda #>irq_main
        sta $ffff
        pla
        tax
        pla
        rti

; ===================================================================
;  SCROLLER SPLIT (line 240): fine scroll + 38 cols for row 24 only,
;  black background under the text.
; ===================================================================
!zone
irq_scroll:
        pha
        lda #$ff
        sta VIC+$19
        lda scrollx
        ora #$c0                ; 38 cols + xscroll
        sta VIC+$16
        lda #$00
        sta VIC+$21
        lda #MAIN_LINE
        sta VIC+$12
        lda #<irq_main
        sta $fffe
        lda #>irq_main
        sta $ffff
        pla
        rti

; ===================================================================
;  Scene switching (main-loop context, display blanked while drawing)
; ===================================================================
!zone
scene_switch:
        sta scene
        asl
        asl
        asl
        sta scnoff              ; scene*8 for the sprite config tables
        lda VIC+$11
        and #$ef
        sta VIC+$11             ; display off -> clean black cut
        lda #0
        sta sh_en
        sta VIC+$15
        sta wactive
        sta wsn
        sta poolnext
        ldx #31                 ; forget big-font letter allocations
        lda #0
-       sta lmap,x
        dex
        bpl -
        jsr spr_load_config
        ldx scene
        lda scn_ini_lo,x
        sta jvec
        lda scn_ini_hi,x
        sta jvec+1
        jsr jump_jvec
        lda VIC+$11
        ora #$10
        sta VIC+$11             ; display on
        rts

; -------------------------------------------------------------------
;  Shared init helpers
; -------------------------------------------------------------------
!zone
clear_screen:
        ldx #0
        lda #$20
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        inx
        bne -
        ldx #0
        lda #$0b
-       sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$300,x
        inx
        bne -
        rts

!zone
draw_stars:
        ldx #0
.st:    txa
        pha
        asl
        asl                     ; *4
        tay
        lda star_table,y        ; row
        tax
        lda star_table+1,y      ; col
        clc
        adc scr_lo,x
        sta zp_dst
        lda scr_hi,x
        adc #0
        sta zp_dst+1
        lda star_table+2,y      ; char
        ldy #0
        sta (zp_dst),y
        lda zp_dst+1
        clc
        adc #$d4                ; screen -> colour RAM ($04xx -> $d8xx)
        sta zp_dst+1
        pla
        pha
        asl
        asl
        tay
        lda star_table+3,y      ; colour
        ldy #0
        sta (zp_dst),y
        pla
        tax
        inx
        cpx #NUM_STARS
        bne .st
        rts

; twinkle: roll a grey/white palette over the star cells
!zone
twinkle:
        lda frame
        and #$07
        bne .tw_done            ; every 8th frame
        ldx #0
.tw:    txa
        pha
        asl
        asl
        tay
        lda star_table,y        ; row
        stx tmp
        tax
        lda star_table+1,y      ; col
        clc
        adc col_lo,x
        sta zp_dst
        lda col_hi,x
        adc #0
        sta zp_dst+1
        lda frame
        lsr
        lsr
        lsr
        clc
        adc tmp
        and #$07
        tay
        lda twinkle_pal,y
        ldy #0
        sta (zp_dst),y
        pla
        tax
        inx
        cpx #NUM_STARS
        bne .tw
.tw_done:
        rts

; draw a zero-terminated small-text string: zp_src=str, X=row, Y=col, tmp=colour
!zone
draw_text:
        tya
        clc
        adc scr_lo,x
        sta zp_dst
        lda scr_hi,x
        adc #0
        sta zp_dst+1
        ldy #0
.dt:    lda (zp_src),y
        beq .dt_done
        sta (zp_dst),y
        iny
        bne .dt
.dt_done:
        ; recolour the same cells
        lda zp_dst+1
        clc
        adc #$d4
        sta zp_dst+1
        ldy #0
.dc:    lda (zp_src),y
        beq .dc_done
        lda textcol
        sta (zp_dst),y
        iny
        bne .dc
.dc_done:
        rts
textcol !byte $0b

; set the scroll message: A = id (1 credits, 2 greets); no-op if current
!zone
set_msg:
        cmp msgid
        beq .sm_done
        sta msgid
        cmp #2
        beq .sm_greets
        lda #<credits_text
        sta msgptr
        lda #>credits_text
        sta msgptr+1
        jmp .sm_clear
.sm_greets:
        lda #<greets_text
        sta msgptr
        lda #>greets_text
        sta msgptr+1
.sm_clear:
        ldx #39                 ; blank the scroller row
        lda #$20
-       sta SCREEN + SCROLL_ROW*40,x
        dex
        bpl -
        lda #7
        sta scrollx
        rts
.sm_done:
        rts

; ===================================================================
;  SCENE 0: INTRO  — starfield + the big title
; ===================================================================
!zone
intro_init:
        jsr clear_screen
        jsr draw_stars
        lda #0
        sta nsplits
        sta scrollon
        sta flashen
        sta msgid
        lda #$20
        sta bgchar
        ldy #4                  ; big KATTENE
        lda #WORD_KATTENE
        jsr draw_word
        lda #<txt_pres
        sta zp_src
        lda #>txt_pres
        sta zp_src+1
        lda #$0e
        sta textcol
        ldx #8
        ldy #14
        jsr draw_text
        ldy #11                 ; big MOTORSAG / ARKITEKT
        lda #WORD_MOTORSAG
        jsr draw_word
        ldy #14
        lda #WORD_ARKITEKT
        jsr draw_word
        lda #<txt_prod
        sta zp_src
        lda #>txt_prod
        sta zp_src+1
        lda #$0b
        sta textcol
        ldx #19
        ldy #5
        jsr draw_text
        rts

!zone
intro_update:
        jsr twinkle
        ; rainbow roll across the KATTENE row (rows 4-5, cols 13-26)
        ldx #0
.ir:    txa
        clc
        adc frame
        lsr
        lsr
        and #$07
        tay
        lda logo_pal,y
        sta COLRAM + 4*40 + 13,x
        sta COLRAM + 5*40 + 13,x
        inx
        cpx #14
        bne .ir
        rts

; ===================================================================
;  SCENE 1: VERSE — sine-bobbing copper bars + cats & horses
; ===================================================================
!zone
verse_init:
        jsr clear_screen
        jsr draw_stars
        lda #48
        sta nsplits
        lda #1
        sta scrollon
        sta flashen
        jsr set_msg             ; A=1 -> credits
        lda #$20
        sta bgchar
        ldx #47                 ; start with black bars
        lda #0
-       sta split_col,x
        dex
        bpl -
        rts

!zone
verse_update:
        jsr twinkle
        ; ---- rebuild the copper bar colour table ----
        ldx #47
        lda #0
-       sta split_col,x
        dex
        bpl -
        ; four glowing bars on sine paths (two slow, two double speed)
        lda #0
        sta vbar
.vb:    ldx vbar
        lda frame
        cpx #2
        bcc +
        asl                     ; bars 2 & 3 bob at double speed
+       clc
        adc bar_phase,x
        tay
        lda sine_ctr,y          ; centre split (5..40)
        sec
        sbc #3
        sta vpos                ; first split of the 7-entry glow ramp
        txa
        asl
        asl
        asl
        tax                     ; ramp row = bar*8
        ldy #0
.vr:    lda bar_ramps,x
        sty tmp
        ldy vpos
        sta split_col,y
        inc vpos
        ldy tmp
        inx
        iny
        cpy #7
        bne .vr
        inc vbar
        lda vbar
        cmp #4
        bne .vb
        rts

bar_phase !byte 0, 96, 160, 224

; ===================================================================
;  SCENE 2: DROP — outrun grid, sun, skyline, ships
; ===================================================================
!zone
drop_init:
        jsr copy_drop_image
        lda #48
        sta nsplits
        lda #0
        sta scrollon
        sta gphase
        lda #1
        sta flashen
        lda #$20
        sta bgchar
        ; sky gradient into splits 0-25
        ldx #25
-       lda sky_grad,x
        sta split_col,x
        dex
        bpl -
        jsr grid_ground
        rts

!zone
copy_drop_image:
        ldx #0
-       lda drop_screen,x
        sta SCREEN,x
        lda drop_screen+250,x
        sta SCREEN+250,x
        lda drop_screen+500,x
        sta SCREEN+500,x
        lda drop_screen+750,x
        sta SCREEN+750,x
        lda drop_color,x
        sta COLRAM,x
        lda drop_color+250,x
        sta COLRAM+250,x
        lda drop_color+500,x
        sta COLRAM+500,x
        lda drop_color+750,x
        sta COLRAM+750,x
        inx
        cpx #250
        bne -
        rts

; copy this phase's 22 ground-split colours into the split table
!zone
grid_ground:
        lda gphase
        ; ptr = grid_anim + phase*22
        sta tmp
        asl
        asl
        clc
        adc tmp                 ; *5
        asl                     ; *10
        sta zp_src
        lda #0
        sta zp_src+1
        rol zp_src+1
        lda zp_src
        asl
        rol zp_src+1            ; *20
        clc
        adc tmp
        bcc +
        inc zp_src+1
+       clc
        adc tmp                 ; *22
        bcc +
        inc zp_src+1
+       clc
        adc #<grid_anim
        sta zp_src
        lda zp_src+1
        adc #>grid_anim
        sta zp_src+1
        ldy #21
-       lda (zp_src),y
        sta split_col+26,y
        dey
        bpl -
        rts

!zone
drop_update:
        inc gphase
        lda gphase
        cmp #96
        bcc +
        lda #0
        sta gphase
+       jsr grid_ground
        rts

; ===================================================================
;  SCENE 3: TUNNEL — colour-cycled rings, dancers, bobs
; ===================================================================
!zone
tunnel_init:
        ; whole screen becomes full-block chars; colour does the rest
        ldx #0
        lda #182
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2c0,x       ; rows up to 23 ($2c0+$100 = row 24 start)
        inx
        bne -
        lda #0
        sta nsplits
        sta tunrot
        sta tunhalf
        lda #2
        jsr set_msg             ; greetings
        lda #1
        sta scrollon
        sta flashen
        lda #182
        sta bgchar
        rts

!zone
tunnel_update:
        ; rotate the ring palette every other frame (inward motion)
        lda frame
        and #1
        bne +
        inc tunrot
+       ; build the live 16-colour palette (hot variant while flashing)
        ldx #0
.tp:    txa
        clc
        adc tunrot
        and #$0f
        tay
        lda flash
        cmp #3
        bcs .hot
        lda ringpal,y
        jmp .store
.hot:   lda ringpal_hot,y
.store: sta ringcur,x
        inx
        cpx #16
        bne .tp
        ; rewrite half the colour RAM (rows 0-11 / 12-23) via the ring map
        lda tunhalf
        eor #1
        sta tunhalf
        bne .lower
        ldx #0
-       ldy tunnel_map,x
        lda ringcur,y
        sta COLRAM,x
        ldy tunnel_map+240,x
        lda ringcur,y
        sta COLRAM+240,x
        inx
        cpx #240
        bne -
        jmp .words
.lower:
        ldx #0
-       ldy tunnel_map+480,x
        lda ringcur,y
        sta COLRAM+480,x
        ldy tunnel_map+720,x
        lda ringcur,y
        sta COLRAM+720,x
        inx
        cpx #240
        bne -
.words:
        jsr word_recolor
        rts

; ===================================================================
;  SCENE 4: FINALE — grid + rainbow copper sky + everything
; ===================================================================
!zone
finale_init:
        jsr copy_drop_image
        ldx #39                 ; row 24 hosts the greets scroller
        lda #$20
-       sta SCREEN + SCROLL_ROW*40,x
        dex
        bpl -
        lda #48
        sta nsplits
        lda #2
        jsr set_msg
        lda #1
        sta scrollon
        sta flashen
        lda #0
        sta gphase
        lda #$20
        sta bgchar
        jsr grid_ground
        rts

!zone
finale_update:
        inc gphase
        lda gphase
        cmp #96
        bcc +
        lda #0
        sta gphase
+       jsr grid_ground
        ; rainbow copper waves rolling through the sky splits
        ldx #0
.fs:    txa
        clc
        adc frame
        lsr
        and #$1f
        tay
        lda rainbow32,y
        sta split_col,x
        inx
        cpx #26
        bne .fs
        rts

; ===================================================================
;  SCENE 5: OUTRO — TUSEN TAKK, fade to black
; ===================================================================
!zone
outro_init:
        jsr clear_screen
        jsr draw_stars
        lda #0
        sta nsplits
        sta scrollon
        sta flashen
        sta fadecnt
        sta msgid
        lda #$20
        sta bgchar
        lda #15
        sta vol
        ldy #7
        lda #WORD_TAKK
        jsr draw_word
        lda #<txt_romskip
        sta zp_src
        lda #>txt_romskip
        sta zp_src+1
        lda #$0e
        sta textcol
        ldx #12
        ldy #9
        jsr draw_text
        lda #<txt_2026
        sta zp_src
        lda #>txt_2026
        sta zp_src+1
        lda #$0b
        sta textcol
        ldx #15
        ldy #13
        jsr draw_text
        rts

!zone
outro_update:
        jsr twinkle
        ; rainbow roll on TUSEN TAKK (rows 7-8, cols 10-29)
        ldx #0
.orr:   txa
        clc
        adc frame
        lsr
        lsr
        and #$07
        tay
        lda logo_pal,y
        sta COLRAM + 7*40 + 10,x
        sta COLRAM + 8*40 + 10,x
        inx
        cpx #20
        bne .orr
        ; fade the SID out over the last two bars
        lda bar
        cmp #62
        bcc .of_done
        inc fadecnt
        lda fadecnt
        and #$0f
        bne .of_done
        lda vol
        beq .of_done
        dec vol
        lda vol
        sta $d418
.of_done:
        rts

; ===================================================================
;  Word cues (big lyric words on bar boundaries)
; ===================================================================
!zone
do_cues:.next:  ldx cueidx
        lda cue_bar,x
        cmp #$ff
        beq .done
        cmp bar
        bne .chk
        lda cue_act,x
        cmp #$fe
        beq .clr
        pha
        jsr clear_words
        pla
        ldy #2                  ; cue words live on rows 2-3
        jsr draw_word
        jmp .adv
.clr:   jsr clear_words
.adv:   inc cueidx
        jmp .next
.chk:   bcs .done               ; cue bar > current bar -> wait
        inc cueidx              ; stale cue (can happen right after
        jmp .next               ; a scene skipped over it) -> skip
.done:  rts

; ===================================================================
;  Big-font engine: 2x2-cell letters expanded from the ROM glyphs
; ===================================================================

; ---- clear all active words (restore bgchar), reset the letter pool
!zone
clear_words:
        lda wsn
        beq .cw_done
        ldx #0
.cw_word:
        stx tmp2
        lda ws_row,x
        tay
        lda ws_col,x
        clc
        adc scr_lo,y
        sta zp_dst
        lda scr_hi,y
        adc #0
        sta zp_dst+1
        lda ws_w,x              ; width in cells
        tax
        ldy #0
        lda bgchar
.cw_r1: sta (zp_dst),y
        iny
        dex
        bne .cw_r1
        ldx tmp2
        lda ws_w,x
        tax
        lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       ldy #0
        lda bgchar
.cw_r2: sta (zp_dst),y
        iny
        dex
        bne .cw_r2
        ldx tmp2
        inx
        cpx wsn
        bne .cw_word
        lda #0
        sta wsn
        sta wactive
        sta poolnext
        ldx #31
-       sta lmap,x
        dex
        bpl -
.cw_done:
        rts

; ---- re-stamp the active words' colour cells (tunnel overwrites them)
!zone
word_recolor:
        lda wsn
        beq .wr_done
        ldx #0
.wr_word:
        stx tmp2
        lda ws_row,x
        tay
        lda ws_col,x
        clc
        adc col_lo,y
        sta zp_dst
        lda col_hi,y
        adc #0
        sta zp_dst+1
        lda ws_colr,x
        sta tmp
        lda ws_w,x
        tax
        ldy #0
        lda tmp
.wr_r1: sta (zp_dst),y
        iny
        dex
        bne .wr_r1
        ldx tmp2
        lda ws_w,x
        tax
        lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       ldy #0
        lda tmp
.wr_r2: sta (zp_dst),y
        iny
        dex
        bne .wr_r2
        ldx tmp2
        inx
        cpx wsn
        bne .wr_word
.wr_done:
        rts

; ---- draw a big word: A = word id, Y = top row ----
!zone
draw_word:
        sty wrow
        tax
        lda word_lo,x
        sta zp_src
        lda word_hi,x
        sta zp_src+1
        lda word_col,x
        sta wcolor
        lda word_len,x
        sta wlen
        lda #20                 ; centred: col = 20 - len
        sec
        sbc wlen
        sta wcol
        ldx wsn                 ; record a word slot for clear/recolour
        cpx #4
        bcs +
        lda wrow
        sta ws_row,x
        lda wcol
        sta ws_col,x
        lda wlen
        asl
        sta ws_w,x
        lda wcolor
        sta ws_colr,x
        inc wsn
+       lda #1
        sta wactive
        lda #0
        sta widx
.dw_loop:
        ldy widx
        lda (zp_src),y
        cmp #$20
        bne .dw_letter
        lda bgchar              ; space -> 2x2 background cells
        sta tmp2
        jsr stamp_cells
        jmp .dw_adv
.dw_letter:
        jsr get_bigletter       ; A = screen code -> A = pool base char
        sta tmp2
        jsr stamp_cells4        ; base..base+3 into the 2x2 block
.dw_adv:
        inc widx
        lda widx
        cmp wlen
        bne .dw_loop
        rts

; zp_dst = SCREEN + wrow*40 + wcol + widx*2
!zone
word_cell_addr:
        ldx wrow
        lda widx
        asl
        clc
        adc wcol
        clc
        adc scr_lo,x
        sta zp_dst
        lda scr_hi,x
        adc #0
        sta zp_dst+1
        rts

; write tmp2 to all 4 cells (spaces), plus colour
!zone
stamp_cells:
        jsr word_cell_addr
        lda tmp2
        ldy #0
        sta (zp_dst),y
        iny
        sta (zp_dst),y
        jsr .down40
        lda tmp2
        ldy #0
        sta (zp_dst),y
        iny
        sta (zp_dst),y
        rts
.down40:
        lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       rts

; write tmp2..tmp2+3 as the 2x2 block + colour the 4 cells
!zone
stamp_cells4:
        jsr word_cell_addr
        lda tmp2
        ldy #0
        sta (zp_dst),y
        iny
        clc
        adc #1
        sta (zp_dst),y
        jsr .sc_down
        lda tmp2
        clc
        adc #2
        ldy #0
        sta (zp_dst),y
        clc
        adc #1
        iny
        sta (zp_dst),y
        ; colours
        ldx wrow
        lda widx
        asl
        clc
        adc wcol
        clc
        adc col_lo,x
        sta zp_dst
        lda col_hi,x
        adc #0
        sta zp_dst+1
        lda wcolor
        ldy #0
        sta (zp_dst),y
        iny
        sta (zp_dst),y
        jsr .sc_down
        lda wcolor
        ldy #0
        sta (zp_dst),y
        iny
        sta (zp_dst),y
        rts
.sc_down:
        lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       rts

; ---- A = screen code (1-31) -> A = base char of its 2x2 expansion ----
;      Expands the ROM glyph into the pool on first use (pixel doubling).
!zone
get_bigletter:
        tax
        lda lmap,x
        beq .gb_new
        rts
.gb_new:
        lda poolnext
        asl
        asl
        clc
        adc #128
        sta lmap,x              ; cache base char for this letter
        pha
        inc poolnext
        ; exp_src = CHARSET + code*8
        lda #0
        sta exp_src+1
        txa
        asl
        rol exp_src+1
        asl
        rol exp_src+1
        asl
        rol exp_src+1
        sta exp_src
        lda exp_src+1
        clc
        adc #>CHARSET
        sta exp_src+1
        ; exp_dst = BIGPOOL + (base-128)*8
        pla
        pha
        sec
        sbc #128
        sta exp_dst
        lda #0
        sta exp_dst+1
        asl exp_dst
        rol exp_dst+1
        asl exp_dst
        rol exp_dst+1
        asl exp_dst
        rol exp_dst+1
        lda exp_dst+1
        clc
        adc #>BIGPOOL
        sta exp_dst+1
        ; TL quadrant: src rows 0-3, high nibble -> dst bytes 0-7
        ldx #0
.gb_tl: txa
        tay
        lda (exp_src),y
        lsr
        lsr
        lsr
        lsr
        tay
        lda nib_exp,y
        pha
        txa
        asl
        tay
        pla
        sta (exp_dst),y
        iny
        sta (exp_dst),y
        inx
        cpx #4
        bne .gb_tl
        ; TR quadrant: src rows 0-3, low nibble -> dst bytes 8-15
        ldx #0
.gb_tr: txa
        tay
        lda (exp_src),y
        and #$0f
        tay
        lda nib_exp,y
        pha
        txa
        asl
        clc
        adc #8
        tay
        pla
        sta (exp_dst),y
        iny
        sta (exp_dst),y
        inx
        cpx #4
        bne .gb_tr
        ; BL quadrant: src rows 4-7, high nibble -> dst bytes 16-23
        ldx #0
.gb_bl: txa
        clc
        adc #4
        tay
        lda (exp_src),y
        lsr
        lsr
        lsr
        lsr
        tay
        lda nib_exp,y
        pha
        txa
        asl
        clc
        adc #16
        tay
        pla
        sta (exp_dst),y
        iny
        sta (exp_dst),y
        inx
        cpx #4
        bne .gb_bl
        ; BR quadrant: src rows 4-7, low nibble -> dst bytes 24-31
        ldx #0
.gb_br: txa
        clc
        adc #4
        tay
        lda (exp_src),y
        and #$0f
        tay
        lda nib_exp,y
        pha
        txa
        asl
        clc
        adc #24
        tay
        pla
        sta (exp_dst),y
        iny
        sta (exp_dst),y
        inx
        cpx #4
        bne .gb_br
        pla                     ; base char
        rts

; ===================================================================
;  Sprite path engine
; ===================================================================
!zone
spr_load_config:
        ldx scnoff
        ldy #0
-       lda scn_mode,x
        sta cur_mode,y
        lda scn_ptr,x
        sta cur_ptr,y
        lda scn_col,x
        sta sh_col,y
        lda scn_vel,x
        sta cur_vel,y
        lda scn_ybase,x
        sta cur_ybase,y
        lda scn_ph,x
        sta cur_ph,y
        lda scn_xin,x
        sta curxlo,y
        lda scn_xinh,x
        sta curxhi,y
        inx
        iny
        cpy #8
        bne -
        ldx scene
        lda scn_en,x
        sta sh_en
        lda scn_mc,x
        sta sh_mc
        lda scn_xe,x
        sta sh_xe
        lda scn_ye,x
        sta sh_ye
        rts

!zone
update_sprites:
        lda #0
        sta sh_msb
        ldx #0
.us:    stx spri
        lda cur_mode,x
        bne +
        jmp .us_next
+       cmp #1
        bne +
        jmp .us_walk
+       cmp #2
        bne +
        jmp .us_liss
+       cmp #3
        bne +
        jmp .us_dance
+       jmp .us_bob

; ---- mode 1: walk/fly across the screen with a sine bob ----
.us_walk:
        lda cur_vel,x
        bmi .wneg
        clc
        adc curxlo,x
        sta curxlo,x
        bcc +
        inc curxhi,x
+       ; wrap at 384
        lda curxhi,x
        cmp #1
        bne .wdone
        lda curxlo,x
        cmp #$80
        bcc .wdone
        sbc #$80
        sta curxlo,x
        lda #0
        sta curxhi,x
        jmp .wdone
.wneg:  clc
        adc curxlo,x
        sta curxlo,x
        bcs .wdone
        dec curxhi,x
        bpl .wdone
        ; went below 0 -> += 384  ($ffxx + $0180)
        lda curxlo,x
        clc
        adc #$80
        sta curxlo,x
        lda curxhi,x
        adc #$01
        sta curxhi,x
.wdone:
        lda curxlo,x
        sta sh_xlo,x
        lda curxhi,x
        and #1
        beq +
        lda sh_msb
        ora bit_tab,x
        sta sh_msb
+       ; y = ybase + bob
        lda frame
        asl
        clc
        adc cur_ph,x
        tay
        lda sine256,y
        lsr
        lsr
        lsr
        lsr
        clc
        adc cur_ybase,x
        sta sh_y,x
        ; animate: base ptr + (frame>>3)&1
        lda frame
        lsr
        lsr
        lsr
        and #1
        clc
        adc cur_ptr,x
        sta sh_ptr,x
        jmp .us_next

; ---- mode 2: lissajous bob (balls) ----
.us_liss:
        lda frame
        clc
        adc cur_ph,x
        tay
        lda sine256,y
        lsr
        sta tmp
        lda sine256,y
        lsr
        lsr
        clc
        adc tmp                 ; sine*0.75 -> 0..191
        clc
        adc #44
        sta sh_xlo,x
        lda frame
        asl
        clc
        adc cur_ph,x
        eor #$80
        tay
        lda sine256,y
        lsr
        clc
        adc #42
        sta sh_y,x
        lda cur_ptr,x
        sta sh_ptr,x
        jmp .us_next

; ---- mode 3: dancer (sways, pose flips on the beat) ----
.us_dance:
        lda frame
        clc
        adc cur_ph,x
        tay
        lda sine256,y
        lsr
        lsr
        lsr
        clc
        adc curxlo,x            ; xin is the base position
        sta sh_xlo,x
        lda cur_ybase,x
        sta sh_y,x
        lda cur_ptr,x
        clc
        adc dpose
        sta sh_ptr,x
        jmp .us_next

; ---- mode 4: gentle bob in place ----
.us_bob:
        lda curxlo,x
        sta sh_xlo,x
        lda frame
        clc
        adc cur_ph,x
        tay
        lda sine256,y
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc cur_ybase,x
        sta sh_y,x
        lda frame
        lsr
        lsr
        lsr
        lsr
        and #1
        clc
        adc cur_ptr,x
        sta sh_ptr,x

.us_next:
        ldx spri
        inx
        cpx #8
        beq +
        jmp .us
+       rts

; ===================================================================
;  Scroller (hardware fine scroll, 2px per frame)
; ===================================================================
!zone
do_scroll:
        dec scrollx
        dec scrollx
        bpl .sc_done
        lda scrollx
        clc
        adc #8
        sta scrollx
        ; shift row 24 one char left
        ldx #0
-       lda SCREEN + SCROLL_ROW*40 + 1,x
        sta SCREEN + SCROLL_ROW*40,x
        inx
        cpx #39
        bne -
        ; next message char (0 = wrap to start of message)
        ldy #0
        lda (msgptr),y
        bne .have
        lda msgid
        cmp #2
        beq .wrapg
        lda #<credits_text
        sta msgptr
        lda #>credits_text
        sta msgptr+1
        jmp .rehave
.wrapg: lda #<greets_text
        sta msgptr
        lda #>greets_text
        sta msgptr+1
.rehave:
        ldy #0
        lda (msgptr),y
.have:  sta SCREEN + SCROLL_ROW*40 + 39
        inc msgptr
        bne +
        inc msgptr+1
+       ; rainbow wash over the scroller row
        ldx #0
.wash:  txa
        clc
        adc frame
        lsr
        lsr
        and #$07
        tay
        lda wash_pal,y
        sta COLRAM + SCROLL_ROW*40,x
        inx
        cpx #40
        bne .wash
.sc_done:
        rts

; ===================================================================
;  Include: the SID driver (song data lives at $2400)
; ===================================================================
        !source "music.asm"
        !source "notes.inc"
        !source "tables.inc"

        !if * > $2000 { !error "code overflows into sprite area" }

; ===================================================================
;  Sprites ($2000) and song data ($2400)
; ===================================================================
        !source "gfx_sprites.inc"

        * = $2400
        !source "music_data.inc"
        !if * > $3000 { !error "music data overflows charset area" }

; ===================================================================
;  Custom charset half ($3400) and generated tables ($3800)
; ===================================================================
        !source "gfx_chars.inc"
        !source "gfx_tables.inc"

; ===================================================================
;  Hand-authored data (follows the generated tables)
; ===================================================================

; ---- screen/colour-RAM row address tables ----
scr_lo:
        !for i, 0, 24 { !byte <(SCREEN + i*40) }
scr_hi:
        !for i, 0, 24 { !byte >(SCREEN + i*40) }
col_lo:
        !for i, 0, 24 { !byte <(COLRAM + i*40) }
col_hi:
        !for i, 0, 24 { !byte >(COLRAM + i*40) }

; ---- palettes / ramps ----
logo_pal    !byte $07,$0a,$08,$02,$04,$0e,$03,$0d
wash_pal    !byte $03,$0e,$04,$0a,$04,$0e,$03,$01
twinkle_pal !byte $01,$0f,$0c,$0b,$0c,$0f,$01,$0b
flash_col   !byte $00,$0b,$0c,$0f,$01,$01

; copper bar glow ramps, 8 bytes each (7 used), 4 bars
bar_ramps
        !byte $06,$0e,$03,$01,$03,$0e,$06,0     ; cyan
        !byte $04,$0a,$0a,$01,$0a,$0a,$04,0     ; hot pink
        !byte $09,$08,$07,$01,$07,$08,$09,0     ; gold
        !byte $05,$0d,$0d,$01,$0d,$0d,$05,0     ; green

; tunnel ring palettes
ringpal     !byte $00,$06,$04,$0a,$01,$0a,$04,$06,$00,$06,$0e,$03,$01,$03,$0e,$06
ringpal_hot !byte $06,$0e,$0a,$01,$01,$01,$0a,$0e,$06,$0e,$03,$01,$01,$01,$03,$0e
ringcur     !fill 16, 0

bit_tab     !byte $01,$02,$04,$08,$10,$20,$40,$80

; ---- nibble -> doubled-bits table for the big-font expander ----
nib_exp !byte $00,$03,$0c,$0f,$30,$33,$3c,$3f
        !byte $c0,$c3,$cc,$cf,$f0,$f3,$fc,$ff

; ---- timeline: scene per bar ----
scene_of_bar
        !byte 0,0,0,0                                           ; intro
        !byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1                   ; verse 1
        !byte 2,2,2,2,2,2,2,2,2,2,2,2,2,2                       ; drop
        !byte 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3                 ; tunnel (34-50)
        !byte 4,4,4,4,4,4,4,4,4,4                               ; finale
        !byte 5,5,5                                             ; outro

; ---- scene vector tables ----
scn_ini_lo !byte <intro_init,<verse_init,<drop_init,<tunnel_init,<finale_init,<outro_init
scn_ini_hi !byte >intro_init,>verse_init,>drop_init,>tunnel_init,>finale_init,>outro_init
scn_upd_lo !byte <intro_update,<verse_update,<drop_update,<tunnel_update,<finale_update,<outro_update
scn_upd_hi !byte >intro_update,>verse_update,>drop_update,>tunnel_update,>finale_update,>outro_update

; ---- word cue list (bar, action) ----
cue_bar !byte 4,  6,  7,  8,  10, 11, 12, 15, 16, 17, 19
        !byte 36, 38, 39, 40, 42, 43, 44, 47, 48, 49
        !byte $ff
cue_act !byte WORD_KATTENE, $fe, WORD_OOHH, WORD_HESTENE, $fe, WORD_OOHH, $fe
        !byte WORD_NEI, WORD_ROMSKIP, WORD_FANTASTISK, $fe
        !byte WORD_KATTENE, $fe, WORD_OOHH, WORD_HESTENE, $fe, WORD_OOHH, $fe
        !byte WORD_NEI, WORD_ROMSKIP, WORD_FANTASTISK

; ---- big words ----
WORD_KATTENE    = 0
WORD_HESTENE    = 1
WORD_OOHH       = 2
WORD_ROMSKIP    = 3
WORD_FANTASTISK = 4
WORD_NEI        = 5
WORD_TAKK       = 6
WORD_MOTORSAG   = 7
WORD_ARKITEKT   = 8

word_lo !byte <w_kat,<w_hest,<w_ooh,<w_rom,<w_fant,<w_nei,<w_takk,<w_mot,<w_ark
word_hi !byte >w_kat,>w_hest,>w_ooh,>w_rom,>w_fant,>w_nei,>w_takk,>w_mot,>w_ark
word_len !byte 7,7,4,7,10,11,10,8,8
word_col !byte $0a,$0a,$03,$0e,$07,$0a,$07,$03,$0a

w_kat   !scr "kattene"
w_hest  !scr "hestene"
w_ooh   !scr "oohh"
w_rom   !scr "romskip"
w_fant  !scr "fantastisk"
w_nei   !scr "nei nei nei"
w_takk  !scr "tusen takk"
w_mot   !scr "motorsag"
w_ark   !scr "arkitekt"

; ---- small texts ----
txt_pres    !scr "presenterer"
            !byte 0
txt_prod    !scr "a claude demoscene production"
            !byte 0
txt_romskip !scr "romskip er fantastisk"
            !byte 0
txt_2026    !scr "kattene * 2026"
            !byte 0

; ---- scroll messages ----
credits_text
        !scr "                                        "
        !scr "motorsag arkitekt ... en kattene produksjon anno 2026 ... "
        !scr "musikk: kim_jensen ... sid-arrangement, pixels og 6510-kode: claude ... "
        !scr "promptmaster: einar ingebrigtsen ... "
        !scr "katter med motorsag - hester paa jakt etter arkitektoppdrag - "
        !scr "og selvfoelgelig: romskip! ...    "
        !byte 0
greets_text
        !scr "                                        "
        !scr "greetings fly out to the legends: "
        !scr "fairlight .. razor 1911 .. the black lotus .. farbrausch .. "
        !scr "cryptoburners .. spaceballs .. melon dezign .. scoopex .. "
        !scr "andromeda .. kefrens .. sanity .. complex .. phenomena .. "
        !scr "anarchy .. lemon. .. ascii .. and you watching this !! "
        !scr "the horses are still looking for architecture assignments ...    "
        !byte 0

; ---- sprite scene configs (8 sprites x 6 scenes) ----
; modes: 0 off, 1 walk, 2 lissajous, 3 dancer, 4 bob in place
scn_mode
        !byte 1,1,0,0,0,0,0,0                   ; intro: 2 ships
        !byte 1,1,1,1,1,1,1,1                   ; verse: 4 cats, 4 horses
        !byte 1,1,1,1,1,1,0,0                   ; drop: 4 ships, 2 cats
        !byte 3,3,2,2,2,2,2,2                   ; tunnel: 2 dancers, 6 bobs
        !byte 1,1,1,1,1,1,2,2                   ; finale: mix + 2 bobs
        !byte 4,4,1,0,0,0,0,0                   ; outro: cat, horse, ship
scn_ptr
        !byte SP_SHIP_A,SP_SHIP_A,0,0,0,0,0,0
        !byte SP_CAT_A,SP_CAT_A,SP_CAT_A,SP_CAT_A,SP_HORSE_A,SP_HORSE_A,SP_HORSE_A,SP_HORSE_A
        !byte SP_SHIP_A,SP_SHIP_A,SP_SHIP_A,SP_SHIP_A,SP_CAT_A,SP_CAT_A,0,0
        !byte SP_DANCER_A,SP_DANCER_A,SP_BALL,SP_BALL,SP_BALL,SP_BALL,SP_BALL,SP_BALL
        !byte SP_SHIP_A,SP_SHIP_A,SP_CAT_A,SP_HORSE_A,SP_CAT_A,SP_HORSE_A,SP_BALL,SP_BALL
        !byte SP_CAT_A,SP_HORSE_A,SP_SHIP_A,0,0,0,0,0
scn_col
        !byte $0f,$0f,0,0,0,0,0,0
        !byte $08,$08,$08,$08,$04,$04,$04,$04
        !byte $0f,$0f,$0f,$0f,$08,$08,0,0
        !byte $00,$00,$07,$0e,$0a,$0d,$01,$08
        !byte $0f,$0f,$08,$04,$08,$04,$07,$0e
        !byte $08,$04,$0f,0,0,0,0,0
scn_vel
        !byte 1,1,0,0,0,0,0,0
        !byte 2,2,2,2,1,1,1,1
        !byte 2,3,2,3,2,2,0,0
        !byte 0,0,0,0,0,0,0,0
        !byte 3,2,2,1,2,1,0,0
        !byte 0,0,1,0,0,0,0,0
scn_ybase
        !byte 70,110,0,0,0,0,0,0
        !byte 185,185,185,185,150,150,150,150
        !byte 58,84,108,72,198,198,0,0
        !byte 110,120,0,0,0,0,0,0
        !byte 60,84,196,166,204,174,0,0
        !byte 190,186,70,0,0,0,0,0
scn_ph
        !byte 0,128,0,0,0,0,0,0
        !byte 0,64,128,192,32,96,160,224
        !byte 0,48,96,144,0,128,0,0
        !byte 0,128,0,64,128,192,32,96
        !byte 0,64,0,96,128,192,160,224
        !byte 0,80,0,0,0,0,0,0
scn_xin
        !byte 30,120,0,0,0,0,0,0
        !byte 10,110,210,54,60,160,4,240
        !byte 20,120,220,64,40,190,0,0
        !byte 110,210,0,0,0,0,0,0
        !byte 20,150,60,160,240,84,0,0
        !byte 80,235,30,0,0,0,0,0
scn_xinh
        !byte 0,0,0,0,0,0,0,0
        !byte 0,0,0,1,0,0,1,0
        !byte 0,0,0,1,0,0,0,0
        !byte 0,0,0,0,0,0,0,0
        !byte 0,0,0,0,0,1,0,0
        !byte 0,0,0,0,0,0,0,0
scn_en  !byte $03,$ff,$3f,$ff,$ff,$07
scn_mc  !byte $03,$ff,$3f,$00,$3f,$07
scn_xe  !byte $00,$00,$00,$03,$00,$00
scn_ye  !byte $00,$00,$00,$03,$00,$00

; ---- runtime state ----
sh_xlo   !fill 8, 0
sh_y     !fill 8, 0
sh_ptr   !fill 8, 0
sh_col   !fill 8, 0
sh_msb   !byte 0
sh_en    !byte 0
sh_mc    !byte 0
sh_xe    !byte 0
sh_ye    !byte 0
cur_mode !fill 8, 0
cur_ptr  !fill 8, 0
cur_vel  !fill 8, 0
cur_ybase !fill 8, 0
cur_ph   !fill 8, 0
lmap     !fill 32, 0            ; letter -> big-font base char
ws_row   !fill 4, 0             ; active word slots (row/col/width/colour)
ws_col   !fill 4, 0
ws_w     !fill 4, 0
ws_colr  !fill 4, 0
split_col !fill 48, 0
