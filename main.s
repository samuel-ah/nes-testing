; TODO:
; sprite art ?
; figure out background displaying
; basic shooter ?
; CPU enemies ?
; collision ?

; Note: do NOT use .sizeof() to define constants in runtime

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
JOYPAD1 = $4016
CNTPORT2 = $4017

SPRSIZE = 4
SPRWIDTHHEIGHT = 8
PALETTESIZE = 4
NUMSPRS = 4

.struct Sprite_1x1
    ypos .byte
    ptrnindex .byte
    attrs .byte
    xpos .byte
.endstruct

.struct Sprite_4x4
    ypos0 .byte
    ptrnindex0 .byte
    attrs0 .byte
    xpos0 .byte

    ypos1 .byte
    ptrnindex1 .byte
    attrs1 .byte
    xpos1 .byte

    ypos2 .byte
    ptrnindex2 .byte
    attrs2 .byte
    xpos2 .byte

    ypos3 .byte
    ptrnindex3 .byte
    attrs3 .byte
    xpos3 .byte
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

.segment "ZEROPAGE"
    player: .res .sizeof(Sprite_1x1) * NUMSPRS
    joy1buttons: .res 1
    nmiflag: .res 1

.segment "STARTUP" ; unused rn but compiler yells at me :(

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

    transferoam:
        lda player, x
        sta OAMDATA
        inx
        cpx #$10 ; size of 4 sprite (4 x #$04 bytes)
        bne transferoam

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
    
    clearmem: ; X must be 0 to start
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

    @ldbgpalette:
        lda bgpalettes, x
        sta PPUDATA
        inx
        cpx #(PALETTESIZE * 4) ; size of 4 palettes (4 * #$04 bytes)
        bne @ldbgpalette
    
        ldx #$00

    @ldsprpalette:
        lda sprpalettes, x
        sta PPUDATA
        inx
        cpx #(PALETTESIZE * 4) ; size of 4 palettes (4 * #$04 bytes)
        bne @ldsprpalette

    enablerender:
        lda #$80 ; nmi enable
        sta PPUCTRL

        lda #%00010000 ; sprite enable
        sta PPUMASK

    initpos:
        lda #$08 ; starting x
        sta player+Sprite_1x1::xpos
        lda #$10 ; starting y
        sta player+Sprite_1x1::ypos
        ldx #$01
        stx player+Sprite_1x1::ptrnindex + SPRSIZE ; starting pos is same for all 4 player sprites, gets
                                               ; fixed at first NMI before first frame is even drawn
        inx
        stx player+Sprite_1x1::ptrnindex + (2 * SPRSIZE)
        inx
        stx player+Sprite_1x1::ptrnindex + (3 * SPRSIZE)

    main:
        jsr readjoy1 ; would this lead to less noticeable input lag to do at the end of the frame ?
                     ; thoughts for when more game logic is in the program
    ; 76543210
    ; ABsSUDLR - controller buttons

    @left:
        lda joy1buttons
        and #%00000010 ; left on dpad
        beq @up ; branch if AND leaves A with $00 in it
        lda player+Sprite_1x1::xpos
        cmp #$08 ; skip moving to left if it would move sprites behind mask
        beq @up
        sec
        sbc #$01
        sta player+Sprite_1x1::xpos
        
    @up:
        lda joy1buttons
        and #%00001000 ; up on dpad
        beq @right
        lda player+Sprite_1x1::ypos
        cmp #$0e
        beq @right
        sec
        sbc #$01
        sta player+Sprite_1x1::ypos
    
    @right:
        lda joy1buttons
        and #%00000001 ; right on dpad
        beq @down
        lda player+Sprite_1x1::xpos
        cmp #$f0
        beq @down
        clc
        adc #$01
        sta player+Sprite_1x1::xpos

    @down:
        lda joy1buttons
        and #%00000100 ; down on dpad
        beq @updatepos
        lda player +Sprite_1x1::ypos
        cmp #$d7
        beq @updatepos
        clc
        adc #$01
        sta player+Sprite_1x1::ypos

    @updatepos:
        lda player+Sprite_1x1::xpos
        sta player+Sprite_1x1::xpos + (2 * SPRSIZE) ; same xpos for corner in bottom left of 2x2 sprite
        clc ; might not be necessary?
        adc #(SPRWIDTHHEIGHT) ; top right and bottom right sprites are $08 pixels to the right
        sta player+Sprite_1x1::xpos + SPRSIZE
        sta player+Sprite_1x1::xpos + (3 * SPRSIZE)

        lda player+Sprite_1x1::ypos
        sta player+Sprite_1x1::ypos + SPRSIZE
        clc ; might not be necessary?
        adc #(SPRWIDTHHEIGHT)
        sta player+Sprite_1x1::ypos + (2 * SPRSIZE)
        sta player+Sprite_1x1::ypos + (3 * SPRSIZE)
        jsr nmiwaitsafe
        jmp main

    readjoy1:
        lda #$01
        sta JOYPAD1 ; write 1 then 0 to controller port to start serial transfer
        sta joy1buttons ; store 1 in buttons
        lsr a ; A: 1 -> 0
        sta JOYPAD1

    @ldbuttons:
        lda JOYPAD1
        lsr a ; bit 0 -> C
        rol joy1buttons ; C -> bit 0 in joy1buttons, shift all other to left
        bcc @ldbuttons ; if sentinel bit shifted out end loop
        rts

    bgpalettes:
    ; BG palettes, 4 total
        .byte $0f, $00, $00, $00 ; BG palette 1 ;; black, empty, empty, empty
        .byte $00, $00, $00, $00 ; BG palette 2 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 3 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 4 ;; empty

    sprpalettes:
        ; SPR palettes, 4 total
        .byte $19, $12, $20, $15 ; SPR palette 1 ;; green, blue, white, red
        .byte $00, $00, $00, $00 ; SPR palette 2 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 3 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 4 ;; empty

.segment "CHARS"
    ; sprite 0
;;;;;;;;;;;;;;;;;;;;;;;
    .byte %00000000
    .byte %00010000
    .byte %00110000
    .byte %00010000
    .byte %00010000
    .byte %00010000
    .byte %00111000
    .byte %00000000

    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %11111111
;;;;;;;;;;;;;;;;;;;;;;;

    ; sprite 1
;;;;;;;;;;;;;;;;;;;;;;;
    .byte %10000000
    .byte %10011000
    .byte %10100100 
    .byte %10000100
    .byte %10001000
    .byte %10010000
    .byte %10111100
    .byte %11111111

    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %11111111
;;;;;;;;;;;;;;;;;;;;;;;

    ; sprite 2
;;;;;;;;;;;;;;;;;;;;;;;
    .byte %11111111
    .byte %00000001
    .byte %00011001 
    .byte %00100101
    .byte %00001001
    .byte %00100101
    .byte %00011001
    .byte %00000001

    .byte %11111111
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
    .byte %00000001
;;;;;;;;;;;;;;;;;;;;;;;

    ; sprite 3
;;;;;;;;;;;;;;;;;;;;;;;
    .byte %00000000
    .byte %00000000
    .byte %00001100
    .byte %00010100
    .byte %00111110
    .byte %00000100
    .byte %00000100
    .byte %00000000

    .byte %11111111
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
    .byte %10000000
;;;;;;;;;;;;;;;;;;;;;;;