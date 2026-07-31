; ===================================================================
;  M O T O R S A G   A R K I T E K T   -   C 6 4   D E M O
; -------------------------------------------------------------------
;  A classic-style C64 demo: full-screen animated copper bars,
;  a colour-cycling text logo, eight bobbing hardware sprites
;  (spaceships & cats) and a smooth sine-washed hardware scroller,
;  all driven by an original 3-voice SID rendition of
;  "Motorsag Arkitekt".
;
;  Assemble with ACME:   acme motorsag.asm   ->  motorsag.prg
;  Run:                  x64sc motorsag.prg  (LOAD"*",8,1 : RUN on real HW)
;
;  PAL C64.  Everything runs from a chained raster interrupt.
; ===================================================================

        !to "motorsag.prg", cbm

; ---- hardware ----
VIC   = $d000
CIA1  = $dc00
CIA2  = $dd00
SCREEN  = $0400
COLRAM  = $d800
SPRPTR  = SCREEN + $3f8

; ---- zero page (demo side; player uses $f8-$fe) ----
zp_src = $02
zp_dst = $04
scrollx = $06           ; current fine scroll (0..7)
tmp     = $07
msgptr  = $08           ; 16-bit pointer into the scroll message

; ---- tunables ----
NBARS   = 48            ; number of copper-bar raster splits
BAR_TOP = 54            ; first bar raster line
BAR_STEP = 4            ; lines between bar splits
SCROLL_ROW = 24         ; text row used for the scroller

; ===================================================================
;  BASIC stub:  2026 SYS 2064
; ===================================================================
        * = $0801
        !byte $0b,$08,$e2,$07,$9e,$32,$30,$36,$34,$00,$00,$00

        * = $0810
; -------------------------------------------------------------------
;  Cold start
; -------------------------------------------------------------------
start:
        sei
        lda #$35                ; RAM under KERNAL/BASIC I/O; keep I/O in
        sta $01

        jsr init_vic
        jsr clear_screen
        jsr draw_logo
        jsr init_sprites

        ; initialise the 16-bit scroll pointer
        lda #<scrolltext
        sta msgptr
        lda #>scrolltext
        sta msgptr+1

        jsr music_init

        jsr init_irq

        cli
.idle:  jmp .idle               ; everything happens in the IRQ

; ===================================================================
;  VIC / screen setup
; ===================================================================
init_vic:
        lda #$00
        sta VIC+$20             ; border black
        sta VIC+$21             ; background black
        ; standard text mode, 25 rows, screen $0400 chars $1000 (ROM upper)
        lda #$1b
        sta VIC+$11
        lda #$c8                ; 40 cols, xscroll 0
        sta VIC+$16
        lda #$15                ; screen $0400, charset $1000
        sta VIC+$18
        ; VIC bank 0
        lda CIA2+0
        ora #$03
        sta CIA2+0
        rts

clear_screen:
        ldx #0
        lda #$20                ; space
.cs:
        sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        inx
        bne .cs
        ; colour RAM -> light grey (mostly hidden; logo/scroller recolour)
        ldx #0
        lda #$0b
.cc:
        sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$300,x
        inx
        bne .cc
        rts

; ===================================================================
;  Logo : three centred text lines near the top
; ===================================================================
draw_logo:
        ; line 1 (row 2)  ->  "M O T O R S A G"
        ldx #0
.l1:    lda logo1,x
        beq .l1d
        sta SCREEN + 2*40 + 12, x
        lda #$07                ; yellow
        sta COLRAM + 2*40 + 12, x
        inx
        bne .l1
.l1d:
        ldx #0
.l2:    lda logo2,x
        beq .l2d
        sta SCREEN + 4*40 + 11, x
        lda #$03                ; cyan
        sta COLRAM + 4*40 + 11, x
        inx
        bne .l2
.l2d:
        ldx #0
.l3:    lda logo3,x
        beq .l3d
        sta SCREEN + 6*40 + 10, x
        lda #$0e                ; light blue
        sta COLRAM + 6*40 + 10, x
        inx
        bne .l3
.l3d:
        ; sub line (row 8)
        ldx #0
.l4:    lda logo4,x
        beq .l4d
        sta SCREEN + 8*40 + 8, x
        lda #$0f
        sta COLRAM + 8*40 + 8, x
        inx
        bne .l4
.l4d:
        rts

; screen codes: letters A-Z = 1..26, space = 32
logo1:  !scr "motorsag"
        !byte 0
logo2:  !scr "arkitekt"
        !byte 0
logo3:  !scr "kattene presenterer"
        !byte 0
logo4:  !scr "a claude demoscene production"
        !byte 0

; ===================================================================
;  Sprites : 8 hardware sprites (4 ships, 4 cats) bobbing on sines
; ===================================================================
init_sprites:
        ; sprite pointers: even=ship, odd=cat
        lda #(spr_ship / 64)
        sta SPRPTR+0
        sta SPRPTR+2
        sta SPRPTR+4
        sta SPRPTR+6
        lda #(spr_cat / 64)
        sta SPRPTR+1
        sta SPRPTR+3
        sta SPRPTR+5
        sta SPRPTR+7
        ; colours (synthwave-ish): ships cyan, cats pink
        ldx #0
.sc:
        lda spr_col,x
        sta VIC+$27,x
        inx
        cpx #8
        bne .sc
        ; enable all 8, hi-res, no expand
        lda #$ff
        sta VIC+$15             ; enable
        lda #$00
        sta VIC+$17             ; y-expand off
        sta VIC+$1d             ; x-expand off
        sta VIC+$1c             ; multicolor off (hi-res)
        rts

spr_col: !byte $03,$04, $0e,$0a, $03,$04, $0e,$0a   ; cyan/pink pairs

; ===================================================================
;  Copper-bar palette ring : several soft "bars", each ramping through
;  the C64 palette from dark to bright and back -> reads as glowing
;  bars.  A window of NBARS is copied into the live bar_col table
;  (scrolled one step per frame) that the raster IRQs read.
; ===================================================================
; The source ring: several soft "bars", each ramping through the
; C64 palette from dark to bright and back -> reads as glowing bars.
BARRING_LEN = 64
bar_ring:
        ; bar A (blue family)
        !byte $06,$06,$0e,$0e,$03,$03,$0d,$01
        ; bar B (purple/pink)
        !byte $06,$04,$04,$0a,$0a,$0f,$07,$01
        ; bar C (cyan)
        !byte $00,$06,$0e,$03,$03,$0d,$0f,$01
        ; bar D (magenta)
        !byte $00,$04,$04,$02,$0a,$0a,$0f,$01
        ; bar E (green-cyan)
        !byte $00,$06,$0e,$05,$03,$0d,$0f,$01
        ; bar F (orange sunset)
        !byte $00,$09,$08,$08,$0a,$07,$0f,$01
        ; bar G (blue)
        !byte $00,$06,$06,$0e,$03,$0e,$0d,$01
        ; bar H (pink)
        !byte $00,$04,$0a,$0a,$0f,$0a,$04,$01

; ===================================================================
;  Raster interrupt setup
; ===================================================================
init_irq:
        ; full takeover: KERNAL is banked out, so use the hardware
        ; vectors at $fffe/$ffff (IRQ) and $fffa/$fffb (NMI, -> rti).
        lda #<irq_main
        sta $fffe
        lda #>irq_main
        sta $ffff
        lda #<nmi_rti
        sta $fffa
        lda #>nmi_rti
        sta $fffb
        ; disable CIA timer IRQs, enable raster IRQ
        lda #$7f
        sta CIA1+$0d
        sta CIA2+$0d
        lda CIA1+$0d            ; ack pending CIA irqs
        lda CIA2+$0d
        lda #$01
        sta VIC+$1a             ; enable raster irq
        lda #$1b
        sta VIC+$11             ; high bit of raster = 0
        lda #250
        sta VIC+$12             ; first irq at line 250 (main/vblank work)
        lda #$ff
        sta VIC+$19             ; ack any pending
        rts

nmi_rti:
        rti

; ===================================================================
;  MAIN raster IRQ (line 250, lower border): heavy per-frame work,
;  then hand off to the first copper-bar split.
; ===================================================================
irq_main:
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta VIC+$19             ; ack raster irq

        jsr music_play          ; advance the SID tune (once per frame)
        jsr frame_logic         ; scroll, sprites, palette, flashes

        ; reset fine scroll for the top of screen (only scroller row scrolls)
        lda #$c8
        sta VIC+$16

        ; program first bar split
        lda #0
        sta bar_idx
        lda #BAR_TOP
        sta VIC+$12
        lda #<irq_bar
        sta $fffe
        lda #>irq_bar
        sta $ffff

        pla
        tay
        pla
        tax
        pla
        rti

; ===================================================================
;  BAR raster IRQ : set background to this bar's colour, advance to
;  the next split.  On the scroller row, switch on fine scroll.
; ===================================================================
irq_bar:
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta VIC+$19

        ldx bar_idx
        lda bar_col,x
        sta VIC+$21             ; background = bar colour

        inx
        cpx #NBARS
        bcs .last
        stx bar_idx
        ; next split line = BAR_TOP + idx*BAR_STEP
        txa
        asl                     ; *2
        asl                     ; *4  (BAR_STEP)
        clc
        adc #BAR_TOP
        sta VIC+$12
        pla
        tay
        pla
        tax
        pla
        rti

.last:
        ; last bar sits on the scroller row: switch on fine scroll for
        ; row 24 only, then hand back to MAIN at line 250.
        lda scrollx
        ora #$c0                ; 38-col + low3 = fine scroll
        sta VIC+$16
        lda #250
        sta VIC+$12
        lda #<irq_main
        sta $fffe
        lda #>irq_main
        sta $ffff
        pla
        tay
        pla
        tax
        pla
        rti

; ===================================================================
;  Per-frame logic (runs inside MAIN irq)
; ===================================================================
frame_logic:
        inc frame
        ; ---- rotate the copper-bar window one step each frame ----
        jsr scroll_bars
        ; ---- colour-cycle the logo ----
        jsr cycle_logo
        ; ---- move sprites ----
        jsr move_sprites
        ; ---- advance the text scroller ----
        jsr do_scroll
        ; ---- backbeat flash on the border (multi-frame decay) ----
        lda beat_flag
        beq +
        lda #0
        sta beat_flag
        lda #5
        sta flash               ; start a 5-frame flash
+       ldx flash
        lda flash_col,x
        sta VIC+$20             ; border colour follows the decay ramp
        lda flash
        beq +
        dec flash
+       rts

; flash decay ramp indexed by the flash counter (0 = black border)
flash_col: !byte $00,$0b,$0c,$0f,$01,$01

; ---- copy an NBARS window out of the ring, at a moving offset ----
scroll_bars:
        inc bar_scroll
        ldx #0
.bs:
        txa
        clc
        adc bar_scroll
        and #(BARRING_LEN-1)
        tay
        lda bar_ring,y
        sta bar_col,x
        inx
        cpx #NBARS
        bne .bs
        rts

; ---- roll a moving rainbow across the two title rows ----
cycle_logo:
        lda frame
        lsr                     ; slow the roll to half speed
        sta tmp
        ldx #0
.cl:
        txa
        clc
        adc tmp
        and #$07
        tay
        lda logo_pal,y
        sta COLRAM + 2*40 + 12, x   ; "motorsag" (row 2)
        sta COLRAM + 4*40 + 11, x   ; "arkitekt" (row 4)
        inx
        cpx #8
        bne .cl
        rts

logo_pal: !byte $07,$0a,$08,$02,$04,$0e,$03,$0d

; ---- sprite motion : per-sprite Y bob + slight X sway on sines ----
move_sprites:
        ldx #0                  ; X = sprite index 0..7
.ms:
        ; --- horizontal sway (0..15) added to 9-bit base X ---
        lda frame
        clc
        adc sprxphase,x
        tay
        lda sine256,y
        lsr
        lsr
        lsr
        lsr                     ; 0..15
        clc
        adc basex_lo,x
        sta sx_lo
        lda basex_hi,x
        adc #0
        sta sx_msb              ; 0 or 1
        ; --- vertical bob (96..159) ---
        lda frame
        asl                     ; frame*2 mod 256
        clc
        adc spryphase,x
        tay
        lda sine256,y
        lsr
        lsr                     ; 0..63
        clc
        adc #96
        sta sy
        ; --- write X/Y to the sprite registers (offset = 2*i) ---
        txa
        asl
        tay                     ; Y = 2*i
        lda sx_lo
        sta VIC+0,y             ; $d000 + 2i
        lda sy
        sta VIC+1,y             ; $d001 + 2i
        ; --- X MSB bit for this sprite ---
        lda sx_msb
        beq .clrmsb
        lda VIC+$10
        ora bit_tab,x
        sta VIC+$10
        jmp .nxt
.clrmsb:
        lda VIC+$10
        and inv_bit_tab,x
        sta VIC+$10
.nxt:
        inx
        cpx #8
        bne .ms
        rts

; ---- text scroller (hardware fine + char shift on wrap) ----
do_scroll:
        dec scrollx
        bpl .sd
        lda #7
        sta scrollx
        ; shift scroller row left by one char
        ldx #0
.shift:
        lda SCREEN + SCROLL_ROW*40 + 1, x
        sta SCREEN + SCROLL_ROW*40 + 0, x
        inx
        cpx #39
        bne .shift
        ; pull next char from the message into column 39 (16-bit ptr)
        ldy #0
        lda (msgptr),y
        bne +
        ; hit terminator -> rewind to start of message
        lda #<scrolltext
        sta msgptr
        lda #>scrolltext
        sta msgptr+1
        ldy #0
        lda (msgptr),y
+       sta SCREEN + SCROLL_ROW*40 + 39
        ; advance pointer
        inc msgptr
        bne +
        inc msgptr+1
+       ; colour wash the scroller row
        jsr wash_scroller
.sd:
        rts

; give the scroller row a moving rainbow
wash_scroller:
        ldx #0
.ws:
        txa
        clc
        adc frame
        lsr
        and #$07
        tay
        lda wash_pal,y
        sta COLRAM + SCROLL_ROW*40, x
        inx
        cpx #40
        bne .ws
        rts

wash_pal: !byte $03,$0e,$0d,$05,$0d,$0e,$03,$01

; ===================================================================
;  Variables
; ===================================================================
frame       !byte 0
bar_idx     !byte 0
bar_scroll  !byte 0
flash       !byte 0
sx_lo       !byte 0
sx_msb      !byte 0
sy          !byte 0

; live bar colour table (one per split)
bar_col:    !fill NBARS, 0

; per-sprite base X (9-bit split) and sine phases
basex_lo:   !byte  30, 66,102,138,174,210,246, 26
basex_hi:   !byte   0,  0,  0,  0,  0,  0,  0,  1
sprxphase:  !byte   0, 32, 64, 96,128,160,192,224
spryphase:  !byte   0, 40, 80,120,160,200,240, 20
bit_tab:    !byte $01,$02,$04,$08,$10,$20,$40,$80
inv_bit_tab:!byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

; ===================================================================
;  Scroll message
; ===================================================================
scrolltext:
        !scr "                    "
        !scr "motorsag arkitekt ... a kattene production anno 2026 ... "
        !scr "original sid score, copper bars, sprites and code hammered out in 6510 assembly ... "
        !scr "greetings to all sceners everywhere - the horses are still looking for architecture gigs ... "
        !scr "and remember: romskip er fantastisk !!!        "
        !byte 0

; ===================================================================
;  Includes : note table, sine tables, sprite bitmaps, SID player
; ===================================================================
        !source "notes.inc"
        !source "tables.inc"
        !source "music.asm"

; -------------------------------------------------------------------
;  Sprite bitmaps live at a 64-byte boundary that the VIC can see
;  (outside the $1000-$1fff character-ROM shadow).  $2000 = block 128.
; -------------------------------------------------------------------
        * = $2000
        !source "sprites.inc"
