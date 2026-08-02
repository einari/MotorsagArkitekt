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

        ; both buffer sets: wipe the bob planes (BSS may arrive dirty)
        ; and copy the pristine title into both plane-0 buffers
        lea     plane1a,a0
        bsr     init_wipe
        lea     plane2a,a0
        bsr     init_wipe
        lea     plane1b,a0
        bsr     init_wipe
        lea     plane2b,a0
        bsr     init_wipe
        lea     plane0a,a1
        bsr     copy_title
        lea     plane0b,a1
        bsr     copy_title
        bsr     inval_slots
        clr.w   front
        bsr     flip_buffers            ; copper -> set B, draw -> set A

        bsr     mt_init
        clr.w   frame
        clr.w   bar
        clr.w   gphase
        clr.w   scrollpx
        clr.w   scene
        move.w  #-1,cur_scene

main:
        bsr     wait_vb
        bsr     flip_buffers            ; show last frame, draw the next
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

wait_vb:                                ; accept lines 303-312 so a frame
.w:     move.l  VPOSR(a6),d0            ; that runs a touch long only
        and.l   #$1ff00,d0              ; loses one frame, not the window
        sub.l   #303<<8,d0
        bmi.s   .w
        cmp.l   #10<<8,d0
        bge.s   .w
        rts

; ===================================================================
;  Double buffering: two sets of the three planes; the copper shows
;  one set while everything draws into the other, flipped per vblank.
; ===================================================================
flip_buffers:
        move.w  front,d0
        eor.w   #1,d0
        move.w  d0,front                ; the freshly drawn set goes live
        lsl.w   #2,d0
        lea     coplist,a0
        lea     COPOFF_BPL(a0),a1
        lea     buf0,a2
        move.l  (a2,d0.w),d0
        bsr     poke_ptr
        move.w  front,d0
        lsl.w   #2,d0
        lea     buf1,a2
        move.l  (a2,d0.w),d0
        bsr     poke_ptr
        move.w  front,d0
        lsl.w   #2,d0
        lea     buf2,a2
        move.l  (a2,d0.w),d0
        bsr     poke_ptr
        ; drawing targets = the hidden set
        move.w  front,d0
        eor.w   #1,d0
        lsl.w   #2,d0
        lea     buf0,a2
        move.l  (a2,d0.w),cur_p0
        lea     buf1,a2
        move.l  (a2,d0.w),cur_p1
        lea     buf2,a2
        move.l  (a2,d0.w),cur_p2
        rts

init_wipe:                              ; clear a full plane at a0
        moveq   #22,d0
        move.w  #256,d1
        moveq   #0,d2
        bra     blt_clear

copy_title:                             ; logo_src -> plane at a1
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)      ; D = A
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        move.l  #logo_src,BLTAPTH(a6)
        move.l  a1,BLTDPTH(a6)
        move.w  #256*64+22,BLTSIZE(a6)
        bra     blt_wait

copy_ovl:                               ; sun/grid overlay -> zone at a1
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)
        clr.w   BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        move.l  #drop_ovl,BLTAPTH(a6)
        move.l  a1,BLTDPTH(a6)
        move.w  #171*64+22,BLTSIZE(a6)
        bra     blt_wait

; ---- dirty rectangles: each object slot remembers where it drew in
;      each buffer; the spot is cleared before redrawing there ----
inval_slots:
        lea     prevs,a0
        moveq   #15,d0
.i:     move.l  #$7fff7fff,(a0)+
        dbra    d0,.i
        rts

; a0 -> this slot's prev entry in the back buffer's bank (d5 = slot)
prev_base:
        move.w  front,d0
        eor.w   #1,d0
        lsl.w   #5,d0                   ; bank * 32 bytes
        lea     prevs,a0
        adda.w  d0,a0
        move.w  d5,d0
        lsl.w   #2,d0
        adda.w  d0,a0
        rts

slot_clear:                             ; d5 = slot
        movem.l d0-d2/a0,-(sp)
        bsr     prev_base
        move.w  2(a0),d1                ; prev y
        cmp.w   #$7fff,d1
        beq.s   .none
        move.w  (a0),d0                 ; prev x
        bsr     rect_clear
.none:  movem.l (sp)+,d0-d2/a0
        rts

slot_store:                             ; d5 = slot, d0/d1 = x/y
        movem.l d2/a0,-(sp)             ; prev_base trashes d0: keep x
        move.w  d0,d2
        bsr     prev_base
        move.w  d2,(a0)
        move.w  d1,2(a0)
        move.w  d2,d0                   ; hand x back to the caller
        movem.l (sp)+,d2/a0
        rts

slot_hide:                              ; d5 = slot: wipe it and forget
        movem.l d0/a0,-(sp)             ; (for objects leaving the screen)
        bsr     slot_clear
        bsr     prev_base
        move.l  #$7fff7fff,(a0)
        movem.l (sp)+,d0/a0
        rts

; clear a 6-word x 72-row rect at (d0,d1) in both back bob planes
; (72 rows covers the tallest object: the 64px magic circles)
rect_clear:
        movem.l d0-d3/a0-a1,-(sp)
        sub.w   #8,d0
        bpl.s   .x1
        moveq   #0,d0
.x1:    asr.w   #4,d0
        cmp.w   #16,d0
        ble.s   .x2
        moveq   #16,d0
.x2:    add.w   d0,d0                   ; byte offset of start word
        subq.w  #2,d1
        cmp.w   #16,d1
        bge.s   .y1
        moveq   #16,d1
.y1:    cmp.w   #183,d1
        ble.s   .y2
        move.w  #183,d1
.y2:    move.w  d1,d3
        mulu    #PLANEB,d3
        add.w   d0,d3
        move.l  d3,-(sp)                ; blt_clear trashes d3
        move.l  cur_p1,a1
        adda.l  d3,a1
        move.l  a1,a0
        moveq   #6,d0
        moveq   #72,d1
        move.w  #PLANEB-12,d2
        bsr     blt_clear
        move.l  (sp)+,d3
        move.l  cur_p2,a1
        adda.l  d3,a1
        move.l  a1,a0
        moveq   #6,d0
        moveq   #72,d1
        move.w  #PLANEB-12,d2
        bsr     blt_clear
        movem.l (sp)+,d0-d3/a0-a1
        rts

; ---- the big magic circle: 64x64 one-plane bob, rotating ticks ----
; d0 = x, d1 = y, d5 = slot
draw_circle64:
        movem.l d0-d2/a0-a1,-(sp)
        bsr     slot_store              ; (rect already cleared in do_cast)
        move.w  frame,d2
        lsr.w   #3,d2
        and.w   #3,d2
        lsl.w   #8,d2
        add.w   d2,d2                   ; frame * 512 bytes
        lea     circle64_0,a0
        adda.w  d2,a0
        move.w  d1,d2
        mulu    #PLANEB,d2
        move.l  cur_p1,a1
        adda.l  d2,a1
        move.w  #64,d1
        bsr     blt_img4
        movem.l (sp)+,d0-d2/a0-a1
        rts

; ===================================================================
;  ProTracker-subset replayer (notes, Fxx speed, Cxx volume, 0xy arp)
; ===================================================================
mt_init:
        lea     mod_data,a0
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
        lea     mod_data,a0
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
        move.w  #300,d1                 ; settle again (as PT does)
.d2:    dbra    d1,.d2
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
        lea     mod_data,a0
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

        ; arpeggio param for this row (0 unless effect 0 with param).
        ; When an arp row ends, snap the channel back to its base
        ; period — otherwise a held note stays stuck on the last arp
        ; offset for the whole next row (audibly detuned).
        move.w  MC_ARP(a2),d5
        clr.w   MC_ARP(a2)
        tst.w   d3
        bne.s   .chkoff
        tst.w   d4
        beq.s   .chkoff
        move.w  d4,MC_ARP(a2)
        bra.s   .noarp
.chkoff:
        tst.w   d5
        beq.s   .noarp
        movem.l d0-d1/a0,-(sp)          ; restore the base period
        move.w  MC_PIDX(a2),d0
        add.w   d0,d0
        lea     mt_periods,a0
        move.w  (a0,d0.w),d0
        bsr     mt_regs
        move.w  d0,6(a5)
        movem.l (sp)+,d0-d1/a0
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
        jsr     (a0,d1.w)               ; each scene owns its copper bg
        bsr     logo_colours
        bsr     do_cast
        rts

scene_tab:
        dc.w    sc_black-scene_tab      ; 0 intro
        dc.w    sc_verse-scene_tab      ; 1
        dc.w    sc_drop-scene_tab       ; 2
        dc.w    sc_plasma-scene_tab     ; 3
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
.n2:    cmp.w   #4,d0                   ; finale: everyone in bright colours
        bne.s   .n3
        lea     pal_horses,a1
        bra.s   .go
.n3:    cmp.w   #1,d0                   ; verse: horses take over at bar 8
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

; zero the 256-line background shadow (helper, no copper writes)
shadow_black:
        lea     shadow,a0
        move.w  #127,d0
.c:     clr.l   (a0)+
        dbra    d0,.c
        rts

sc_black:                               ; static scenes: build + poke once
        move.w  scene,d0
        cmp.w   shadow_scene,d0
        beq.s   .done
        move.w  d0,shadow_scene
        bsr     shadow_black
        bra     copy_shadow
.done:  rts

; four smooth 32-line copper bars gliding on sines (4096-colour ramps)
sc_verse:
        move.w  #1,shadow_scene
        bsr     shadow_black
        lea     sine64,a1
        moveq   #0,d5
.bar:   move.w  frame,d0
        lsr.w   #3,d0                   ; slow pair glides ~10 s/cycle
        cmp.w   #2,d5
        blt.s   .s
        move.w  frame,d0
        lsr.w   #2,d0                   ; fast pair ~5 s, like the web
.s:     move.w  d5,d1
        lsl.w   #4,d1
        add.w   d1,d0
        and.w   #63,d0
        moveq   #0,d1
        move.b  (a1,d0.w),d1
        subq.w  #3,d1
        mulu    #6,d1                   ; bar top line 0..210
        add.w   d1,d1
        lea     bar32_cyan,a3           ; the four ramps sit 64B apart
        move.w  d5,d2
        lsl.w   #6,d2
        adda.w  d2,a3
        lea     shadow,a2
        adda.w  d1,a2
        moveq   #31,d2
.r:     move.w  (a3)+,(a2)+
        dbra    d2,.r
        addq.w  #1,d5
        cmp.w   #4,d5
        bne.s   .bar
        bra     copy_shadow

; per-line 4096-colour sunset + ground with accelerating grid lines.
; The sky and ground are static: built and poked into the copper once,
; then only the 6 moving grid lines are patched in place per frame.
sc_drop:
        move.w  scene,d0
        cmp.w   shadow_scene,d0
        beq.s   .light
        move.w  d0,shadow_scene
        clr.w   grid_n
        lea     shadow,a0
        lea     sunset,a1
        moveq   #103,d0
.sky:   move.w  (a1)+,(a0)+
        dbra    d0,.sky
        move.w  #151,d0
.gnd:   move.w  #$0102,(a0)+
        dbra    d0,.gnd
        bsr     copy_shadow
.light: bra     grid_patch

; undo last frame's grid writes (from crt_shadow), advance the grid,
; write the new pink pairs straight into the copper list
grid_patch:
        lea     coplist,a2
        lea     copoff_c00,a3
        lea     crt_shadow,a4
        move.w  grid_n,d2
        beq.s   .adv
        subq.w  #1,d2
        lea     grid_prev,a0
.r:     move.w  (a0)+,d1                ; line
        add.w   d1,d1
        move.w  (a4,d1.w),d3            ; CRT'd background value
        move.w  (a3,d1.w),d0            ; copper byte offset
        move.w  d3,(a2,d0.w)
        dbra    d2,.r
.adv:   addq.w  #1,gphase
        cmp.w   #96,gphase
        blt.s   .ok
        clr.w   gphase
.ok:    lea     grid_prev,a0
        lea     persp96,a1
        moveq   #0,d5
        moveq   #0,d6                   ; lines written
.k:     move.w  gphase,d0
        move.w  d5,d1
        lsl.w   #4,d1
        add.w   d1,d0
.m:     cmp.w   #96,d0
        blt.s   .in
        sub.w   #96,d0
        bra.s   .m
.in:    moveq   #0,d1
        move.b  (a1,d0.w),d1
        add.w   #104,d1                 ; screen line of the pink pair
        move.w  d1,(a0)+
        addq.w  #1,d6
        move.w  d1,d0
        add.w   d0,d0
        move.w  (a3,d0.w),d0
        move.w  #$f3b,(a2,d0.w)         ; hot pink line, 2 px tall
        cmp.w   #254,d1
        bge.s   .one
        addq.w  #1,d1
        move.w  d1,(a0)+
        addq.w  #1,d6
        move.w  d1,d0
        add.w   d0,d0
        move.w  (a3,d0.w),d0
        move.w  #$92c,(a2,d0.w)
.one:   addq.w  #1,d5
        cmp.w   #6,d5
        bne.s   .k
        move.w  d6,grid_n
        rts

; part two: the plasma, straight out of the copper (per-line sines
; through the web palette; the whole field breathes and drifts)
sc_plasma:
        move.w  #3,shadow_scene         ; plasma owns the copper directly:
        addq.w  #1,gphase               ; 128 line pairs, bright + dimmed
        lea     coplist,a2              ; (the CRT scanline look for free)
        lea     copoff_c00,a3
        lea     plasma_s1,a0
        lea     plasma_s2,a1
        lea     plasma_pal,a4
        move.w  gphase,d4               ; t1
        move.w  frame,d5
        add.w   d5,d5
        add.w   gphase,d5               ; t2 moves faster
        moveq   #0,d3                   ; pair 0..127
.l:     move.w  d3,d0
        add.w   d0,d0
        add.w   d4,d0
        and.w   #255,d0
        moveq   #0,d1
        move.b  (a0,d0.w),d1
        move.w  d3,d0
        lsl.w   #2,d0
        add.w   d5,d0
        and.w   #255,d0
        moveq   #0,d2
        move.b  (a1,d0.w),d2
        add.w   d2,d1
        lsr.w   #3,d1
        and.w   #31,d1
        add.w   d1,d1
        move.w  (a4,d1.w),d1            ; colour of this pair
        cmp.w   #6,d3                   ; vignette top/bottom pairs
        blt.s   .vig
        cmp.w   #122,d3
        blt.s   .wr
.vig:   lsr.w   #1,d1
        and.w   #$777,d1
.wr:    move.w  d3,d0
        lsl.w   #2,d0                   ; even line's table entry
        move.w  (a3,d0.w),d2
        move.w  d1,(a2,d2.w)
        lsr.w   #1,d1                   ; odd line dimmed
        and.w   #$777,d1
        addq.w  #2,d0
        move.w  (a3,d0.w),d2
        move.w  d1,(a2,d2.w)
        addq.w  #1,d3
        cmp.w   #128,d3
        bne.s   .l
        rts

; finale: rolling rainbow sky over the grid ground.  The ground is
; poked once; the 52 sky pairs and the grid are patched per frame.
sc_finale:
        move.w  scene,d0
        cmp.w   shadow_scene,d0
        beq.s   .light
        move.w  d0,shadow_scene
        clr.w   grid_n
        bsr     shadow_black
        lea     shadow+104*2,a0
        move.w  #151,d0
.gnd:   move.w  #$0102,(a0)+
        dbra    d0,.gnd
        bsr     copy_shadow
.light: lea     coplist,a2
        lea     copoff_c00,a3
        lea     rainbow64,a1
        move.w  frame,d2
        moveq   #0,d3                   ; sky pair 0..51
.f:     move.w  d3,d1
        add.w   d2,d1
        and.w   #63,d1
        add.w   d1,d1
        move.w  (a1,d1.w),d0            ; pair colour
        cmp.w   #6,d3
        bge.s   .nv
        lsr.w   #1,d0                   ; vignette at the top
        and.w   #$777,d0
.nv:    move.w  d3,d1
        lsl.w   #2,d1                   ; even line's table entry
        move.w  (a3,d1.w),d4
        move.w  d0,(a2,d4.w)
        lsr.w   #1,d0                   ; odd line dimmed
        and.w   #$777,d0
        addq.w  #2,d1
        move.w  (a3,d1.w),d4
        move.w  d0,(a2,d4.w)
        addq.w  #1,d3
        cmp.w   #52,d3
        bne.s   .f
        bra     grid_patch

; Copy the 256-line shadow into the copper, applying the CRT pass on
; the way: odd scanlines are dimmed and the top/bottom edges get a
; vignette (halving every RGB nibble = >>1 masked with $777).
copy_shadow:
        lea     shadow,a0
        lea     copoff_c00,a1
        lea     coplist,a2
        lea     crt_shadow,a3           ; final values kept for later
        moveq   #0,d3                   ; in-place patches (grid lines)
.l:     move.w  (a0)+,d2
        move.w  d3,d1
        and.w   #1,d1
        beq.s   .even
        lsr.w   #1,d2                   ; scanline
        and.w   #$777,d2
.even:  cmp.w   #12,d3
        blt.s   .vig
        cmp.w   #244,d3
        blt.s   .keep
.vig:   lsr.w   #1,d2                   ; vignette
        and.w   #$777,d2
.keep:  move.w  d2,(a3)+
        move.w  (a1)+,d1
        move.w  d2,(a2,d1.w)
        addq.w  #1,d3
        cmp.w   #256,d3
        bne.s   .l
        rts

; the letter colour: a rolling metallic gradient normally, and the
; static sun/grid palette in the outrun scenes (85 two-line slots)
logo_colours:
        lea     copoff_c01,a1
        lea     coplist,a2
        move.w  scene,d0
        cmp.w   #2,d0
        beq.s   .sun
        cmp.w   #4,d0
        beq.s   .sun
        lea     logo_grad,a3
        move.w  frame,d2
        lsr.w   #2,d2
        moveq   #0,d0
.l:     move.w  d0,d1
        add.w   d2,d1
.m:     cmp.w   #96,d1
        blt.s   .in
        sub.w   #96,d1
        bra.s   .m
.in:    add.w   d1,d1
        move.w  (a3,d1.w),d1
        move.w  (a1)+,d3
        move.w  d1,(a2,d3.w)
        addq.w  #1,d0
        cmp.w   #85,d0
        bne.s   .l
        rts
.sun:   lea     sun_c01,a3
        moveq   #0,d0
.s:     move.w  d0,d1
        add.w   d1,d1
        move.w  (a3,d1.w),d1
        move.w  (a1)+,d3
        move.w  d1,(a2,d3.w)
        addq.w  #1,d0
        cmp.w   #85,d0
        bne.s   .s
        rts

; ===================================================================
;  The cast: dirty-rectangle clears + draws into the hidden buffer
; ===================================================================
do_cast:
        ; on a scene change, wipe all four bob planes once and forget
        ; every slot (the per-frame work is dirty rectangles only)
        move.w  scene,d0
        cmp.w   cur_scene,d0
        beq     .same
        move.w  d0,cur_scene
        lea     plane1a,a0
        bsr     init_wipe
        lea     plane2a,a0
        bsr     init_wipe
        lea     plane1b,a0
        bsr     init_wipe
        lea     plane2b,a0
        bsr     init_wipe
        bsr     inval_slots
        ; the outrun scenes get the sun + grid verticals in plane 0;
        ; the plasma scene gets a clean zone
        move.w  cur_scene,d0
        cmp.w   #2,d0
        beq.s   .ovl
        cmp.w   #4,d0
        beq.s   .ovl
        cmp.w   #3,d0
        bne.s   .same
        lea     plane0a+16*PLANEB,a0
        moveq   #22,d0
        move.w  #171,d1
        moveq   #0,d2
        bsr     blt_clear
        lea     plane0b+16*PLANEB,a0
        moveq   #22,d0
        move.w  #171,d1
        moveq   #0,d2
        bsr     blt_clear
        bra.s   .same
.ovl:   lea     plane0a+16*PLANEB,a1
        bsr     copy_ovl
        lea     plane0b+16*PLANEB,a1
        bsr     copy_ovl
.same:
        ; wipe every slot's previous rectangle BEFORE anything draws —
        ; clearing inside the draw calls let one object's clear bite
        ; a neighbour that had already drawn this frame
        moveq   #0,d5
.ca:    bsr     slot_clear
        addq.w  #1,d5
        cmp.w   #8,d5
        bne.s   .ca
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

; ---- walking bob: d0=x d1=y, d5=slot, a3=frame ptrs (p1/p2) ----
draw_bob:
        movem.l d0-d1/a1/a3,-(sp)
        bsr     slot_store              ; (rect already cleared in do_cast)
        move.l  (a3),a0                 ; plane-1 image
        move.w  d1,d2
        mulu    #PLANEB,d2
        move.l  cur_p1,a1
        adda.l  d2,a1
        move.w  #42,d1
        bsr     blt_img
        movem.l (sp),d0-d1/a1/a3
        move.l  4(a3),a0                ; plane-2 image
        move.w  d1,d2
        mulu    #PLANEB,d2
        move.l  cur_p2,a1
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
        bpl.s   .cok
        bsr     slot_hide
        bra.s   .cn
.cok:
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
        bpl.s   .hok
        bsr     slot_hide
        bra.s   .hn
.hok:
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
        ; the big magic circle drifting on a lissajous, like the web's
        lea     rot_sine,a0
        move.w  frame,d0
        and.w   #255,d0
        move.b  (a0,d0.w),d1
        ext.w   d1
        muls    #100,d1
        asr.l   #7,d1
        add.w   #112,d1
        move.w  d1,d0                   ; x = 12..212
        move.w  frame,d1
        add.w   d1,d1
        add.w   #64,d1
        and.w   #255,d1
        move.b  (a0,d1.w),d2
        ext.w   d2
        asr.w   #2,d2
        add.w   #58,d2
        move.w  d2,d1                   ; y = 26..90
        moveq   #3,d5
        bsr     draw_circle64
        rts

cast_tunnel:
        moveq   #0,d5
.d:     bsr     walk_pos
        tst.w   d0
        bpl.s   .dok
        bsr     slot_hide
        bra.s   .dn
.dok:
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
        bpl.s   .fok
        bsr     slot_hide
        bra.s   .cn
.fok:
        move.w  d5,d2
        and.w   #1,d2
        bne.s   .fh
        move.w  frame,d2                ; cats: 4-frame saw animation
        lsr.w   #2,d2
        add.w   d5,d2
        and.w   #3,d2
        lsl.w   #3,d2
        lea     cat_frames,a3
        adda.w  d2,a3
        bra.s   .fd
.fh:    move.w  frame,d2                ; horses: 2-frame trot
        lsr.w   #3,d2
        add.w   d5,d2
        and.w   #1,d2
        lsl.w   #3,d2
        lea     horse_frames,a3
        adda.w  d2,a3
.fd:    bsr     draw_bob
.cn:    addq.w  #1,d5
        cmp.w   #4,d5
        bne.s   .c
        ; and the magic circle joins the finale party
        lea     rot_sine,a0
        move.w  frame,d0
        and.w   #255,d0
        move.b  (a0,d0.w),d1
        ext.w   d1
        muls    #100,d1
        asr.l   #7,d1
        add.w   #112,d1
        move.w  d1,d0
        move.w  frame,d1
        add.w   d1,d1
        add.w   #64,d1
        and.w   #255,d1
        move.b  (a0,d1.w),d2
        ext.w   d2
        asr.w   #2,d2
        add.w   #58,d2
        move.w  d2,d1
        moveq   #4,d5
        bsr     draw_circle64
        rts

; ===================================================================
;  Vector spaceships (drop scene): CPU XOR outline -> blitter fill ->
;  OR into both bob planes (colour 6, with parity cockpit holes)
; ===================================================================
SHIPBUF_W = 4                   ; words (64 px)
SHIPBUF_H = 56
CLSBUF    = SHIPBUF_W*2*SHIPBUF_H

; ===================================================================
;  The web version's ships, for real: the Spaceships.ts mesh (cone
;  fuselage / rear block / delta wing, from gen_amiga.py) flying the
;  Spaceships.ts paths — sin(t*.5) sweeps with lookAt heading and
;  bank-into-the-turn — transformed in 3D, backface-culled, parity-
;  filled by the blitter in three shaded colour classes.
;  The pipeline was validated against a pixel-exact Python simulator
;  (0 parity leaks over 32 pose renders).
; ===================================================================
NSHIPS = 2

cast_ships:
        moveq   #0,d7
.ship:  bsr     ship_pose               ; angles + position for ship d7
        tst.w   ship_on
        beq     .off
        move.w  d7,d5
        move.w  ship_x,d0
        move.w  ship_y,d1
        bsr     slot_store
        ; the image is re-rendered every 4th frame (position still
        ; moves at 50 Hz; the pose lags a few frames, invisibly)
        move.w  frame,d0
        and.w   #3,d0
        move.w  d7,d1
        add.w   d1,d1
        cmp.w   d1,d0
        bne.s   .place
        ; queue the three buffer clears, then transform on the CPU
        ; while the blitter works through them
        moveq   #0,d6
.clr:   bsr     set_sbuf
        move.l  cur_sbuf,a0
        moveq   #SHIPBUF_W,d0
        move.w  #SHIPBUF_H,d1
        moveq   #0,d2
        bsr     blt_clear
        addq.w  #1,d6
        cmp.w   #3,d6
        bne.s   .clr
        bsr     ship_transform          ; all vertices -> poly_xy
        moveq   #0,d6                   ; colour class 0/1/2
.cls:   bsr     set_sbuf
        bsr     class_render
        move.w  d7,d0
        add.w   d0,d0
        add.w   d7,d0
        add.w   d6,d0
        add.w   d0,d0
        lea     cls_flags,a0
        move.w  cls_any,(a0,d0.w)
        addq.w  #1,d6
        cmp.w   #3,d6
        bne.s   .cls
.place: moveq   #0,d6
.pl:    move.w  d7,d0
        add.w   d0,d0
        add.w   d7,d0
        add.w   d6,d0
        add.w   d0,d0
        lea     cls_flags,a0
        tst.w   (a0,d0.w)
        beq.s   .np
        bsr     set_sbuf
        move.w  d6,d0
        bsr     class_place
.np:    addq.w  #1,d6
        cmp.w   #3,d6
        bne.s   .pl
        bra.s   .next
.off:   move.w  d7,d5
        bsr     slot_hide
.next:  addq.w  #1,d7
        cmp.w   #NSHIPS,d7
        bne     .ship
        rts

; cur_sbuf = the render buffer of ship d7, class d6
set_sbuf:
        movem.l d0/a0,-(sp)
        move.w  d7,d0
        add.w   d0,d0
        add.w   d7,d0
        add.w   d6,d0
        mulu    #CLSBUF,d0
        lea     shipbufs,a0
        adda.l  d0,a0
        move.l  a0,cur_sbuf
        movem.l (sp)+,d0/a0
        rts

; ---- advance the path counters, derive pos / heading / bank ----
ship_pose:
        movem.l d0-d6/a0-a2,-(sp)
        move.w  d7,d0
        mulu    #14,d0
        lea     ship0_c,a0
        adda.w  d0,a0                   ; consts: s1,s2,s3,p2,lane,amp,depth
        move.w  d7,d0
        lsl.w   #3,d0
        lea     shipst,a1
        adda.w  d0,a1                   ; state: three 8.8 phase counters
        lea     rot_sine,a2
        move.w  (a1),d1                 ; a1 += s1
        add.w   (a0),d1
        move.w  d1,(a1)
        move.w  2(a1),d2                ; a2 += s2
        add.w   2(a0),d2
        move.w  d2,2(a1)
        move.w  4(a1),d3                ; a3 += s3
        add.w   4(a0),d3
        move.w  d3,4(a1)
        lsr.w   #8,d1                   ; angle indices
        lsr.w   #8,d2
        lsr.w   #8,d3

        ; x_w = sin(a1)*96>>7 + lane
        moveq   #0,d4
        move.b  (a2,d1.w),d4
        ext.w   d4
        muls    #96,d4
        asr.l   #7,d4
        add.w   8(a0),d4
        move.w  d4,ship_wx
        ; y_w = sin(a2)*amp>>7 + 8
        moveq   #0,d4
        move.b  (a2,d2.w),d4
        ext.w   d4
        muls    10(a0),d4
        asr.l   #7,d4
        addq.w  #8,d4
        move.w  d4,ship_wy
        ; z_w = depth + cos(a3)*32>>7
        move.w  d3,d5
        add.w   #64,d5
        and.w   #255,d5
        moveq   #0,d4
        move.b  (a2,d5.w),d4
        ext.w   d4
        asl.w   #5,d4
        asr.w   #7,d4
        add.w   12(a0),d4
        move.w  d4,ship_wz

        ; tangent: tx = cos(a1)*48>>7, ty = cos(a2)*amp>>7, tz = -sin(a3)*13>>7
        move.w  d1,d5
        add.w   #64,d5
        and.w   #255,d5
        moveq   #0,d0
        move.b  (a2,d5.w),d0
        ext.w   d0
        muls    #48,d0
        asr.l   #7,d0                   ; tx
        move.w  d2,d5
        add.w   #64,d5
        and.w   #255,d5
        moveq   #0,d4
        move.b  (a2,d5.w),d4
        ext.w   d4
        muls    10(a0),d4
        asr.l   #7,d4                   ; ty (dy of the path)
        moveq   #0,d5
        move.b  (a2,d3.w),d5
        ext.w   d5
        muls    #-13,d5
        asr.l   #7,d5                   ; tz

        ; heading: yaw = atan2(tz, tx); pitch/bank from ty (small angle)
        move.w  d5,d1
        move.w  d0,d2
        bsr     atan2_idx               ; d1=y, d2=x -> d0 = 0..255
        move.w  d0,ship_yaw
        move.w  d4,d0
        asr.w   #1,d0
        neg.w   d0
        bsr     clamp20
        move.w  d0,ship_pitch
        move.w  d4,d0
        bsr     clamp20
        move.w  d0,ship_bank

        ; perspective scale from depth
        move.w  ship_wz,d0
        add.w   #96,d0
        bpl.s   .zp
        moveq   #0,d0
.zp:    lsr.w   #1,d0
        cmp.w   #SCALE_TAB_N-1,d0
        ble.s   .zi
        move.w  #SCALE_TAB_N-1,d0
.zi:    add.w   d0,d0
        lea     scale_tab,a0
        move.w  (a0,d0.w),d5
        move.w  d5,ship_scale

        ; screen top-left of the 64x56 work buffer
        move.w  ship_wx,d0
        muls    d5,d0
        asr.l   #7,d0
        add.w   #128,d0                 ; centre 160 - 32
        move.w  ship_wy,d1
        muls    d5,d1
        asr.l   #8,d1
        neg.w   d1
        add.w   #56,d1
        move.w  #1,ship_on
        cmp.w   #0,d0
        blt.s   .hide
        cmp.w   #286,d0
        bgt.s   .hide
        move.w  d0,ship_x
        move.w  d1,ship_y
        bra.s   .out
.hide:  clr.w   ship_on
.out:   movem.l (sp)+,d0-d6/a0-a2
        rts

clamp20:
        cmp.w   #20,d0
        ble.s   .n
        moveq   #20,d0
.n:     cmp.w   #-20,d0
        bge.s   .p
        moveq   #-20,d0
.p:     rts

; d1 = y, d2 = x -> d0 = atan2 angle in 256-per-turn units
atan2_idx:
        movem.l d1-d4,-(sp)
        moveq   #0,d3                   ; sign bits: 1 = y<0, 2 = x<0
        tst.w   d1
        bge.s   .yp
        neg.w   d1
        moveq   #1,d3
.yp:    tst.w   d2
        bge.s   .xp
        neg.w   d2
        addq.w  #2,d3
.xp:    move.w  d1,d4
        or.w    d2,d4
        bne.s   .nz
        moveq   #0,d0
        bra.s   .oct
.nz:    cmp.w   d2,d1
        bgt.s   .ymaj
        move.w  d1,d0                   ; r = y*32/x
        lsl.w   #5,d0
        divu    d2,d0
        and.w   #63,d0
        lea     atan_tab,a0
        move.b  (a0,d0.w),d0
        ext.w   d0
        bra.s   .oct
.ymaj:  move.w  d2,d0                   ; r = x*32/y -> 64 - atan
        lsl.w   #5,d0
        divu    d1,d0
        and.w   #63,d0
        lea     atan_tab,a0
        move.b  (a0,d0.w),d0
        ext.w   d0
        neg.w   d0
        add.w   #64,d0
.oct:   ; fold into the right quadrant by the saved signs
        cmp.w   #2,d3
        blt.s   .q01
        beq.s   .q2
        ; x<0, y<0 -> 128 + t
        add.w   #128,d0
        bra.s   .done
.q2:    ; x<0, y>=0 -> 128 - t
        neg.w   d0
        add.w   #128,d0
        bra.s   .done
.q01:   tst.w   d3
        beq.s   .done                   ; x>=0, y>=0 -> t
        neg.w   d0                      ; x>=0, y<0 -> -t
.done:  and.w   #255,d0
        movem.l (sp)+,d1-d4
        rts

; ---- transform all mesh vertices into poly_xy (matches the sim) ----
ship_transform:
        movem.l d0-d7/a0-a2,-(sp)
        lea     rot_sine,a2
        move.w  ship_yaw,d0
        bsr     sincos                  ; d1 = sin, d2 = cos
        move.w  d1,t_sy
        move.w  d2,t_cy
        move.w  ship_pitch,d0
        bsr     sincos
        move.w  d1,t_sp
        move.w  d2,t_cp
        move.w  ship_bank,d0
        bsr     sincos
        move.w  d1,t_sb
        move.w  d2,t_cb
        lea     ship_verts,a0
        lea     poly_xy,a1
        move.w  #SHIP_NVERT-1,d7
.v:     movem.w (a0)+,d0-d2             ; x y z
        move.w  d0,d3
        muls    t_cy,d3
        move.w  d2,d4
        muls    t_sy,d4
        sub.l   d4,d3
        asr.l   #7,d3                   ; x1
        move.w  d0,d4
        muls    t_sy,d4
        move.w  d2,d0
        muls    t_cy,d0
        add.l   d4,d0
        asr.l   #7,d0                   ; z1
        move.w  d3,d4
        muls    t_cp,d4
        move.w  d1,d2
        muls    t_sp,d2
        sub.l   d2,d4
        asr.l   #7,d4                   ; x2
        muls    t_sp,d3
        muls    t_cp,d1
        add.l   d1,d3
        asr.l   #7,d3                   ; y2
        muls    t_cb,d3
        muls    t_sb,d0
        sub.l   d0,d3
        asr.l   #7,d3                   ; y3
        muls    ship_scale,d4
        asr.l   #7,d4
        add.w   #32,d4
        bpl.s   .x0
        moveq   #0,d4
.x0:    cmp.w   #63,d4
        ble.s   .x1
        moveq   #63,d4
.x1:    muls    ship_scale,d3
        asr.l   #7,d3
        add.w   #27,d3
        bpl.s   .y0
        moveq   #0,d3
.y0:    cmp.w   #55,d3
        ble.s   .y1
        moveq   #55,d3
.y1:    move.w  d4,(a1)+
        move.w  d3,(a1)+
        dbra    d7,.v
        movem.l (sp)+,d0-d7/a0-a2
        rts

; d0 = angle idx -> d1 = sin, d2 = cos (from rot_sine, +-127)
sincos:
        and.w   #255,d0
        moveq   #0,d1
        move.b  (a2,d0.w),d1
        ext.w   d1
        add.w   #64,d0
        and.w   #255,d0
        moveq   #0,d2
        move.b  (a2,d0.w),d2
        ext.w   d2
        rts

; ---- XOR-outline and fill every visible face of class d6 ----
class_render:                           ; buffer pre-cleared by caller
        movem.l d0-d7/a0-a3,-(sp)
        clr.w   cls_any
        lea     ship_faces,a3
        move.w  #SHIP_NFACE,d7
.f:     moveq   #0,d4
        move.b  (a3)+,d4                ; class
        moveq   #0,d5
        move.b  (a3)+,d5                ; vertex count
        cmp.w   d6,d4
        beq.s   .mine
        adda.w  d5,a3
        bra     .nf
.mine:  ; backface cull: signed area of the first three points
        lea     poly_xy,a1
        moveq   #0,d0
        move.b  (a3),d0
        lsl.w   #2,d0
        movem.w (a1,d0.w),d1-d2         ; x0 y0
        moveq   #0,d0
        move.b  1(a3),d0
        lsl.w   #2,d0
        movem.w (a1,d0.w),d3-d4         ; x1 y1
        sub.w   d1,d3
        sub.w   d2,d4
        moveq   #0,d0
        move.b  2(a3),d0
        lsl.w   #2,d0
        move.w  2(a1,d0.w),d0           ; y2
        sub.w   d2,d0
        muls    d0,d3                   ; (x1-x0)*(y2-y0)
        moveq   #0,d0
        move.b  2(a3),d0
        lsl.w   #2,d0
        move.w  (a1,d0.w),d0            ; x2
        sub.w   d1,d0
        muls    d0,d4                   ; (y1-y0)*(x2-x0)
        sub.l   d4,d3
        cmp.l   #6,d3
        ble.s   .cull
        ; visible: XOR each edge (closing back to the first vertex)
        move.w  #1,cls_any
        moveq   #0,d3                   ; edge counter
.e:     moveq   #0,d0
        move.b  (a3,d3.w),d0
        move.w  d3,d1
        addq.w  #1,d1
        cmp.w   d5,d1
        bne.s   .nc
        moveq   #0,d1
.nc:    moveq   #0,d2
        move.b  (a3,d1.w),d2
        move.w  d2,d1
        bsr     edge_from_idx
        addq.w  #1,d3
        cmp.w   d5,d3
        bne.s   .e
.cull:  adda.w  d5,a3
.nf:    subq.w  #1,d7
        bne     .f
        ; parity fill (inclusive, descending)
        tst.w   cls_any
        beq.s   .out
        bsr     blt_wait
        move.w  #$09f0,BLTCON0(a6)
        move.w  #$000a,BLTCON1(a6)
        move.w  #$ffff,BLTAFWM(a6)
        move.w  #$ffff,BLTALWM(a6)
        clr.w   BLTAMOD(a6)
        clr.w   BLTDMOD(a6)
        move.l  cur_sbuf,a0
        lea     CLSBUF-2(a0),a0
        move.l  a0,BLTAPTH(a6)
        move.l  a0,BLTDPTH(a6)
        move.w  #SHIPBUF_H*64+SHIPBUF_W,BLTSIZE(a6)
.out:   movem.l (sp)+,d0-d7/a0-a3
        rts

; d0 = class -> OR the filled buffer into its plane(s)
;   class 0 (dark)   -> plane 1        class 1 (mid) -> plane 2
;   class 2 (bright) -> both planes
class_place:
        movem.l d3/a1,-(sp)
        move.w  d0,d3                   ; d3 survives the blits
        cmp.w   #1,d3
        beq.s   .p2
        move.l  cur_p1,a1               ; classes 0 and 2 hit plane 1
        bsr     face_place
        cmp.w   #2,d3
        bne.s   .done
.p2:    move.l  cur_p2,a1               ; classes 1 and 2 hit plane 2
        bsr     face_place
.done:  movem.l (sp)+,d3/a1
        rts

; d0/d1 = vertex indices -> edge_dots between their projected points
edge_from_idx:
        movem.l d0-d3/a1,-(sp)
        lea     poly_xy,a1
        add.w   d0,d0
        add.w   d0,d0                   ; idx1 * 4
        add.w   d1,d1
        add.w   d1,d1                   ; idx2 * 4
        move.w  2(a1,d1.w),d3           ; y2
        move.w  0(a1,d1.w),d2           ; x2
        move.w  2(a1,d0.w),d1           ; y1
        move.w  0(a1,d0.w),d0           ; x1
        bsr     edge_dots
        movem.l (sp)+,d0-d3/a1
        rts

; one XOR dot per scanline from (d0,d1) to (d2,d3), y half-open.
; Pointer-walking inner loop: ~30 cycles per row, no multiplies.
edge_dots:
        movem.l d0-d6/a0,-(sp)
        cmp.w   d1,d3
        beq.s   .out                    ; horizontal: no parity change
        bgt.s   .down
        exg     d0,d2
        exg     d1,d3
.down:  move.w  d2,d4
        sub.w   d0,d4                   ; dx
        move.w  d3,d5
        sub.w   d1,d5                   ; dy > 0
        ext.l   d4
        asl.l   #8,d4
        divs    d5,d4                   ; x step, 8.8
        move.w  d0,d2
        asl.w   #8,d2                   ; x accumulator, 8.8
        move.l  cur_sbuf,a0
        move.w  d1,d0                   ; start row pointer (one mul)
        mulu    #SHIPBUF_W*2,d0
        adda.w  d0,a0
        move.w  d5,d6
        subq.w  #1,d6
.yl:    move.w  d2,d0
        asr.w   #8,d0
        cmp.w   #SHIPBUF_W*16-1,d0
        bhi.s   .sk                     ; x outside (negative too)
        move.w  d0,d1
        lsr.w   #3,d1
        not.w   d0
        and.w   #7,d0
        bchg    d0,(a0,d1.w)            ; XOR the parity dot
.sk:    add.w   d4,d2
        lea     SHIPBUF_W*2(a0),a0
        dbra    d6,.yl
.out:   movem.l (sp)+,d0-d6/a0
        rts

; ---- OR the filled face buffer into plane a1 at the ship position ----
face_place:
        move.l  cur_sbuf,a0
        move.w  ship_y,d2
        mulu    #PLANEB,d2
        adda.l  d2,a1
        move.w  ship_x,d0
        move.w  #SHIPBUF_H,d1
        bra     blt_img4

; OR-blit a 64px-wide image: 5-word blit with shift
blt_img4:
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
        move.w  #PLANEB-10,BLTCMOD(a6)
        move.w  #PLANEB-10,BLTDMOD(a6)
        move.l  a0,BLTAPTH(a6)
        move.w  d0,d2
        asr.w   #4,d2
        add.w   d2,d2
        lea     (a1,d2.w),a2
        move.l  a2,BLTCPTH(a6)
        move.l  a2,BLTDPTH(a6)
        move.w  d1,d2
        lsl.w   #6,d2
        or.w    #5,d2
        move.w  d2,BLTSIZE(a6)
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
        move.l  #plane0a,lyrdst         ; draw the cue into both buffers
        bsr     render_lyric
        move.l  #plane0b,lyrdst
        bsr     render_lyric
        addq.w  #1,lyr_idx
        bra.s   .chk
.wrapped:
        move.w  d0,prev_bar
        clr.w   lyr_idx
        lea     plane0a,a1              ; bring the pristine title back
        bsr     copy_title              ; in both display buffers
        lea     plane0b,a1
        bsr     copy_title
.done:  rts

; render the lyric cue lyr_idx into the plane at lyrdst (zone cleared)
render_lyric:
        movem.l d0-d7/a0-a4,-(sp)
        move.l  lyrdst,a0
        adda.l  #LYRZ_Y0*PLANEB,a0
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
        move.l  lyrdst,a1
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
        move.l  lyrdst,a1
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
        move.l  cur_p0,a0
        adda.l  #DYCP_Y*PLANEB,a0
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
        move.l  cur_p0,a1
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
ship_yaw:   dc.w 0
ship_pitch: dc.w 0
ship_bank:  dc.w 0
ship_x:     dc.w 0
ship_y:     dc.w 0
ship_wx:    dc.w 0
ship_wy:    dc.w 0
ship_wz:    dc.w 0
ship_scale: dc.w 0
ship_on:    dc.w 0
cls_any:    dc.w 0
t_sy:       dc.w 0
t_cy:       dc.w 0
t_sp:       dc.w 0
t_cp:       dc.w 0
t_sb:       dc.w 0
t_cb:       dc.w 0
shipst:     ds.b 16             ; 2 ships x three 8.8 phase counters
front:      dc.w 0
cur_p0:     dc.l 0
cur_p1:     dc.l 0
cur_p2:     dc.l 0
lyrdst:     dc.l 0
buf0:       dc.l plane0a,plane0b
buf1:       dc.l plane1a,plane1b
buf2:       dc.l plane2a,plane2b
prevs:      ds.b 64             ; 2 banks x 8 slots x (x.w, y.w)
cur_sbuf:   dc.l 0              ; render buffer of the ship class in hand
cls_flags:  ds.w 6              ; per ship+class: cached image non-empty
shadow_scene: dc.w -1           ; scene the copper background is built for
grid_n:     dc.w 0              ; copper lines patched by the grid
grid_prev:  ds.w 12
crt_shadow: ds.w 256            ; CRT-processed value of every bg line
mt_songpos: dc.w 0
mt_row:     dc.w 0
mt_counter: dc.w 0
mt_speed:   dc.w 6
mt_trigmask: dc.w 0
mt_patterns: dc.l 0
mt_samples: ds.b 31*14
mt_chan:    ds.b MC_SIZE*4
shadow:     ds.w 256
poly_xy:    ds.w 64             ; SHIP_NVERT (23) x/y pairs + margin

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

mod_data:
        incbin  "motorsag.mod"
        even
logo_src:
        incbin  "logo.raw"              ; pristine title screen
        even
drop_ovl:
        incbin  "dropovl.raw"           ; sun + grid verticals overlay
        even

; double-buffered display: two full sets of the three bitplanes;
; draw into one while the copper shows the other
        section chipbss,bss_c
plane0a:  ds.b PLANEB*256
plane1a:  ds.b PLANEB*256
plane2a:  ds.b PLANEB*256
plane0b:  ds.b PLANEB*256
plane1b:  ds.b PLANEB*256
plane2b:  ds.b PLANEB*256
shipbufs: ds.b CLSBUF*6         ; 2 ships x 3 colour classes
