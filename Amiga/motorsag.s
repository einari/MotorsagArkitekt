; ===================================================================
;  M O T O R S A G   A R K I T E K T   -   A M I G A   5 0 0   v 2
; -------------------------------------------------------------------
;  OCS/PAL.  The music is a real SoundTracker module (motorsag.mod,
;  ST-01 instruments + the sung vocals as samples) played by a
;  ProTracker-subset replayer; the visual timeline is driven by the
;  replayer's song position.
;
;  Visuals: 3 bitplanes.
;    plane 0  scale4x title screen + starfield + the DYCP scroller
;             (letters bounce on their own sines, blitter-drawn)
;    plane 1+2  the cast: chainsaw cats / architect horses / dancers /
;             magic circles as blitter bobs, and in the drop scene the
;             spaceships as CPU-outlined, blitter-FILLED vector
;             polygons (XOR parity gives them cockpit holes)
;  Copper: 64 background colour slots (bars / sunset+grid / tunnel /
;  rainbow), a 44-step gradient rolling through the title letters, and
;  per-scene palettes for the cast planes.
;
;  Assemble:  vasmm68k_mot -Fhunkexe -kick1hunks -o motorsag motorsag.s
; ===================================================================

CUSTOM   = $dff000
VPOSR    = $004
DMACONR  = $002
BLTCON0  = $040
BLTCON1  = $042
BLTAFWM  = $044
BLTALWM  = $046
BLTCPTH  = $048
BLTBPTH  = $04c
BLTAPTH  = $050
BLTDPTH  = $054
BLTSIZE  = $058
BLTCMOD  = $060
BLTBMOD  = $062
BLTAMOD  = $064
BLTDMOD  = $066
BLTADAT  = $074
COP1LC   = $080
COPJMP1  = $088
DMACON   = $096
INTENA   = $09a
INTREQ   = $09c
AUD0     = $0a0

PLANEB   = 44                   ; bytes per row (352 px: 32 hidden spill
                                ;  pixels so blits can enter from the right)
ROWS_PER_BAR = 16

; ---- replayer channel state ----
MC_SMP    = 0                   ; .l  sample data
MC_LEN    = 4                   ; .w  words
MC_LOOP   = 6                   ; .l  loop data
MC_LOOPL  = 10                  ; .w  loop words
MC_PER    = 12                  ; .w
MC_VOL    = 14                  ; .w
MC_ARP    = 16                  ; .w  0xy param
MC_PIDX   = 18                  ; .w  PT table index of base period
MC_TRIG   = 20                  ; .w
MC_SIZE   = 22

        section code,code

; ===================================================================
;  Takeover + init
; ===================================================================
start:
        lea     CUSTOM,a6
        move.w  #$7fff,INTENA(a6)
        move.w  #$7fff,INTREQ(a6)
        move.w  #$7fff,INTREQ(a6)
        move.w  #$07ff,DMACON(a6)

        ; bitplane pointers into the copper list
        lea     coplist,a0
        lea     COPOFF_BPL(a0),a1
        move.l  #plane0,d0
        bsr     poke_ptr
        move.l  #plane1,d0
        bsr     poke_ptr
        move.l  #plane2,d0
        bsr     poke_ptr

        ; silence Paula
        moveq   #3,d0
        lea     AUD0(a6),a1
.sil:   move.l  #silence,(a1)
        move.w  #1,4(a1)
        move.w  #200,6(a1)
        clr.w   8(a1)
        lea     $10(a1),a1
        dbra    d0,.sil

        move.l  #coplist,COP1LC(a6)
        move.w  d0,COPJMP1(a6)
        move.w  #$83cf,DMACON(a6)       ; DMAEN+BPL+COP+BLT+AUD0-3

        ; wipe the bob planes (BSS may arrive dirty) and keep a pristine
        ; copy of the title screen for restoring it when the song loops
        lea     plane1,a0
        moveq   #22,d0
        move.w  #256,d1
        moveq   #0,d2
        bsr     blt_clear
        lea     plane2,a0
        moveq   #22,d0
        move.w  #256,d1
        moveq   #0,d2
        bsr     blt_clear
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)      ; D = A
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        move.l  #plane0,BLTAPTH(a6)
        move.l  #logo_src,BLTDPTH(a6)
        move.w  #256*64+22,BLTSIZE(a6)
        bsr     blt_wait

        bsr     mt_init
        clr.w   frame
        clr.w   bar
        clr.w   gphase
        clr.w   scrollpx
        clr.w   scene
        move.w  #-1,cur_scene

main:
        bsr     wait_vb
        bsr     mt_tick                 ; the module drives everything
        bsr     scene_tick
        bsr     lyr_tick
        bsr     dycp_tick
        addq.w  #1,frame
        bra     main

; write a longword pointer as two copper move values: a1 -> hi,lo slots
poke_ptr:
        move.w  d0,d1
        swap    d0
        move.w  d0,(a1)                 ; xxxPTH value
        move.w  d1,4(a1)                ; xxxPTL value
        addq.l  #8,a1
        rts

wait_vb:
.w:     move.l  VPOSR(a6),d0
        and.l   #$1ff00,d0
        cmp.l   #303<<8,d0
        bne.s   .w
        rts

; ===================================================================
;  ProTracker-subset replayer (notes, Fxx speed, Cxx volume, 0xy arp)
; ===================================================================
mt_init:
        lea     module,a0
        ; find highest pattern in the order table
        moveq   #0,d0
        lea     952(a0),a1
        moveq   #127,d1
.scan:  moveq   #0,d2
        move.b  (a1)+,d2
        cmp.w   d0,d2
        ble.s   .ns
        move.w  d2,d0
.ns:    dbra    d1,.scan
        addq.w  #1,d0                   ; pattern count
        mulu    #1024,d0
        lea     1084(a0),a1             ; pattern data
        move.l  a1,mt_patterns
        adda.l  d0,a1                   ; a1 = sample data
        ; build the per-sample info table
        lea     20(a0),a2               ; sample headers
        lea     mt_samples,a3
        moveq   #30,d1                  ; 31 samples
.smp:   move.l  a1,(a3)+                ; data
        moveq   #0,d2
        move.w  22(a2),d2               ; length words
        move.w  d2,(a3)+
        moveq   #0,d3
        move.w  26(a2),d3               ; loop start words
        add.l   d3,d3
        move.l  a1,d4
        add.l   d3,d4
        move.l  d4,(a3)+                ; loop ptr
        move.w  28(a2),(a3)+            ; loop len words
        moveq   #0,d3
        move.b  25(a2),d3
        move.w  d3,(a3)+                ; volume
        add.l   d2,d2
        adda.l  d2,a1
        lea     30(a2),a2
        dbra    d1,.smp
        ; song state
        moveq   #0,d0
        move.w  d0,mt_songpos
        move.w  d0,mt_row
        move.w  d0,mt_counter
        move.w  #6,mt_speed
        ; channel state
        lea     mt_chan,a2
        moveq   #4*MC_SIZE/2-1,d1
.cc:    clr.w   (a2)+
        dbra    d1,.cc
        rts

mt_tick:
        addq.w  #1,mt_counter
        move.w  mt_counter,d0
        cmp.w   mt_speed,d0
        blt     mt_effects
        clr.w   mt_counter

        ; ---- new row ----
        lea     module,a0
        moveq   #0,d0
        move.w  mt_songpos,d0
        lea     952(a0),a1
        move.b  (a1,d0.w),d0            ; pattern number
        mulu    #1024,d0
        move.l  mt_patterns,a1
        adda.l  d0,a1
        move.w  mt_row,d0
        lsl.w   #4,d0
        adda.w  d0,a1                   ; a1 = 4 cells of this row

        clr.w   mt_trigmask
        lea     mt_chan,a2
        moveq   #0,d6                   ; channel #
.ch:    bsr     mt_cell
        lea     MC_SIZE(a2),a2
        lea     4(a1),a1
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .ch

        ; ---- apply triggers ----
        move.w  mt_trigmask,d0
        beq.s   .adv
        move.w  d0,DMACON(a6)
        lea     mt_chan,a2
        moveq   #0,d6
.tr:    tst.w   MC_TRIG(a2)
        beq.s   .tn
        clr.w   MC_TRIG(a2)
        bsr     mt_start
.tn:    lea     MC_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .tr
        move.w  #300,d1
.dl:    dbra    d1,.dl
        move.w  mt_trigmask,d0
        or.w    #$8000,d0
        move.w  d0,DMACON(a6)
        ; point the started channels at their loops (next fetch)
        lea     mt_chan,a2
        moveq   #0,d6
.lp:    tst.w   MC_LOOPL(a2)
        beq.s   .ln
        bsr     mt_regs                 ; a5 = AUDx
        move.l  MC_LOOP(a2),(a5)
        move.w  MC_LOOPL(a2),4(a5)
.ln:    lea     MC_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .lp

.adv:   ; ---- advance row / song position ----
        addq.w  #1,mt_row
        cmp.w   #64,mt_row
        blt.s   .done
        clr.w   mt_row
        addq.w  #1,mt_songpos
        lea     module,a0
        moveq   #0,d0
        move.b  950(a0),d0              ; song length
        cmp.w   mt_songpos,d0
        bgt.s   .done
        clr.w   mt_songpos
.done:  rts

; ---- decode one pattern cell: a1 = cell, a2 = chan state, d6 = ch ----
mt_cell:
        moveq   #0,d0
        move.b  (a1),d0
        and.w   #$f0,d0
        moveq   #0,d1
        move.b  2(a1),d1
        lsr.b   #4,d1
        or.w    d1,d0                   ; sample number
        moveq   #0,d2
        move.b  (a1),d2
        and.w   #$0f,d2
        lsl.w   #8,d2
        move.b  1(a1),d2                ; period
        moveq   #0,d3
        move.b  2(a1),d3
        and.w   #$0f,d3                 ; effect
        moveq   #0,d4
        move.b  3(a1),d4                ; param

        ; arpeggio param for this row (0 unless effect 0 with param)
        clr.w   MC_ARP(a2)
        tst.w   d3
        bne.s   .noarp
        tst.w   d4
        beq.s   .noarp
        move.w  d4,MC_ARP(a2)
.noarp:
        tst.w   d0
        beq.s   .nosmp
        ; latch sample info
        move.w  d0,d5
        subq.w  #1,d5
        mulu    #14,d5
        lea     mt_samples,a3
        adda.l  d5,a3
        move.l  (a3),MC_SMP(a2)
        move.w  4(a3),MC_LEN(a2)
        move.l  6(a3),MC_LOOP(a2)
        move.w  10(a3),MC_LOOPL(a2)
        move.w  12(a3),MC_VOL(a2)
.nosmp:
        tst.w   d2
        beq.s   .noper
        move.w  d2,MC_PER(a2)
        bsr     mt_pidx                 ; cache the table index
        move.w  #1,MC_TRIG(a2)
        moveq   #0,d5
        bset    d6,d5
        or.w    d5,mt_trigmask
.noper:
        cmp.w   #$c,d3
        bne.s   .novol
        move.w  d4,MC_VOL(a2)
        bsr     mt_regs
        move.w  d4,8(a5)
.novol: cmp.w   #$f,d3
        bne.s   .nospd
        tst.w   d4
        beq.s   .nospd
        cmp.w   #32,d4
        bge.s   .nospd                  ; CIA tempos not supported
        move.w  d4,mt_speed
.nospd: rts

; find PT table index of MC_PER -> MC_PIDX
mt_pidx:
        movem.l d0-d1/a0,-(sp)
        lea     mt_periods,a0
        moveq   #0,d0
        move.w  MC_PER(a2),d1
.f:     cmp.w   (a0)+,d1
        beq.s   .got
        addq.w  #1,d0
        cmp.w   #36,d0
        blt.s   .f
        moveq   #12,d0                  ; fallback: C-2
.got:   move.w  d0,MC_PIDX(a2)
        movem.l (sp)+,d0-d1/a0
        rts

; a5 = AUDx register base for channel d6
mt_regs:
        move.w  d6,d5
        lsl.w   #4,d5
        lea     AUD0(a6),a5
        adda.w  d5,a5
        rts

; program Paula for a triggered channel
mt_start:
        bsr     mt_regs
        move.l  MC_SMP(a2),(a5)
        move.w  MC_LEN(a2),4(a5)
        move.w  MC_PER(a2),6(a5)
        move.w  MC_VOL(a2),8(a5)
        rts

; ---- per-tick effects: arpeggio ----
mt_effects:
        lea     mt_chan,a2
        moveq   #0,d6
.ch:    move.w  MC_ARP(a2),d4
        beq.s   .next
        move.w  mt_counter,d0
        divu    #3,d0
        swap    d0                      ; remainder 0/1/2
        move.w  d0,d1
        moveq   #0,d2
        cmp.w   #1,d1
        blt.s   .base
        beq.s   .x
        move.w  d4,d2
        and.w   #$0f,d2
        bra.s   .base
.x:     move.w  d4,d2
        lsr.w   #4,d2
        and.w   #$0f,d2
.base:  move.w  MC_PIDX(a2),d1
        add.w   d2,d1
        cmp.w   #35,d1
        ble.s   .ok
        moveq   #35,d1
.ok:    add.w   d1,d1
        lea     mt_periods,a0
        move.w  (a0,d1.w),d1
        bsr     mt_regs
        move.w  d1,6(a5)
.next:  lea     MC_SIZE(a2),a2
        addq.w  #1,d6
        cmp.w   #4,d6
        bne.s   .ch
        rts

mt_periods:
        dc.w    856,808,762,720,678,640,604,570,538,508,480,453
        dc.w    428,404,381,360,339,320,302,285,269,254,240,226
        dc.w    214,202,190,180,170,160,151,143,135,127,120,113

; ===================================================================
;  Blitter helpers
; ===================================================================
blt_wait:
        btst    #14,DMACONR(a6)
.bw:    btst    #14,DMACONR(a6)
        bne.s   .bw
        rts

; clear h rows of w words at a0 (screen-modulo aware): d0=w, d1=h, d2=mod
blt_clear:
        bsr     blt_wait
        move.w  #$0100,BLTCON0(a6)
        clr.w   BLTCON1(a6)
        move.w  d2,BLTDMOD(a6)
        move.l  a0,BLTDPTH(a6)
        move.w  d1,d3
        lsl.w   #6,d3
        or.w    d0,d3
        move.w  d3,BLTSIZE(a6)
        rts

; OR-blit a 32px-wide, d1-rows image (a0) to plane a1 at (d0=x, rows
; preset in a1 base): 3-word blit with shift
;   a0 = src (4 bytes/row), a1 = dest row0 byte addr, d0 = x, d1 = h
blt_img:
        bsr     blt_wait
        move.w  d0,d2
        and.w   #$f,d2
        ror.w   #4,d2                   ; shift in bits 15-12
        or.w    #$0bfa,d2               ; USEA|USEC|USED, LF = A|C
        move.w  d2,BLTCON0(a6)
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        clr.w   BLTALWM(a6)             ; the spill word is masked away
        move.w  #-2,BLTAMOD(a6)
        move.w  #PLANEB-6,BLTCMOD(a6)
        move.w  #PLANEB-6,BLTDMOD(a6)
        move.l  a0,BLTAPTH(a6)
        move.w  d0,d2
        asr.w   #4,d2
        add.w   d2,d2
        lea     (a1,d2.w),a2
        move.l  a2,BLTCPTH(a6)
        move.l  a2,BLTDPTH(a6)
        move.w  d1,d2
        lsl.w   #6,d2
        or.w    #3,d2
        move.w  d2,BLTSIZE(a6)
        rts

; ===================================================================
;  Scene engine: bar timeline from the replayer position
; ===================================================================
scene_tick:
        ; bar = songpos*4 + row/16
        move.w  mt_songpos,d0
        lsl.w   #2,d0
        move.w  mt_row,d1
        lsr.w   #4,d1
        add.w   d1,d0
        move.w  d0,bar
        lea     scene_of_bar,a0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        move.w  d1,scene
        bsr     scene_palette           ; 6 copper words, cheap every frame
        move.w  scene,d1
        add.w   d1,d1
        lea     scene_tab,a0
        move.w  (a0,d1.w),d1
        lea     scene_tab,a0
        jsr     (a0,d1.w)
        bsr     copy_shadow
        bsr     logo_colours
        bsr     do_cast
        rts

scene_tab:
        dc.w    sc_black-scene_tab      ; 0 intro
        dc.w    sc_verse-scene_tab      ; 1
        dc.w    sc_drop-scene_tab       ; 2
        dc.w    sc_tunnel-scene_tab     ; 3
        dc.w    sc_finale-scene_tab     ; 4
        dc.w    sc_black-scene_tab      ; 5 outro

; per-scene palette for colours 2-7 into the copper header
scene_palette:
        lea     pal_cats,a1
        move.w  scene,d0
        cmp.w   #2,d0
        bne.s   .n1
        lea     pal_ships,a1
        bra.s   .go
.n1:    cmp.w   #3,d0
        bne.s   .n2
        lea     pal_tunnel,a1
        bra.s   .go
.n2:    cmp.w   #1,d0                   ; verse: horses take over at bar 8
        bne.s   .go
        cmp.w   #8,bar
        blt.s   .go
        lea     pal_horses,a1
.go:    lea     coplist,a0
        lea     COPOFF_PAL+4(a0),a0     ; +4: skip COLOR01 (logo gradient)
        moveq   #5,d0
.c:     move.w  (a1)+,(a0)
        addq.l  #4,a0
        dbra    d0,.c
        rts

sc_black:
        lea     shadow,a0
        moveq   #31,d0
.c:     clr.l   (a0)+
        dbra    d0,.c
        rts

sc_verse:
        bsr     sc_black
        lea     shadow,a0
        lea     sine64,a1
        moveq   #0,d5
.bar:   move.w  frame,d0
        cmp.w   #2,d5
        blt.s   .s
        add.w   d0,d0
.s:     move.w  d5,d1
        lsl.w   #4,d1
        add.w   d1,d0
        and.w   #63,d0
        moveq   #0,d1
        move.b  (a1,d0.w),d1
        subq.w  #3,d1
        add.w   d1,d1
        lea     ramp_cyan,a3
        move.w  d5,d2
        lsl.w   #4,d2
        adda.w  d2,a3
        lea     shadow,a2
        adda.w  d1,a2
        moveq   #6,d2
.r:     move.w  (a3)+,(a2)+
        dbra    d2,.r
        addq.w  #1,d5
        cmp.w   #4,d5
        bne.s   .bar
        rts

sc_drop:
        lea     shadow,a0
        lea     sky_grad,a1
        moveq   #25,d0
.sky:   move.w  (a1)+,(a0)+
        dbra    d0,.sky
        bra     grid_ground

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

sc_tunnel:
        addq.w  #1,gphase
        cmp.w   #96,gphase
        blt.s   .ok
        clr.w   gphase
.ok:    move.w  gphase,d0
        lsl.w   #7,d0
        lea     tunnel_anim,a1
        adda.l  d0,a1
        lea     shadow,a0
        moveq   #63,d0
.t:     move.w  (a1)+,(a0)+
        dbra    d0,.t
        rts

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
        bra     grid_ground

copy_shadow:
        lea     shadow,a0
        lea     copoff_c00,a1
        lea     coplist,a2
        moveq   #63,d0
.l:     move.w  (a1)+,d1
        move.w  (a0)+,(a2,d1.w)
        dbra    d0,.l
        rts

; roll the metallic gradient through the title letters
logo_colours:
        lea     copoff_c01,a1
        lea     coplist,a2
        lea     logo_grad,a3
        move.w  frame,d2
        lsr.w   #2,d2
        moveq   #0,d0
.l:     move.w  d0,d1
        add.w   d2,d1
        and.w   #63,d1
        cmp.w   #44,d1
        blt.s   .in
        moveq   #43,d1
.in:    add.w   d1,d1
        move.w  (a3,d1.w),d1
        move.w  (a1)+,d3
        move.w  d1,(a2,d3.w)
        addq.w  #1,d0
        cmp.w   #44,d0
        bne.s   .l
        rts

; ===================================================================
;  The cast: clear planes 1+2 in the action bands, then draw
; ===================================================================
do_cast:
        ; clear the whole action area in both bob planes: from the sky
        ; band (vector ships) down past the bobs' full 42px height
        lea     plane1+16*PLANEB,a0
        moveq   #22,d0
        move.w  #240,d1
        moveq   #0,d2
        bsr     blt_clear
        lea     plane2+16*PLANEB,a0
        moveq   #22,d0
        move.w  #240,d1
        moveq   #0,d2
        bsr     blt_clear

        move.w  scene,d0
        cmp.w   #1,d0
        beq     cast_verse
        cmp.w   #2,d0
        beq     cast_ships
        cmp.w   #3,d0
        beq     cast_tunnel
        cmp.w   #4,d0
        beq     cast_finale
        rts

; ---- walking bob: d0=x d1=y, a3=frame table (4 entries of p1/p2) ----
draw_bob:
        movem.l d0-d1/a1/a3,-(sp)
        move.l  (a3),a0                 ; plane-1 image
        move.w  d1,d2
        mulu    #PLANEB,d2
        lea     plane1,a1
        adda.l  d2,a1
        move.w  #42,d1
        bsr     blt_img
        movem.l (sp),d0-d1/a1/a3
        move.l  4(a3),a0                ; plane-2 image
        move.w  d1,d2
        mulu    #PLANEB,d2
        lea     plane2,a1
        adda.l  d2,a1
        move.w  #42,d1
        bsr     blt_img
        movem.l (sp)+,d0-d1/a1/a3
        rts

; walker position: d5 = index -> d0 x, d1 y.  Walkers are spread 96 px
; apart on a 384-wide loop (so someone is always on screen) and bob on
; a sine, below the lyric lines.
walk_pos:
        move.w  frame,d0
        lsr.w   #1,d0                   ; 1 px every other frame
        move.w  d5,d2
        mulu    #96,d2
        add.w   d2,d0
.wrap:  cmp.w   #384,d0
        blt.s   .in
        sub.w   #384,d0
        bra.s   .wrap
.in:    sub.w   #32,d0                  ; -32 .. 351
        cmp.w   #320,d0                 ; fully off the right edge?
        blt.s   .vis                    ; (a blit there would wrap rows)
        moveq   #-32,d0
        rts
.vis:   move.w  frame,d1
        lsr.w   #2,d1
        add.w   d5,d1
        and.w   #63,d1
        lea     sine64,a0
        moveq   #0,d2
        move.b  (a0,d1.w),d2
        lsr.w   #2,d2
        add.w   #CAST_Y0+52,d2          ; clear of the lyric lines
        move.w  d2,d1
        rts

cast_verse:
        move.w  bar,d0
        cmp.w   #8,d0
        bge.s   .horses
        moveq   #0,d5
.cats:  bsr     walk_pos
        tst.w   d0
        bmi.s   .cn
        ; 4-frame saw animation
        move.w  frame,d2
        lsr.w   #2,d2
        add.w   d5,d2
        and.w   #3,d2
        lsl.w   #3,d2
        lea     cat_frames,a3
        adda.w  d2,a3
        bsr     draw_bob
.cn:    addq.w  #1,d5
        cmp.w   #3,d5
        bne.s   .cats
        rts
.horses:
        moveq   #0,d5
.h:     bsr     walk_pos
        tst.w   d0
        bmi.s   .hn
        move.w  frame,d2
        lsr.w   #3,d2
        add.w   d5,d2
        and.w   #1,d2
        lsl.w   #3,d2
        lea     horse_frames,a3
        adda.w  d2,a3
        bsr     draw_bob
.hn:    addq.w  #1,d5
        cmp.w   #2,d5
        bne.s   .h
        ; one magic circle drifting above
        move.w  frame,d0
        and.w   #$1ff,d0
        cmp.w   #288,d0
        bge.s   .done
        move.w  #CAST_Y0+8,d1
        move.w  frame,d2
        lsr.w   #3,d2
        and.w   #1,d2
        lsl.w   #3,d2
        lea     circle_frames,a3
        adda.w  d2,a3
        bsr     draw_bob
.done:  rts

cast_tunnel:
        moveq   #0,d5
.d:     bsr     walk_pos
        tst.w   d0
        bmi.s   .dn
        move.w  frame,d2
        lsr.w   #3,d2
        add.w   d5,d2
        and.w   #1,d2
        lsl.w   #3,d2
        lea     dancer_frames,a3
        adda.w  d2,a3
        bsr     draw_bob
.dn:    addq.w  #1,d5
        cmp.w   #2,d5
        bne.s   .d
        move.w  frame,d0
        lsr.w   #1,d0
        and.w   #$ff,d0
        add.w   #16,d0
        move.w  #CAST_Y0+12,d1
        lea     ball_frames,a3
        bsr     draw_bob
        rts

cast_finale:
        moveq   #0,d5
.c:     bsr     walk_pos
        tst.w   d0
        bmi.s   .cn
        move.w  d5,d2
        and.w   #1,d2
        bne.s   .fh
        lea     cat_frames,a3
        bra.s   .fd
.fh:    lea     horse_frames,a3
.fd:    bsr     draw_bob
.cn:    addq.w  #1,d5
        cmp.w   #4,d5
        bne.s   .c
        rts

; ===================================================================
;  Vector spaceships (drop scene): CPU XOR outline -> blitter fill ->
;  OR into both bob planes (colour 6, with parity cockpit holes)
; ===================================================================
SHIPBUF_W = 3                   ; words (48 px)
SHIPBUF_H = 44

cast_ships:
        moveq   #0,d7                   ; ship number 0/1
.ship:  ; clear the work buffer
        lea     shipbuf,a0
        moveq   #SHIPBUF_W,d0
        move.w  #SHIPBUF_H,d1
        moveq   #0,d2
        bsr     blt_clear
        bsr     blt_wait
        ; angle wobble per ship
        move.w  frame,d0
        move.w  d7,d1
        lsl.w   #7,d1
        add.w   d1,d0
        and.w   #255,d0
        lea     rot_sine,a0
        move.b  (a0,d0.w),d1
        ext.w   d1
        asr.w   #4,d1                   ; gentle tilt -8..8 -> sin idx
        move.w  d1,ship_tilt
        ; draw the hull + canopy outlines
        lea     ship_poly,a0
        move.w  #SHIP_PTS,d0
        bsr     poly_outline
        lea     ship_canopy,a0
        move.w  #CANOPY_PTS,d0
        bsr     poly_outline
        ; blitter fill (inclusive, descending)
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)
        move.w  #$000a,BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        lea     shipbuf+SHIPBUF_W*2*SHIPBUF_H-2,a0
        move.l  a0,BLTAPTH(a6)
        move.l  a0,BLTDPTH(a6)
        move.w  #SHIPBUF_H*64+SHIPBUF_W,BLTSIZE(a6)
        ; position: swoop right-to-left, ships spread over the loop
        move.w  frame,d0
        lsr.w   #1,d0
        move.w  d7,d1
        mulu    #128,d1
        add.w   d1,d0
.swrap: cmp.w   #384,d0
        blt.s   .sin
        sub.w   #384,d0
        bra.s   .swrap
.sin:   move.w  #352,d1
        sub.w   d0,d1                   ; 352 .. -32
        cmp.w   #0,d1
        blt     .next
        cmp.w   #300,d1
        bge     .next
        move.w  d1,d0
        move.w  frame,d2
        lsr.w   #1,d2
        move.w  d7,d3
        lsl.w   #5,d3
        add.w   d3,d2
        and.w   #63,d2
        lea     sine64,a0
        moveq   #0,d3
        move.b  (a0,d2.w),d3
        add.w   #CAST_Y0-70,d3          ; fly high in the sky band
        ; OR the ship into both planes
        movem.w d0/d3,-(sp)
        lea     shipbuf,a0
        move.w  d3,d2
        mulu    #PLANEB,d2
        lea     plane1,a1
        adda.l  d2,a1
        move.w  #SHIPBUF_H,d1
        bsr     blt_img3
        movem.w (sp)+,d0/d3
        lea     shipbuf,a0
        move.w  d3,d2
        mulu    #PLANEB,d2
        lea     plane2,a1
        adda.l  d2,a1
        move.w  #SHIPBUF_H,d1
        bsr     blt_img3
.next:  addq.w  #1,d7
        cmp.w   #3,d7
        bne     .ship
        rts

; like blt_img but 4-word wide (48px source + shift spill)
blt_img3:
        bsr     blt_wait
        move.w  d0,d2
        and.w   #$f,d2
        ror.w   #4,d2
        or.w    #$0bfa,d2
        move.w  d2,BLTCON0(a6)
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        clr.w   BLTALWM(a6)
        move.w  #-2,BLTAMOD(a6)
        move.w  #PLANEB-8,BLTCMOD(a6)
        move.w  #PLANEB-8,BLTDMOD(a6)
        move.l  a0,BLTAPTH(a6)
        move.w  d0,d2
        asr.w   #4,d2
        add.w   d2,d2
        lea     (a1,d2.w),a2
        move.l  a2,BLTCPTH(a6)
        move.l  a2,BLTDPTH(a6)
        move.w  d1,d2
        lsl.w   #6,d2
        or.w    #4,d2
        move.w  d2,BLTSIZE(a6)
        rts

; ---- rotate/scale polygon a0 (d0 points) and XOR its outline into
;      shipbuf, one dot per row (fill parity) ----
poly_outline:
        move.w  d0,d5
        subq.w  #1,d5
        lea     poly_xy,a1
        move.w  d0,-(sp)
        ; transform all points: x' = 24 + x - (y*tilt)>>5, y' = 20 + y/?
.pt:    move.w  (a0)+,d1                ; px
        move.w  (a0)+,d2                ; py
        move.w  ship_tilt,d3
        muls    d1,d3
        asr.w   #5,d3
        move.w  d2,d4
        add.w   d3,d4                   ; shear = poor man's rotation
        add.w   #22,d4
        add.w   #24,d1
        move.w  d1,(a1)+
        move.w  d4,(a1)+
        dbra    d5,.pt
        ; XOR-walk the edges
        move.w  (sp)+,d5
        lea     poly_xy,a1
        move.w  d5,d6
        subq.w  #1,d6
.edge:  move.w  (a1),d0                 ; x1
        move.w  2(a1),d1                ; y1
        move.w  4(a1),d2                ; x2
        move.w  6(a1),d3                ; y2
        tst.w   d6
        bne.s   .e2
        ; last edge closes back to point 0
        lea     poly_xy,a2
        move.w  (a2),d2
        move.w  2(a2),d3
.e2:    bsr     edge_dots
        addq.l  #4,a1
        dbra    d6,.edge
        rts

; one XOR dot per scanline from (d0,d1) to (d2,d3), y half-open
; (exactly one parity flip per row per edge crossing -> fillable)
edge_dots:
        movem.l d0-d6/a0,-(sp)
        cmp.w   d1,d3
        beq.s   .out                    ; horizontal: no parity change
        bgt.s   .down
        exg     d0,d2
        exg     d1,d3
.down:  ; d1 < d3: walk rows y = d1 .. d3-1, x in 8.8 fixed point
        move.w  d2,d4
        sub.w   d0,d4                   ; dx (|dx| <= 56)
        move.w  d3,d5
        sub.w   d1,d5                   ; dy > 0
        ext.l   d4
        asl.l   #8,d4
        divs    d5,d4                   ; x step, 8.8
        move.w  d0,d2
        asl.w   #8,d2                   ; x accumulator, 8.8
        move.w  d5,d6
        subq.w  #1,d6
.yl:    cmp.w   #SHIPBUF_H-1,d1
        bhi.s   .sk                     ; y outside the buffer
        move.w  d2,d0
        asr.w   #8,d0
        cmp.w   #SHIPBUF_W*16-1,d0
        bhi.s   .sk                     ; x outside (negative too)
        move.w  d1,d3
        mulu    #SHIPBUF_W*2,d3
        lea     shipbuf,a0
        adda.w  d3,a0
        move.w  d0,d3
        lsr.w   #3,d3
        adda.w  d3,a0
        not.w   d0
        and.w   #7,d0
        bchg    d0,(a0)                 ; XOR the parity dot
.sk:    add.w   d4,d2
        addq.w  #1,d1
        dbra    d6,.yl
.out:   movem.l (sp)+,d0-d6/a0
        rts

; ===================================================================
;  Lyrics: bar-synced cues rendered into the title zone of plane 0
; ===================================================================
LYRZ_Y0 = 16
LYRZ_Y1 = 186

lyr_tick:
        move.w  bar,d0
        cmp.w   prev_bar,d0
        beq.s   .done
        blt.s   .wrapped                ; song looped: bring the title back
        move.w  d0,prev_bar
.chk:   move.w  lyr_idx,d1
        lea     lyr_bars,a0
        moveq   #0,d2
        move.b  (a0,d1.w),d2
        cmp.b   #$ff,d2
        beq.s   .done
        cmp.w   d0,d2
        bne.s   .done
        bsr     render_lyric
        addq.w  #1,lyr_idx
        bra.s   .chk
.wrapped:
        move.w  d0,prev_bar
        clr.w   lyr_idx
        ; restore the pristine title screen (rows 0..LYRZ_Y1)
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)      ; D = A
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        move.l  #logo_src,BLTAPTH(a6)
        move.l  #plane0,BLTDPTH(a6)
        move.w  #LYRZ_Y1*64+22,BLTSIZE(a6)
.done:  rts

; render the lyric cue lyr_idx (clears the whole zone first)
render_lyric:
        movem.l d0-d7/a0-a4,-(sp)
        lea     plane0+LYRZ_Y0*PLANEB,a0
        moveq   #22,d0
        move.w  #LYRZ_Y1-LYRZ_Y0,d1
        moveq   #0,d2
        bsr     blt_clear
        move.w  lyr_idx,d0
        add.w   d0,d0
        lea     lyr_offs,a0
        move.w  (a0,d0.w),d0
        lea     lyr_blob,a4
        adda.w  d0,a4
        moveq   #0,d7
        move.b  (a4)+,d7                ; big keyword?
        ; keyword
        moveq   #0,d6
        move.b  (a4)+,d6
        beq.s   .l1
        tst.w   d7
        beq.s   .kw16
        move.w  #44,d5                  ; y
        moveq   #32,d4                  ; glyph advance
        bsr     center_x
        bsr     blit_string32
        bra.s   .l1
.kw16:  move.w  #52,d5
        moveq   #16,d4
        bsr     center_x
        bsr     blit_string16
.l1:    moveq   #0,d6
        move.b  (a4)+,d6
        beq.s   .l2
        move.w  #104,d5
        moveq   #16,d4
        bsr     center_x
        bsr     blit_string16
.l2:    moveq   #0,d6
        move.b  (a4)+,d6
        beq.s   .out
        move.w  #128,d5
        moveq   #16,d4
        bsr     center_x
        bsr     blit_string16
.out:   movem.l (sp)+,d0-d7/a0-a4
        rts

; d6 = length, d4 = advance -> d3 = centred start x
center_x:
        move.w  d6,d3
        mulu    d4,d3
        move.w  #320,d2
        sub.w   d3,d2
        asr.w   #1,d2
        bpl.s   .ok
        moveq   #0,d2
.ok:    move.w  d2,d3
        rts

; blit d6 glyph ids from (a4) at y=d5, x=d3, 32px font
blit_string32:
.c:     moveq   #0,d0
        move.b  (a4)+,d0
        lsl.w   #7,d0                   ; * 128 bytes per glyph
        lea     dycp_font,a0
        adda.l  d0,a0
        move.w  d5,d1
        mulu    #PLANEB,d1
        lea     plane0,a1
        adda.l  d1,a1
        move.w  d3,d0
        move.w  #32,d1
        bsr     blt_img
        add.w   #32,d3
        subq.w  #1,d6
        bne.s   .c
        rts

; blit d6 glyph ids from (a4) at y=d5, x=d3, 16px font
blit_string16:
.c:     moveq   #0,d0
        move.b  (a4)+,d0
        lsl.w   #5,d0                   ; * 32 bytes per glyph
        lea     font16,a0
        adda.l  d0,a0
        move.w  d5,d1
        mulu    #PLANEB,d1
        lea     plane0,a1
        adda.l  d1,a1
        move.w  d3,d0
        move.w  #16,d1
        bsr     blt_img2
        add.w   #16,d3
        subq.w  #1,d6
        bne.s   .c
        rts

; OR-blit a 16px-wide, d1-rows glyph (a0) to plane a1 at x=d0 (2-word)
blt_img2:
        bsr     blt_wait
        move.w  d0,d2
        and.w   #$f,d2
        ror.w   #4,d2
        or.w    #$0bfa,d2
        move.w  d2,BLTCON0(a6)
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        clr.w   BLTALWM(a6)
        move.w  #-2,BLTAMOD(a6)
        move.w  #PLANEB-4,BLTCMOD(a6)
        move.w  #PLANEB-4,BLTDMOD(a6)
        move.l  a0,BLTAPTH(a6)
        move.w  d0,d2
        asr.w   #4,d2
        add.w   d2,d2
        lea     (a1,d2.w),a2
        move.l  a2,BLTCPTH(a6)
        move.l  a2,BLTDPTH(a6)
        move.w  d1,d2
        lsl.w   #6,d2
        or.w    #2,d2
        move.w  d2,BLTSIZE(a6)
        rts

; ===================================================================
;  DYCP scroller: every letter on its own sine
; ===================================================================
dycp_tick:
        ; clear the band in plane 0
        lea     plane0+DYCP_Y*PLANEB,a0
        moveq   #22,d0
        move.w  #256-DYCP_Y,d1
        moveq   #0,d2
        bsr     blt_clear

        addq.w  #2,scrollpx             ; 2 px per frame
        move.w  scrollpx,d0
        cmp.w   #26,d0
        blt.s   .nof
        clr.w   scrollpx
        addq.w  #1,scrollhead
        lea     scrolltext,a0
        move.w  scrollhead,d1
        cmp.b   #$ff,(a0,d1.w)
        bne.s   .nof
        clr.w   scrollhead
.nof:
        move.w  scrollpx,d7
        neg.w   d7                      ; first letter x
        move.w  scrollhead,d6           ; text index
.loop:  cmp.w   #320,d7
        bge.s   .done
        lea     scrolltext,a0
        move.b  (a0,d6.w),d0
        cmp.b   #$ff,d0
        bne.s   .ok
        clr.w   d6                      ; wrap mid-line
        move.b  (a0),d0
.ok:    tst.w   d7
        bmi.s   .skip                   ; clipped at the left edge
        ; y = per-letter sine
        move.w  d6,d1
        mulu    #11,d1
        move.w  frame,d2
        add.w   d2,d1
        and.w   #127,d1
        lea     dycp_sine,a1
        moveq   #0,d2
        move.b  (a1,d1.w),d2
        add.w   #DYCP_Y+2,d2
        ; blit the glyph
        moveq   #0,d1
        move.b  d0,d1
        lsl.w   #7,d1                   ; glyph * 128 bytes
        lea     dycp_font,a0
        adda.l  d1,a0
        move.w  d2,d1
        mulu    #PLANEB,d1
        lea     plane0,a1
        adda.l  d1,a1
        move.w  d7,d0
        move.w  #32,d1
        bsr     blt_img
.skip:  add.w   #26,d7
        addq.w  #1,d6
        bra.s   .loop
.done:  rts

; ===================================================================
;  Variables
; ===================================================================
frame:      dc.w 0
bar:        dc.w 0
prev_bar:   dc.w -1
lyr_idx:    dc.w 0
scene:      dc.w 0
cur_scene:  dc.w 0
gphase:     dc.w 0
scrollpx:   dc.w 0
scrollhead: dc.w 0
ship_tilt:  dc.w 0
mt_songpos: dc.w 0
mt_row:     dc.w 0
mt_counter: dc.w 0
mt_speed:   dc.w 6
mt_trigmask: dc.w 0
mt_patterns: dc.l 0
mt_samples: ds.b 31*14
mt_chan:    ds.b MC_SIZE*4
shadow:     ds.w 64
poly_xy:    ds.w 32

cat_frames:
        dc.l bob_cat0_1,bob_cat0_2,bob_cat1_1,bob_cat1_2
        dc.l bob_cat2_1,bob_cat2_2,bob_cat3_1,bob_cat3_2
horse_frames:
        dc.l bob_horse0_1,bob_horse0_2,bob_horse1_1,bob_horse1_2
ball_frames:
        dc.l bob_ball0_1,bob_ball0_2,bob_ball1_1,bob_ball1_2
dancer_frames:
        dc.l bob_dancer0_1,bob_dancer0_2,bob_dancer1_1,bob_dancer1_2
circle_frames:
        dc.l bob_circle0_1,bob_circle0_2,bob_circle1_1,bob_circle1_2

; ===================================================================
;  Chip data
; ===================================================================
        section chip,data_c

silence: dc.w 0,0

        include "amiga_data.i"

module:
        incbin  "motorsag.mod"
        even
plane0:
        incbin  "logo.raw"
        even

        section chipbss,bss_c
plane1:   ds.b PLANEB*256
plane2:   ds.b PLANEB*256
logo_src: ds.b PLANEB*256      ; pristine title, for restoring on loop
shipbuf:  ds.b SHIPBUF_W*2*SHIPBUF_H
