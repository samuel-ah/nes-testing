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

SPRWIDTHHEIGHT = 8