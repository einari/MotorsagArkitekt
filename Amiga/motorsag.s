; ===================================================================
;  M O T O R S A G   A R K I T E K T   -   A M I G A   5 0 0
; -------------------------------------------------------------------
;  OCS/PAL version of the Kattene demo.  Plays the identical 64-bar
;  score as the C64 port (93 frames per bar = 129.03 BPM) on Paula:
;
;    ch0  octave-jumping bass          ch2  the sung lead melody
;    ch1  chord arpeggios              ch3  drums + the REAL VOCALS
;                                           (8-bit Paula samples!)
;
;  Visuals: one-bitplane title screen with copper-driven colours -
;  the timeline patches 64 colour slots per frame (sine-bobbing
;  copper bars, sunset + rushing grid lines, breathing tunnel rings,
;  rainbow finale) plus a 32px-tall hardware-scrolled text scroller.
;
;  Assemble:  vasmm68k_mot -Fhunkexe -kick1hunks -o motorsag motorsag.s
;  Run: from CLI/Workbench on any PAL A500 (takes the machine over).
; ===================================================================

CUSTOM   = $dff000
DMACONR  = $002
VPOSR    = $004
COP1LC   = $080
COPJMP1  = $088
DIWSTRT  = $08e
DMACON   = $096
INTENA   = $09a
INTREQ   = $09c
AUD0     = $0a0                 ; +$10 per channel; LC+0 LEN+4 PER+6 VOL+8

FRAMES_PER_BAR = 93

; ---- per-channel player state ----
CH_PTR    = 0                   ; .l  stream position
CH_BASE   = 4                   ; .l  stream start (for looping)
CH_WAIT   = 8                   ; .w
CH_ARPN   = 10                  ; .w  number of periods to cycle (1 or 4)
CH_ARPI   = 12                  ; .w
CH_PERS   = 14                  ; 4 .w
CH_INST   = 22                  ; .w
CH_TRIG   = 24                  ; .w
CH_1SHOT  = 26                  ; .w  point at silence next frame
CH_SIZE   = 28

; instrument table entry (generated): ptr.l, len_words.w, period.w,
; vol.w, oneshot.w
IN_PTR = 0
IN_LEN = 4
IN_PER = 6
IN_VOL = 8
IN_1SH = 10
IN_SIZE = 12

        section code,code

; ===================================================================
;  Takeover + init
; ===================================================================
start:
        lea     CUSTOM,a6
        move.w  #$7fff,INTENA(a6)
        move.w  #$7fff,INTREQ(a6)
        move.w  #$7fff,INTREQ(a6)
        move.w  #$07ff,DMACON(a6)       ; all DMA off

        ; point the copper list's bitplane pointer at the logo screen
        lea     coplist,a0
        move.l  #logo,d0
        move.w  d0,COPOFF_BPL+4(a0)     ; low word
        swap    d0
        move.w  d0,COPOFF_BPL(a0)       ; high word

        ; silence all four channels before enabling audio DMA
        moveq   #3,d0
        lea     AUD0(a6),a1
.sil:   move.l  #silence,(a1)           ; AUDxLC
        move.w  #1,4(a1)                ; AUDxLEN
        move.w  #200,6(a1)              ; AUDxPER
        move.w  #0,8(a1)                ; AUDxVOL
        lea     $10(a1),a1
        dbra    d0,.sil

        move.l  #coplist,COP1LC(a6)
        move.w  d0,COPJMP1(a6)          ; strobe
        move.w  #$8780,DMACON(a6)       ; SET+DMAEN+BPLEN+COPEN
        move.w  #$800f,DMACON(a6)       ; audio DMA on (silent loops)

        bsr     music_init
        clr.w   frame
        clr.w   fr_bar
        clr.w   bar
        clr.w   gphase
        clr.w   scrphase
        clr.w   scrhalf
        clr.w   scridx

; ===================================================================
;  Main loop: one tick per vertical blank
; ===================================================================
main:
        bsr     wait_vb
        bsr     music_tick
        bsr     scene_tick
        bsr     scroll_tick
        addq.w  #1,frame
        bra     main

wait_vb:
.w:     move.l  VPOSR(a6),d0
        and.l   #$1ff00,d0
        cmp.l   #303<<8,d0
        bne.s   .w
        rts

; ===================================================================
;  Music: 4 event streams, one fetch/effect pass per frame
; ===================================================================
music_init:
        lea     chans,a2
        lea     streams,a3
        moveq   #3,d6
.mi:    move.l  (a3)+,d0
        move.l  d0,CH_PTR(a2)
        move.l  d0,CH_BASE(a2)
        move.w  #1,CH_WAIT(a2)
        move.w  #1,CH_ARPN(a2)
        clr.w   CH_ARPI(a2)
        clr.w   CH_TRIG(a2)
        clr.w   CH_1SHOT(a2)
        lea     CH_SIZE(a2),a2
        dbra    d6,.mi
        rts

music_tick:
        ; ---- bar / song position ----
        addq.w  #1,fr_bar
        cmp.w   #FRAMES_PER_BAR,fr_bar
        blt.s   .nobar
        clr.w   fr_bar
        addq.w  #1,bar
        cmp.w   #64,bar
        blt.s   .nobar
        clr.w   bar
        bsr     music_init              ; loop the whole show
.nobar:
        ; ---- oneshot cleanup: samples fall into the silence loop ----
        lea     chans,a2
        moveq   #0,d6
.osl:   tst.w   CH_1SHOT(a2)
        beq.s   .osn
        clr.w   CH_1SHOT(a2)
        bsr     ch_regs                 ; a5 = AUDx base
        move.l  #silence,(a5)
        move.w  #1,4(a5)
.osn:   lea     CH_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .osl

        ; ---- advance each channel ----
        clr.w   trigmask
        lea     chans,a2
        moveq   #0,d6
.chl:   bsr     proc_ch
        lea     CH_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .chl

        ; ---- apply triggers (batch: DMA off, set regs, DMA on) ----
        move.w  trigmask,d0
        beq.s   .done
        move.w  d0,DMACON(a6)           ; stop the retriggered channels
        lea     chans,a2
        moveq   #0,d6
.trl:   tst.w   CH_TRIG(a2)
        beq.s   .trn
        clr.w   CH_TRIG(a2)
        bsr     trig_ch
.trn:   lea     CH_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .trl
        move.w  #250,d1                 ; let Paula fetch the silence
.dly:   dbra    d1,.dly
        move.w  trigmask,d0
        or.w    #$8000,d0
        move.w  d0,DMACON(a6)           ; restart
.done:  rts

; a5 = custom audio register base for channel d6
ch_regs:
        move.w  d6,d1
        lsl.w   #4,d1
        lea     AUD0(a6),a5
        adda.w  d1,a5
        rts

; ---- advance channel d6 (state in a2) ----
proc_ch:
        subq.w  #1,CH_WAIT(a2)
        bgt     .fx
.fetch: move.l  CH_PTR(a2),a3
        moveq   #0,d0
        move.b  (a3)+,d0
        cmp.b   #$ff,d0
        bne.s   .notend
        move.l  CH_BASE(a2),a3          ; loop this stream
        bra     .fetch2
.notend:
        cmp.b   #0,d0
        bne.s   .nrest
        ; rest: volume off
        moveq   #0,d1
        move.b  (a3)+,d1
        move.w  d1,CH_WAIT(a2)
        bsr     ch_regs
        move.w  #0,8(a5)
        bra.s   .store
.nrest: cmp.b   #2,d0
        bne.s   .ntie
        moveq   #0,d1
        move.b  (a3)+,d1
        move.w  d1,CH_WAIT(a2)
        bra.s   .store
.ntie:  ; note (1) / arpnote (3) / oneshot (4)
        move.w  d0,d5
        moveq   #0,d1
        move.b  (a3)+,d1
        move.w  d1,CH_INST(a2)
        moveq   #0,d1
        move.b  (a3)+,d1
        move.w  d1,CH_WAIT(a2)
        move.w  #1,CH_ARPN(a2)
        clr.w   CH_ARPI(a2)
        cmp.w   #4,d5
        beq.s   .trig                   ; oneshot: period from the table
        ; read one or four big-endian period words
        moveq   #0,d2
        cmp.w   #3,d5
        bne.s   .one
        move.w  #4,CH_ARPN(a2)
        moveq   #3,d3
.arpl:  bsr.s   .rdword
        move.w  d1,CH_PERS(a2,d2.w)
        addq.w  #2,d2
        dbra    d3,.arpl
        bra.s   .trig
.one:   bsr.s   .rdword
        move.w  d1,CH_PERS(a2)
.trig:  move.w  #1,CH_TRIG(a2)
        moveq   #0,d1
        move.w  d6,d1
        moveq   #0,d2
        bset    d1,d2
        or.w    d2,trigmask
.store: move.l  a3,CH_PTR(a2)
        rts
.fetch2:
        move.l  a3,CH_PTR(a2)
        bra     .fetch
.rdword:
        moveq   #0,d1
        move.b  (a3)+,d1
        lsl.w   #8,d1
        move.b  (a3)+,d1
        rts
.fx:    ; sounding: cycle the arpeggio periods
        move.w  CH_ARPN(a2),d1
        cmp.w   #1,d1
        beq.s   .fxd
        move.w  CH_ARPI(a2),d2
        addq.w  #1,d2
        cmp.w   d1,d2
        blt.s   .fxi
        moveq   #0,d2
.fxi:   move.w  d2,CH_ARPI(a2)
        add.w   d2,d2
        move.w  CH_PERS(a2,d2.w),d1
        bsr     ch_regs
        move.w  d1,6(a5)
.fxd:   rts

; ---- program Paula for a (re)triggered channel d6 ----
trig_ch:
        move.w  CH_INST(a2),d1
        mulu    #IN_SIZE,d1
        lea     insts,a1
        adda.l  d1,a1
        bsr     ch_regs
        move.l  IN_PTR(a1),(a5)         ; AUDxLC
        move.w  IN_LEN(a1),4(a5)        ; AUDxLEN
        move.w  IN_PER(a1),d1
        tst.w   IN_1SH(a1)
        beq.s   .melodic
        move.w  d1,6(a5)                ; sample: fixed period
        move.w  #1,CH_1SHOT(a2)
        bra.s   .vol
.melodic:
        move.w  CH_PERS(a2),6(a5)
.vol:   move.w  IN_VOL(a1),8(a5)
        rts

; ===================================================================
;  Scenes: build the 64-slot colour shadow, copy it into the copper
; ===================================================================
scene_tick:
        move.w  bar,d0
        lea     scene_of_bar,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        add.w   d1,d1
        lea     scene_tab,a0
        move.w  (a0,d1.w),d1
        lea     scene_tab,a0
        jsr     (a0,d1.w)
        bsr     copy_shadow
        bsr     text_colours
        rts

scene_tab:
        dc.w    sc_intro-scene_tab
        dc.w    sc_verse-scene_tab
        dc.w    sc_drop-scene_tab
        dc.w    sc_tunnel-scene_tab
        dc.w    sc_finale-scene_tab
        dc.w    sc_outro-scene_tab

; ---- intro / outro: black backdrop ----
sc_intro:
sc_outro:
        lea     shadow,a0
        moveq   #31,d0
.c:     clr.l   (a0)+
        dbra    d0,.c
        rts

; ---- verse: four sine-bobbing copper bars ----
sc_verse:
        bsr     sc_intro                ; clear first
        lea     shadow,a0
        lea     sine64,a1
        moveq   #0,d5                   ; bar number 0-3
.bar:   move.w  frame,d0
        cmp.w   #2,d5
        blt.s   .slow
        add.w   d0,d0
.slow:  move.w  d5,d1
        lsl.w   #4,d1
        add.w   d1,d0
        and.w   #63,d0
        moveq   #0,d1
        move.b  (a1,d0.w),d1            ; centre slot 3..38
        subq.w  #3,d1
        add.w   d1,d1                   ; word offset
        lea     ramp_cyan,a3
        move.w  d5,d2
        lsl.w   #4,d2                   ; ramp stride is 16 bytes
        adda.w  d2,a3
        lea     shadow,a2
        adda.w  d1,a2
        moveq   #6,d2
.rmp:   move.w  (a3)+,(a2)+
        dbra    d2,.rmp
        addq.w  #1,d5
        cmp.w   #4,d5
        bne.s   .bar
        rts

; ---- drop: sunset sky + accelerating grid lines ----
sc_drop:
        lea     shadow,a0
        lea     sky_grad,a1
        moveq   #25,d0
.sky:   move.w  (a1)+,(a0)+
        dbra    d0,.sky
        bsr     grid_ground
        rts

grid_ground:
        addq.w  #1,gphase
        cmp.w   #96,gphase
        blt.s   .ok
        clr.w   gphase
.ok:    move.w  gphase,d0
        mulu    #38*2,d0
        lea     grid_anim,a1
        adda.l  d0,a1
        lea     shadow+26*2,a0
        moveq   #37,d0
.g:     move.w  (a1)+,(a0)+
        dbra    d0,.g
        rts

; ---- tunnel: breathing ring colours (pre-generated phases) ----
sc_tunnel:
        addq.w  #1,gphase
        cmp.w   #96,gphase
        blt.s   .ok
        clr.w   gphase
.ok:    move.w  gphase,d0
        lsl.w   #7,d0                   ; *128 bytes per phase
        lea     tunnel_anim,a1
        adda.l  d0,a1
        lea     shadow,a0
        moveq   #63,d0
.t:     move.w  (a1)+,(a0)+
        dbra    d0,.t
        rts

; ---- finale: rolling rainbow sky over the grid ----
sc_finale:
        lea     shadow,a0
        lea     rainbow32,a1
        move.w  frame,d2
        lsr.w   #1,d2
        moveq   #0,d0
.f:     move.w  d0,d1
        add.w   d2,d1
        and.w   #31,d1
        add.w   d1,d1
        move.w  (a1,d1.w),(a0)+
        addq.w  #1,d0
        cmp.w   #26,d0
        bne.s   .f
        bsr     grid_ground
        rts

; ---- write the shadow into the copper list via the offset table ----
copy_shadow:
        lea     shadow,a0
        lea     copoff_c00,a1
        lea     coplist,a2
        moveq   #63,d0
.l:     move.w  (a1)+,d1
        move.w  (a0)+,(a2,d1.w)
        dbra    d0,.l
        rts

; ---- rainbow-cycle the text colour slots ----
text_colours:
        lea     copoff_c01,a1
        lea     coplist,a2
        lea     rainbow32,a3
        move.w  frame,d2
        lsr.w   #2,d2
        moveq   #0,d0
.l:     move.w  d0,d1
        add.w   d2,d1
        and.w   #31,d1
        add.w   d1,d1
        move.w  (a3,d1.w),d1
        move.w  (a1)+,d3
        move.w  d1,(a2,d3.w)
        addq.w  #1,d0
        cmp.w   #9,d0
        bne.s   .l
        rts

; ===================================================================
;  The big scroller: 32px letters, hardware fine scroll via BPLCON1
; ===================================================================
scroll_tick:
        move.w  scrphase,d0
        addq.w  #1,d0
        cmp.w   #8,d0
        blt.s   .fine
        ; coarse step: shift the band 16px left, feed a glyph half
        clr.w   d0
        bsr     band_shift
        bsr     band_feed
.fine:  move.w  d0,scrphase
        ; BPLCON1 value: 14,12,10,...,0 across the 8 phases
        moveq   #7,d1
        sub.w   d0,d1
        add.w   d1,d1
        move.w  d1,d2
        lsl.w   #4,d2
        or.w    d2,d1
        lea     coplist,a2
        move.w  d1,COPOFF_SCR(a2)
        rts

band_shift:
        lea     logo+200*40,a0
        moveq   #31,d1
.row:   moveq   #18,d2
        move.l  a0,a1
.w:     move.w  2(a1),(a1)+
        dbra    d2,.w
        clr.w   (a1)
        lea     40(a0),a0
        dbra    d1,.row
        rts

band_feed:
        ; glyph half -> rightmost 2 bytes of each band row
        lea     scrolltext,a0
        move.w  scridx,d1
        moveq   #0,d2
        move.b  (a0,d1.w),d2
        cmp.b   #$ff,d2
        bne.s   .ok
        clr.w   scridx
        clr.w   scrhalf
        moveq   #0,d1
        move.b  (a0),d2
.ok:    lsl.w   #7,d2                   ; glyph * 128 bytes
        lea     bigfont,a1
        adda.l  d2,a1
        move.w  scrhalf,d3
        beq.s   .h0
        lea     64(a1),a1
.h0:    lea     logo+200*40+38,a2
        moveq   #31,d4
.row:   move.b  (a1)+,(a2)
        move.b  (a1)+,1(a2)
        lea     40(a2),a2
        dbra    d4,.row
        ; advance half / character
        move.w  scrhalf,d3
        eor.w   #1,d3
        move.w  d3,scrhalf
        tst.w   d3
        bne.s   .done
        addq.w  #1,scridx
.done:  rts

; ===================================================================
;  Variables (fast RAM)
; ===================================================================
frame:    dc.w 0
fr_bar:   dc.w 0
bar:      dc.w 0
gphase:   dc.w 0
scrphase: dc.w 0
scrhalf:  dc.w 0
scridx:   dc.w 0
trigmask: dc.w 0
chans:    ds.b CH_SIZE*4
shadow:   ds.w 64

streams:
        dc.l stream0,stream1,stream2,stream3

; ===================================================================
;  Chip data: copper list, tables, samples, the screen
; ===================================================================
        section chip,data_c

silence: dc.w 0,0

        include "amiga_data.i"

samples:
        incbin  "samples.raw"
        even
logo:
        incbin  "logo.raw"
        even
