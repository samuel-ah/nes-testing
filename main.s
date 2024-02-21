; TODO:
; sprite art ?
; figure out background displaying
; CPU enemies ?
; collision ?
; read ca65 user guide
; more comments
; change nes.cfg to have $00FD as zp size

.include "define.s"
.include "header.s"
.include "structs.s"
.include "proc.s"
.include "chars.s"

.segment "ZEROPAGE"
    player: .tag Sprite_4x4
    shot: .tag Sprite_1x1
    enemy: .tag Sprite_1x1
    joy1buttons: .res 1
    nmiflag: .res 1
    dispshot: .res 1

.segment "CODE"
nmi:
@svregs:
    pha
    tya
    pha
    txa
    pha

    lda #1
    sta nmiflag

@initoam:
    ldx #0    ; OAMADDR 0
    stx OAMADDR

    :   lda player, x
        sta OAMDATA
        inx
        cpx #(.sizeof(player)) ; size of 4 sprite (4 x #$04 bytes)
        bne :-

    ldx #0

    :   lda shot, x
        sta OAMDATA
        inx
        cpx #(.sizeof(shot))
        bne :-

    ldx #0
    
    :   lda enemy, x
        sta OAMDATA
        inx
        cpx #(.sizeof(enemy))
        bne :-

@ldregs:
    pla
    tax
    pla
    tay
    pla
    rti

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
    
    :   lda #0
        sta $0000, x
        sta $0100, x
        sta $0200, x
        sta $0300, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        inx
        bne :-

    jsr nmiwaitunsafe

@ldpalettes:
    lda PPUSTATUS ; read from $2002 to clear PPUADDR write flag

    lda #$3f     ;set PPUADDR to $3f00
    sta PPUADDR
    lda #$00
    sta PPUADDR

    ldx #00

    :   lda palettes, x
        sta PPUDATA
        inx
        cpx #(.sizeof(Palette) * 8) ; size of 8 palettes (4 * #$04 bytes)
        bne :-

@enablerender:
    lda #%10000000 ; nmi enable
    sta PPUCTRL

    lda #%00010000 ; sprite enable
    sta PPUMASK

@initpos:
    lda #128 ; starting x
    sta player+Sprite_4x4::xpos0
    lda #200 ; starting y
    sta player+Sprite_4x4::ypos0
    ldx #1
    stx player+Sprite_4x4::ptrnindex1 ; starting pos is same for all 4 player sprites, gets
                                      ; fixed at first NMI before first frame is even drawn
    inx
    stx player+Sprite_4x4::ptrnindex2
    inx
    stx player+Sprite_4x4::ptrnindex3

    inx ; X -> 4 (shot sprite)

    lda #0
    sta shot+Sprite_1x1::xpos
    sta shot+Sprite_1x1::ypos
    stx shot+Sprite_1x1::ptrnindex

    inx ; X -> 5 (enemy sprite)

    lda #100
    sta enemy+Sprite_1x1::xpos
    sta enemy+Sprite_1x1::ypos
    stx enemy+Sprite_1x1::ptrnindex

@main:
    nop ; identify start of execution
    jsr readjoy1 ; would this lead to less noticeable input lag to do later in the frame ?
                    ; thoughts for when more game logic is in the program

@shoot:
    lda joy1buttons
    and #PAD_A
    beq :++
        lda dispshot
        bne :+ ; skip moving shot to player when shot is already on screen
            lda #1
            sta dispshot

            lda player+Sprite_4x4::xpos0
            clc
            adc #4
            sta shot+Sprite_1x1::xpos

            lda player+Sprite_4x4::ypos0
            clc
            sbc #4
            sta shot+Sprite_1x1::ypos
        :
    :

@setmove:
    lda joy1buttons
    and #PAD_LEFT
    beq :++ ; branch if no button held
        ldx player+Sprite_4x4::xpos0
        cpx #8 ; skip moving to left if it would move sprites behind mask
        beq :+
            dex
            stx player+Sprite_4x4::xpos0
        :
    :

    lda joy1buttons
    and #PAD_UP ; up
    beq :++
        ldx player+Sprite_4x4::ypos0
        cpx #14
        beq :+
            dex
            stx player+Sprite_4x4::ypos0
        :
    :

    lda joy1buttons
    and #PAD_RIGHT ; right
    beq :++
        ldx player+Sprite_4x4::xpos0
        cpx #232
        beq :+
            inx
            stx player+Sprite_4x4::xpos0
        :
    :

    lda joy1buttons
    and #PAD_DOWN ; down
    beq :++
        ldx player+Sprite_4x4::ypos0
        cpx #207
        beq :+
            inx
            stx player+Sprite_4x4::ypos0
        :
    :

@updatepos:
    lda player+Sprite_4x4::xpos0
    sta player+Sprite_4x4::xpos2 ; same xpos for corner in bottom left of 2x2 sprite
    clc
    adc #SPRWIDTHHEIGHT ; top right and bottom right sprites are $08 pixels to the right
    sta player+Sprite_4x4::xpos1
    sta player+Sprite_4x4::xpos3

    lda player+Sprite_4x4::ypos0
    sta player+Sprite_4x4::ypos1
    clc 
    adc #SPRWIDTHHEIGHT
    sta player+Sprite_4x4::ypos2
    sta player+Sprite_4x4::ypos3

    ldx enemy+Sprite_1x1::xpos
    inx
    stx enemy+Sprite_1x1::xpos

    lda dispshot
    beq :++
        ldx shot+Sprite_1x1::ypos
        dex
        dex
        cpx #248
        bcc :+ ; if pos >255-SPRWIDTHHEIGHT
            lda #0
            sta dispshot
            sta shot+Sprite_1x1::xpos
        :
        stx shot+Sprite_1x1::ypos
        jsr hit
        jmp @endframe
    :

@endframe:
    jsr nmiwaitsafe
    jmp @main

palettes:
; BG palettes, 4 total
    .byte $0f, $00, $00, $00 ; BG palette 1 ;; black, empty, empty, empty
    .byte $00, $00, $00, $00 ; BG palette 2 ;; empty
    .byte $00, $00, $00, $00 ; BG palette 3 ;; empty
    .byte $00, $00, $00, $00 ; BG palette 4 ;; empty
    
; SPR palettes, 4 total
    .byte $0f, $12, $20, $15 ; SPR palette 1 ;; black, blue, white, red
    .byte $00, $00, $00, $00 ; SPR palette 2 ;; empty
    .byte $00, $00, $00, $00 ; SPR palette 3 ;; empty
    .byte $00, $00, $00, $00 ; SPR palette 4 ;; empty