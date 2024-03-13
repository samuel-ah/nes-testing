.proc nmiwaitunsafe
    bit PPUSTATUS
    bpl nmiwaitunsafe
    rts
.endproc

.proc nmiwaitsafe
    lda nmiflag
    beq nmiwaitsafe
    lda #0
    sta nmiflag
    rts
.endproc

.proc readjoy1
    lda #1
    sta JOYPAD1 ; write 1 then 0 to controller port to start serial transfer
    sta joy1buttons ; store 1 in buttons
    lsr a ; A: 1 -> 0
    sta JOYPAD1

    :   lda JOYPAD1
        lsr a ; bit 0 -> C
        rol joy1buttons ; C -> bit 0 in joy1buttons, shift all other to left
        bcc :- ; if sentinel bit shifted out end loop
    
    rts
.endproc

.proc hit
    lda enemy+Sprite_1x1::xpos
    clc
    sbc #6 ; greater than pos - 6
    cmp shot+Sprite_1x1::xpos
    beq :+
        bcs miss
    :   
    clc
    adc #14 ; less than pos + 8
    cmp shot+Sprite_1x1::xpos
    bcc miss

    lda enemy+Sprite_1x1::ypos
    clc
    sbc #6 ; greater than pos - 6
    cmp shot+Sprite_1x1::ypos
    beq :+
        bcs miss
    :
    clc
    adc #14 ; less than pos + 8
    cmp shot+Sprite_1x1::ypos
    bcc miss

hide:
    lda #0
    sta enemy+Sprite_1x1::xpos
    sta dispshot
    sta shot+Sprite_1x1::xpos
    lda #8
    sta shot+Sprite_1x1::ypos

miss:   
    rts
.endproc

; .proc ppubuftrans
;     lda PPU_BUF

;     rts
; .endproc