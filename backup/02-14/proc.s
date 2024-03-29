.proc nmiwaitunsafe
    bit PPUSTATUS
    bpl nmiwaitunsafe
    rts
.endproc

.proc nmiwaitsafe
    lda nmiflag
    beq nmiwaitsafe
    lda #$00
    sta nmiflag
    rts
.endproc

.proc readjoy1
    lda #$01
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