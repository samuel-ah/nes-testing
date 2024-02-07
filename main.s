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


.segment "HEADER"
    .byte "NES", $1a    ; iNES header format
    .byte $02           ; 2 segments 16kb PRG
    .byte $01           ; 1 segments 8kb CHR
    .byte $01, $00      ; mapper 0, set mirroring vertical

.segment "VECTORS"
    .addr NMI
    .addr RESET
    .addr IRQ

.segment "ZEROPAGE"

.segment "CODE"
    
    RESET:
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

    vbwait:
        bit PPUSTATUS
        bpl vbwait
        rts 
    
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
        jmp vbwait

    loadpalettes:
        lda PPU_STATUS ; read from $2002 to clear PPUADDR write flag

        lda #$3f
    
    bgpalettes:
    ; BG palettes, 4 total
        .byte $0f, $00, $00, $00 ; BG palette 1 ;; black, empty, empty, empty
        .byte $00, $00, $00, $00 ; BG palette 2 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 3 ;; empty
        .byte $00, $00, $00, $00 ; BG palette 4 ;; empty

    sprpalettes:
        ; SPR palettes, 4 total
        .byte $0f, $00, $00, $00 ; SPR palette 1 ;; black, blue, white, empty
        .byte $00, $00, $00, $00 ; SPR palette 2 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 3 ;; empty
        .byte $00, $00, $00, $00 ; SPR palette 4 ;; empty

.segment "CHARS"
    ; sprite 1
    .byte %11111111
    .byte %10000001
    .byte %10000001
    .byte %10000001
    .byte %10000001
    .byte %10000001
    .byte %10000001
    .byte %11111111