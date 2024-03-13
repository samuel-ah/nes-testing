PPUCTRL = $2000 ; PPU control flags
                ; VPHB SINN
                ; NMI enable (V) PPU master/slave (P) sprite height (H) background tile select (B)
                ; sprite pattern table address select (0: $0000, 1: $1000) (S) increment mode (I) nametable select (NN)
PPUMASK = $2001 ; mask control, color settings **use greyscale mask for interesting effect ?
PPUSTATUS = $2002 ; PPU status flags
                  ; VSO- ---- 
                  ; vblank flag (V) sprite 0hit (S) sprite overflow (O) unused (-)
                  ; NOTE: read from this address to reset write flag for PPUADDR
                  ; to allow PPU VRAM address to be changed
OAMADDR = $2003 ; points to address of OAM being used, usually ignored and set to $00 as DMA is better
OAMDATA = $2004 ; OAM data read/write
PPUADDR = $2006 ; PPU accessing address read/write (2 byte address, HI byte first. Read from $2002 before this.)
PPUDATA = $2007 ; PPU data write
DMC_FREQ = $4010
JOYPAD1 = $4016
JOYPAD2 = $4017
ZP_START = $0000
OAM_BUF = $0200
PAD_A = $80
PAD_B = $40
PAD_SELECT = $20
PAD_START = $10
PAD_UP = $08
PAD_DOWN = $04
PAD_LEFT = $02
PAD_RIGHT = $01
SPRWIDTHHEIGHT = 8