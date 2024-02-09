; TODO:
; rename subroutines to have a consistent convention
; rewrite palette data transfer to use size of Palette struct
; delete unused startup segment
; fix oam data transfer bug with comparison of X
; add missing register definitions

PPUCTRL = $2000 ; PPU control flags
                ; VPHB SINN
                ; NMI enable (V) PPU master/slave (P) sprite height (H) background tile select (B)
                ; sprite tile select (S) increment mode (I) nametable select (NN)

PPUMASK = $2001 ; mask control, color settings **use greyscale mask for interesting effect ?
PPUSTATUS = $2002 ; PPU status flags
                  ; VSO- ---- 
                  ; vblank flag (V) sprite 0hit (S) sprite overflow (O) unused (-)
                  ; NOTE: read from this address to reset write flag for PPUADDR
                  ; to allow PPU VRAM address to be changed
OAMADDR = $2003 ; points to address of OAM being used, usually ignored and set to $00 as DMA is better
OAMDATA = $2004 ; OAM data read/write
PPUADDR = $2006 ; PPU accessing address read/write (2 byte address, HI byte first. Read from $2002 before this.)
PPUDATA = $2007 
DMC_FREQ = $4010

CNTPORT1 = $4016
CNTPORT2 = $4017

.struct Sprite_1x1
    ypos .byte
    index .byte
    attributes .byte
    xpos .byte
.endstruct

.struct Palette
    col0 .byte
    col1 .byte
    col2 .byte
    col3 .byte
.endstruct

.segment "HEADER"
    .byte "NES", $1a    ; iNES header format
    .byte $02           ; 2 segments 16kb PRG
    .byte $01           ; 1 segments 8kb CHR
    .byte $01           ; mapper 0
    .byte $00           ; set mirroring vertical

.segment "VECTORS"
    .addr nmi
    .addr reset
    .addr 0 ; irq unused

.segment "STARTUP"

.segment "ZEROPAGE"
    square: .res .sizeof(Sprite_1x1)
    cnt1buttons: .res 1
    nmiflag: .res 1

.segment "CODE"
nmi:
    svregs:
        pha
        tya
        pha
        txa
        pha

        lda #$01
        sta nmiflag

    initoam:
        ldx #$00    ; OAMADDR 0
        stx OAMADDR
        clc

    oamtransfer:
        lda square, x
        sta OAMDATA
        inx
        cpx .sizeof(Sprite_1x1)     ; broken, only does not branch when X = 0
        bne oamtransfer             ; should branch only when x is from 1 - 3

    ldregs:
        pla
        tax
        pla
        tay
        pla
        rti

nmiwaitunsafe:
    bit PPUSTATUS
    bpl nmiwaitunsafe
    rts

nmiwaitsafe:
    lda nmiflag
    beq nmiwaitsafe
    lda #$00
    sta nmiflag
    rts

reset:
    sei ; disable irq
    cld ; disable broken decimal mode

    ldx #$40   ; disable APU irqs
    stx $4017
    
    ldx #$ff  ; initialize stack
    txs
    
    inx ; X: 255 -> 0

    stx PPUCTRL ; disable nmi
    stx PPUMASK ; disable screen output 
    stx DMC_FREQ ; disable APU DMC (delta modulation channel) irqs

    jsr nmiwaitunsafe
    
    clearmem:
        lda #$00
        sta $0000, x
        sta $0100, x
        sta $0200, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne clearmem

    jsr nmiwaitunsafe

    ldpalettes:
        lda PPUSTATUS ; read from $2002 to clear PPUADDR write flag

        lda #$3f
        sta PPUADDR
        lda #$00
        sta PPUADDR

        ldx #$00

    @bgpaletteld:
        lda bgpalettes, x
        sta PPUDATA
        inx
        cpx #$10
        bne @bgpaletteld
    
        ldx #$00

    @sprpaletteld:
        lda sprpalettes, x
        sta PPUDATA
        inx
        cpx #$10
        bne @sprpaletteld

    enablerender:
        lda #$80 ; nmi enable
        sta PPUCTRL

        lda #%00010000 ; sprite enable
        sta PPUMASK

    initpos:
        lda #$08
        sta square+Sprite_1x1::xpos
        lda #$10
        sta square+Sprite_1x1::ypos

    main:
        jsr readcnt1
    ; 76543210
    ; ABsSUDLR - controller buttons

    @left:
        lda cnt1buttons
        and #%00000010
        beq @up
        lda square+Sprite_1x1::xpos
        cmp #$08
        beq @up
        sec
        sbc #$01
        sta square+Sprite_1x1::xpos
        
    @up:
        lda cnt1buttons
        and #%00001000
        beq @right
        lda square+Sprite_1x1::ypos
        cmp #$0e
        beq @right
        sec
        sbc #$01
        sta square+Sprite_1x1::ypos
    
    @right:
        lda cnt1buttons
        and #%00000001
        beq @down
        lda square+Sprite_1x1::xpos
        cmp #$f0
        beq @down
        clc
        adc #$01
        sta square+Sprite_1x1::xpos

    @down:
        lda cnt1buttons
        and #%00000100
        beq @endinput
        lda square +Sprite_1x1::ypos
        cmp #$d7
        beq @endinput
        clc
        adc #$01
        sta square+Sprite_1x1::ypos

    @endinput:
        jsr nmiwaitsafe
        jmp main

    readcnt1:
        lda #$01
        sta CNTPORT1 ; write 1 then 0 to controller port to start serial transfer
        sta cnt1buttons ; store 1 in buttons
        lsr a ; A: 1 -> 0
        sta CNTPORT1

    @ldbuttons:
        lda CNTPORT1
        lsr a
        rol cnt1buttons
        bcc @ldbuttons
        rts

    bgpalettes:
    ; BG palettes, 4 total
        .byte $0f, $00, $00, $00 ; BG palette 1 ;; black, empty, empty, empty
        .byte $00, $00, $00, $00 ; BG palette 2 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 3 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 4 ;; empty

    sprpalettes:
        ; SPR palettes, 4 total
        .byte $0f, $12, $20, $00 ; SPR palette 1 ;; black, blue, white, empty
        .byte $00, $00, $00, $00 ; SPR palette 2 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 3 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 4 ;; empty

.segment "CHARS"
    ; sprite 0
;;;;;;;;;;;;;;;;;;;;;;;
    .byte %11111111 
    .byte %10000001 
    .byte %10000001 
    .byte %10000001 
    .byte %10000001 
    .byte %10000001 
    .byte %10000001 
    .byte %11111111

    .byte %00000000
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %01111110
    .byte %00000000
;;;;;;;;;;;;;;;;;;;;;;;