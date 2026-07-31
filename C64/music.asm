; ===================================================================
;  MOTORSAG ARKITEKT  -  SID music player + tune  (PAL, 50 Hz)
; -------------------------------------------------------------------
;  A small 3-voice tracker-style driver.  Called once per frame.
;
;  Per-voice character that makes it sound like a real SID:
;    * arpeggios       (the classic chord shimmer on one voice)
;    * pulse-width mod  (moving, ping-ponged PWM sweep)
;    * vibrato          (delayed, on the lead)
;    * hard-ish gate retrigger for punchy attacks
;
;  Data format (per pattern, a stream of events):
;    $01..$60 , dur   : play note (1..96 = C-0..B-7) for dur frames
;    $00      , dur   : rest (gate off) for dur frames
;    $FD      , dur   : tie/hold current note for dur frames (no retrig)
;    $FE      , inst  : select instrument
;    $FF              : end of pattern -> advance this voice's order list
;
;  Order list (per voice): pattern ids, terminated by $FF = loop to start.
; ===================================================================

SID = $d400

; ---- zero page scratch used by the player ----
mptr = $f8          ; pattern read pointer (16-bit)
optr = $fa          ; order  read pointer (16-bit)
enote = $fc         ; effective note (byte)
frq   = $fd         ; working frequency (16-bit: $fd/$fe)

; -------------------------------------------------------------------
;  Initialise the player: silence SID, reset all voice state.
; -------------------------------------------------------------------
music_init:
        ; clear all 25 SID registers
        lda #0
        ldx #24
-       sta SID,x
        dex
        bpl -
        sta beat_flag
        sta frame_ctr

        ; set volume to max (no filter routing)
        lda #$0f
        sta SID+24

        ; per-voice: point order pointers at the three order lists,
        ; force an immediate fetch by setting wait = 0, load a default inst.
        ldx #2
.vi:
        lda ord_start_lo,x
        sta ord_lo,x
        lda ord_start_hi,x
        sta ord_hi,x
        lda #0
        sta v_wait,x            ; 0 -> fetch on first tick
        sta v_arpidx,x
        sta v_vibph,x
        sta v_pending,x
        ; prime pat pointer from first order entry
        jsr load_order_entry    ; X preserved
        dex
        bpl .vi
        rts

; -------------------------------------------------------------------
;  Main entry - call once per frame (50 Hz) from the raster IRQ.
; -------------------------------------------------------------------
music_play:
        inc frame_ctr
        ldx #0
.loop:
        stx vx
        lda v_wait,x
        bne .nofetch
        jsr fetch_event         ; X = voice, sets note/rest/tie + wait
        ldx vx
.nofetch:
        dec v_wait,x
        jsr voice_effects       ; applies arp/vib/pwm, writes freq/pw
        ldx vx
        inx
        cpx #3
        bne .loop
        rts

; -------------------------------------------------------------------
;  fetch_event : advance voice X to its next note/rest/tie.
;  Loops internally over zero-length commands (inst set, end-of-pat).
; -------------------------------------------------------------------
fetch_event:
        lda pat_lo,x
        sta mptr
        lda pat_hi,x
        sta mptr+1
.next:
        ldy #0
        lda (mptr),y
        cmp #$ff
        bne .not_end
        ; end of pattern -> advance order list, reload pat pointer
        jsr next_order
        jmp .next
.not_end:
        cmp #$fe
        bne .not_inst
        ; select instrument (byte after)
        ldy #1
        lda (mptr),y
        ldx vx
        jsr load_instrument     ; A = inst id, X = voice
        jsr adv2
        jmp .next
.not_inst:
        cmp #$fd
        bne .not_tie
        ; tie: keep sounding, just set wait (no retrigger)
        ldy #1
        lda (mptr),y
        ldx vx
        sta v_wait,x
        jsr adv2
        jmp .store
.not_tie:
        cmp #$00
        bne .is_note
        ; rest: gate off, set wait
        ldy #1
        lda (mptr),y
        ldx vx
        sta v_wait,x
        ldy sidoff,x
        lda v_wave,x
        and #$fe                ; clear gate bit -> release
        sta SID+4,y
        jsr adv2
        jmp .store
.is_note:
        ; note 1..96 in A
        ldx vx
        sta v_note,x
        ldy #1
        lda (mptr),y
        sta v_wait,x
        jsr trigger_note        ; X = voice
        jsr adv2
        ; fall through to store
.store:
        ldx vx
        lda mptr
        sta pat_lo,x
        lda mptr+1
        sta pat_hi,x
        rts

; advance mptr by 2
adv2:
        lda mptr
        clc
        adc #2
        sta mptr
        bcc +
        inc mptr+1
+       rts

; -------------------------------------------------------------------
;  next_order : move voice X to next pattern in its order list,
;  looping at $FF.  Loads pat pointer + mptr.
; -------------------------------------------------------------------
next_order:
        ldx vx
        ; advance order pointer by 1
        lda ord_lo,x
        clc
        adc #1
        sta ord_lo,x
        bcc +
        inc ord_hi,x
+       jsr load_order_entry
        ; reload mptr from the (new) pattern pointer
        lda pat_lo,x
        sta mptr
        lda pat_hi,x
        sta mptr+1
        rts

; -------------------------------------------------------------------
;  load_order_entry : read pattern id at ord pointer for voice X.
;  If $FF, wrap to the voice's order start.  Sets pat_lo/hi.
; -------------------------------------------------------------------
load_order_entry:
        lda ord_lo,x
        sta optr
        lda ord_hi,x
        sta optr+1
        ldy #0
        lda (optr),y
        cmp #$ff
        bne .have
        ; loop order list
        lda ord_start_lo,x
        sta ord_lo,x
        sta optr
        lda ord_start_hi,x
        sta ord_hi,x
        sta optr+1
        ldy #0
        lda (optr),y
.have:
        ; A = pattern id -> look up address
        tay
        lda pat_addr_lo,y
        sta pat_lo,x
        lda pat_addr_hi,y
        sta pat_hi,x
        rts

; -------------------------------------------------------------------
;  load_instrument : A = inst id, X = voice.  Copies inst params
;  into the voice's live state.
; -------------------------------------------------------------------
load_instrument:
        sta v_inst,x
        tay
        lda in_wave,y
        sta v_wave,x
        lda in_ad,y
        sta v_ad,x
        lda in_sr,y
        sta v_sr,x
        lda in_pwlo,y
        sta v_pwlo,x
        lda in_pwhi,y
        sta v_pwhi,x
        lda in_pwspd,y
        sta v_pwspd,x
        lda in_arp,y
        sta v_arpbase,x
        lda in_vib,y
        sta v_vibset,x
        rts

; -------------------------------------------------------------------
;  trigger_note : X = voice.  Program ADSR/PW, retrigger gate,
;  reset arp + vibrato phase.  Flags a beat on the bass voice.
; -------------------------------------------------------------------
trigger_note:
        ldy sidoff,x
        lda v_ad,x
        sta SID+5,y
        lda v_sr,x
        sta SID+6,y
        lda v_pwlo,x
        sta SID+2,y
        lda v_pwhi,x
        sta SID+3,y
        ; hard-ish restart: gate off then on within the frame
        lda v_wave,x
        and #$fe
        sta SID+4,y
        lda v_wave,x
        ora #$01
        sta SID+4,y
        lda #0
        sta v_arpidx,x
        sta v_vibph,x
        lda #VIB_DELAY
        sta v_vibdelay,x
        ; backbeat flash: voice 0 playing the SNARE (beats 2 & 4)
        cpx #0
        bne +
        lda v_inst,x
        cmp #SNARE
        bne +
        lda #1
        sta beat_flag
+       rts

; -------------------------------------------------------------------
;  voice_effects : X = voice.  Per-frame arp + vibrato + PWM.
;  Writes the final frequency and (if sweeping) pulse width.
; -------------------------------------------------------------------
voice_effects:
        ldx vx
        lda v_note,x
        bne +
        rts                     ; note 0 -> nothing sounding
+       sta enote

        ; ---- arpeggio ----
        lda v_arpbase,x
        cmp #$ff
        beq .noarp
        clc
        adc v_arpidx,x
        tay
        lda arp_data,y
        cmp #$81
        beq .arphold            ; hold: offset 0, freeze index
        cmp #$80
        bne .arpadd
        ; loop marker -> reset index, re-read first entry
        lda #0
        sta v_arpidx,x
        ldy v_arpbase,x
        lda arp_data,y
.arpadd:
        clc
        adc enote
        sta enote
        inc v_arpidx,x
        jmp .noarp
.arphold:
        ; keep enote as-is, do not advance index
.noarp:
        ; ---- base frequency from table ----
        ldy enote
        dey
        lda freqtbl_lo,y
        sta frq
        lda freqtbl_hi,y
        sta frq+1

        ; ---- vibrato ----
        lda v_vibset,x
        beq .novib
        lda v_vibdelay,x
        beq .vibgo
        dec v_vibdelay,x
        jmp .novib
.vibgo:
        lda v_vibset,x
        and #$0f
        clc
        adc v_vibph,x
        sta v_vibph,x
        and #$1f                ; 32-entry table
        tay
        lda vibsine,y
        bpl .vpos
        ; negative delta (signed add)
        clc
        adc frq
        sta frq
        lda frq+1
        adc #$ff
        sta frq+1
        jmp .novib
.vpos:
        clc
        adc frq
        sta frq
        bcc .novib
        inc frq+1
.novib:
        ; ---- write frequency ----
        ldy sidoff,x
        lda frq
        sta SID+0,y
        lda frq+1
        sta SID+1,y

        ; ---- pulse-width sweep (ping-pong) ----
        lda v_pwspd,x
        beq .done
        bmi .pwneg
        ; positive
        clc
        adc v_pwlo,x
        sta v_pwlo,x
        bcc .pwbound
        inc v_pwhi,x
        jmp .pwbound
.pwneg:
        clc
        adc v_pwlo,x
        sta v_pwlo,x
        bcs .pwbound
        dec v_pwhi,x
.pwbound:
        lda v_pwhi,x
        and #$0f
        cmp #$0e
        bcs .pwflip
        cmp #$02
        bcc .pwflip
        jmp .pwwrite
.pwflip:
        lda #0
        sec
        sbc v_pwspd,x
        sta v_pwspd,x
.pwwrite:
        ldy sidoff,x
        lda v_pwlo,x
        sta SID+2,y
        lda v_pwhi,x
        and #$0f
        sta SID+3,y
.done:
        rts

; ===================================================================
;  DATA
; ===================================================================

sidoff  !byte 0, 7, 14

; ---- per-voice live state (3 bytes each) ----
ord_lo      !byte 0,0,0
ord_hi      !byte 0,0,0
pat_lo      !byte 0,0,0
pat_hi      !byte 0,0,0
v_wait      !byte 0,0,0
v_note      !byte 0,0,0
v_inst      !byte 0,0,0
v_wave      !byte 0,0,0
v_ad        !byte 0,0,0
v_sr        !byte 0,0,0
v_pwlo      !byte 0,0,0
v_pwhi      !byte 0,0,0
v_pwspd     !byte 0,0,0
v_arpbase   !byte 0,0,0
v_arpidx    !byte 0,0,0
v_vibset    !byte 0,0,0
v_vibph     !byte 0,0,0
v_vibdelay  !byte 0,0,0
v_pending   !byte 0,0,0
vx          !byte 0
beat_flag   !byte 0
frame_ctr   !byte 0

VIB_DELAY = 10

; ===================================================================
;  INSTRUMENTS   (index 0..8)
;    0 LEAD     1 ARP_MIN  2 ARP_MAJ  3 BASS
;    4 KICK     5 SNARE    6 HAT      7 LEAD2   8 PLUCK
; ===================================================================
;              LEAD  ARPmin ARPmaj BASS  KICK  SNARE HAT   LEAD2 PLUCK
in_wave   !byte $40 , $20 , $20 , $40 , $10 , $80 , $80 , $40 , $40
in_ad     !byte $0a , $08 , $08 , $09 , $08 , $07 , $05 , $0a , $07
in_sr     !byte $b9 , $c8 , $c8 , $58 , $00 , $00 , $00 , $a8 , $88
in_pwlo   !byte $00 , $00 , $00 , $00 , $00 , $00 , $00 , $00 , $00
in_pwhi   !byte $08 , $06 , $06 , $08 , $08 , $08 , $08 , $04 , $02
in_pwspd  !byte $30 , $18 , $18 , $00 , $00 , $00 , $00 , $28 , $40
in_arp    !byte $ff , ARP_MIN_OFS , ARP_MAJ_OFS , ARP_BASS_OFS , ARP_KICK_OFS , $ff , $ff , $ff , $ff
in_vib    !byte $03 , $00 , $00 , $00 , $00 , $00 , $00 , $04 , $00

; ---- arpeggio tables : signed semitone offsets ----
;   $80 = loop to start of this arp,  $81 = hold last (freeze)
ARP_MIN_OFS  = 0
ARP_MAJ_OFS  = 5
ARP_BASS_OFS = 10
ARP_KICK_OFS = 14
arp_data
        !byte 0, 3, 7, 12, $80          ; 0  minor  (i)
        !byte 0, 4, 7, 12, $80          ; 5  major
        !byte 5, 2, 0, $81              ; 10 bass pitch-thump then hold
        !byte 30,20,12,6,0,$81          ; 14 kick pitch drop

; ===================================================================
;  PATTERN ADDRESS TABLE   (pattern id -> address)
; ===================================================================
pat_addr_lo
        !byte <p_bass_am, <p_bass_f,  <p_bass_c,  <p_bass_g,  <p_bass_e
        !byte <p_arp_am,  <p_arp_f,   <p_arp_c,   <p_arp_g,   <p_arp_e
        !byte <p_drum,    <p_lead1,   <p_lead2,   <p_lead3,   <p_lead4
pat_addr_hi
        !byte >p_bass_am, >p_bass_f,  >p_bass_c,  >p_bass_g,  >p_bass_e
        !byte >p_arp_am,  >p_arp_f,   >p_arp_c,   >p_arp_g,   >p_arp_e
        !byte >p_drum,    >p_lead1,   >p_lead2,   >p_lead3,   >p_lead4

; pattern id constants
PB_AM=0 : PB_F=1 : PB_C=2 : PB_G=3 : PB_E=4
PA_AM=5 : PA_F=6 : PA_C=7 : PA_G=8 : PA_E=9
PD=10   : PL1=11 : PL2=12 : PL3=13 : PL4=14

; ===================================================================
;  ORDER LISTS   (8 bars; chords  Am F C G | Am F G E)
; ===================================================================
ord_start_lo !byte <ord_v1, <ord_v2, <ord_v3
ord_start_hi !byte >ord_v1, >ord_v2, >ord_v3

; voice 1: 4 bars of drums, then 4 bars of lead
ord_v1  !byte PD, PD, PD, PD, PL1, PL2, PL3, PL4, $ff
; voice 2: arpeggios follow the chords
ord_v2  !byte PA_AM, PA_F, PA_C, PA_G, PA_AM, PA_F, PA_G, PA_E, $ff
; voice 3: bass follows the chords
ord_v3  !byte PB_AM, PB_F, PB_C, PB_G, PB_AM, PB_F, PB_G, PB_E, $ff

; ===================================================================
;  PATTERNS
;  Durations (frames):  8th = 12,  quarter = 24,  half = 48
; ===================================================================
E8 = 12
Q  = 24
H  = 48

; ---- BASS : driving 8th notes on the root (octave 1-2) ----
p_bass_am !byte $fe,3 : !byte a1,E8,a1,E8,a1,E8,a1,E8,a1,E8,a1,E8,a1,E8,a1,E8 : !byte $ff
p_bass_f  !byte $fe,3 : !byte f1,E8,f1,E8,f1,E8,f1,E8,f1,E8,f1,E8,f1,E8,f1,E8 : !byte $ff
p_bass_c  !byte $fe,3 : !byte c2,E8,c2,E8,c2,E8,c2,E8,c2,E8,c2,E8,c2,E8,c2,E8 : !byte $ff
p_bass_g  !byte $fe,3 : !byte g1,E8,g1,E8,g1,E8,g1,E8,g1,E8,g1,E8,g1,E8,g1,E8 : !byte $ff
p_bass_e  !byte $fe,3 : !byte e1,E8,e1,E8,e1,E8,e1,E8,e1,E8,e1,E8,e1,E8,e1,E8 : !byte $ff

; ---- ARP : chord root retriggered every 8th, arp table fills the chord ----
p_arp_am  !byte $fe,ARP_MIN : !byte a3,E8,a3,E8,a3,E8,a3,E8,a3,E8,a3,E8,a3,E8,a3,E8 : !byte $ff
p_arp_f   !byte $fe,ARP_MAJ : !byte f3,E8,f3,E8,f3,E8,f3,E8,f3,E8,f3,E8,f3,E8,f3,E8 : !byte $ff
p_arp_c   !byte $fe,ARP_MAJ : !byte c4,E8,c4,E8,c4,E8,c4,E8,c4,E8,c4,E8,c4,E8,c4,E8 : !byte $ff
p_arp_g   !byte $fe,ARP_MAJ : !byte g3,E8,g3,E8,g3,E8,g3,E8,g3,E8,g3,E8,g3,E8,g3,E8 : !byte $ff
p_arp_e   !byte $fe,ARP_MAJ : !byte e3,E8,e3,E8,e3,E8,e3,E8,e3,E8,e3,E8,e3,E8,e3,E8 : !byte $ff

; instrument id constants for readability
LEAD=0 : ARP_MIN=1 : ARP_MAJ=2 : BASS=3 : KICK=4 : SNARE=5 : HAT=6 : LEAD2=7 : PLUCK=8

; ---- DRUM bar : hats every 8th, snare on beats 2 & 4 ----
p_drum
        !byte $fe,HAT   : !byte gs5,E8
        !byte $fe,HAT   : !byte gs5,E8
        !byte $fe,SNARE : !byte a4,E8
        !byte $fe,HAT   : !byte gs5,E8
        !byte $fe,HAT   : !byte gs5,E8
        !byte $fe,HAT   : !byte gs5,E8
        !byte $fe,SNARE : !byte a4,E8
        !byte $fe,HAT   : !byte gs5,E8
        !byte $ff

; ---- LEAD : 4-bar hook over  Am F G E ----
p_lead1 !byte $fe,LEAD : !byte a4,Q, c5,Q, e5,H : !byte $ff          ; Am
p_lead2 !byte $fe,LEAD : !byte f4,Q, a4,Q, c5,H : !byte $ff          ; F
p_lead3 !byte $fe,LEAD : !byte g4,Q, b4,Q, d5,Q, g4,Q : !byte $ff    ; G
p_lead4 !byte $fe,LEAD : !byte e4,Q, gs4,Q, b4,H : !byte $ff         ; E (major -> lift)
