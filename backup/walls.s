.segment "HEADER"
  .byte $4E, $45, $53, $1A ; .byte "NES", $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0

.segment "VECTORS"
  ; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ; Reset
  .addr reset
  ; Software interrupt IRQ (unused)
  .addr 0

.segment "STARTUP"

.segment "ZEROPAGE"
  ball_x: .res 1
  ball_y: .res 1
  buttons: .res 1
  nmi_flag: .res 1

.segment "CODE"
PPU_CTRL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002
PPU_OAM_ADDR = $2003
PPU_OAM_DATA = $2004
PPU_ADDRESS = $2006
PPU_DATA = $2007

DMC_FREQ = $4010

JOYPAD1 = $4016
JOYPAD2 = $4017

reset:
  sei		
  cld		; disable decimal mode
  ldx #$40
  stx $4017
  ldx #$ff 	; Set up stack
  txs
  inx		; now X = 0
  stx PPU_CTRL	; disable NMI
  stx PPU_MASK 	; disable rendering
  stx DMC_FREQ 	; disable IRQs

;; first wait for NMI
nmiwait1:
  bit PPU_STATUS
  bpl nmiwait1

clear_memory:
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
  bne clear_memory

;; second wait for NMI, PPU is ready after this
nmiwait2:
  bit PPU_STATUS
  bpl nmiwait2

main:
load_palettes:
  lda PPU_STATUS
  lda #$3f
  sta PPU_ADDRESS
  lda #$00
  sta PPU_ADDRESS
  ldx #$00
@loop:
  lda palettes, x ; load a byte of palette data
  sta PPU_DATA ;send the byte to the PPU
  inx ; move to the next byte
  cpx #$20 ; check if all the information has sent
  bne @loop ;if not load the next byte

enable_rendering:
  lda #%10000000	; Enable NMI
  sta PPU_CTRL
  lda #%00010000	; Enable Sprites
  sta PPU_MASK

set_ball_pos:
  lda #$08
  sta ball_x
  lda #$0e
  sta ball_y

start:
@clear_nmi: ;$00: no NMI; $01: just returned from NMI
  lda #$00 
  sta nmi_flag ; Clear the NMI flag

@read_direction:
  lda #$01
  sta JOYPAD1
  lda #$00
  sta JOYPAD1 ;instruct controller to start serial transfer

  lda JOYPAD1
  lda JOYPAD1
  lda JOYPAD1
  lda JOYPAD1 ;pass first 4 bits to only use directional input

  clc

@read_up:
  lda JOYPAD1 ;load UP bit from controller port
  and #$01 ; see if the UP direction is being held
  beq @read_down ; if not skip moving up
  lda ball_y ;load the Y position
  sec
  sbc #$01 ;subtract 1
  cmp #$0d ; check if top boundary reached
  bne @allowUpMovement ; if not allow the value
  lda #$0e ; reset the position to 1 below the top edge
@allowUpMovement:
  sta ball_y ; set the resulting value

@read_down:
  lda JOYPAD1 ;load DOWN bit from controller port
  and #$01
  beq @read_left
  lda ball_y
  clc
  adc #$01
  cmp #$d8
  bne @allowDownMovement
  lda #$d7
@allowDownMovement:
  sta ball_y ;lower ball by 1 pixel

@read_left:
  lda JOYPAD1 ;load LEFT bit from controller port
  and #$01
  beq @read_right
  lda ball_x
  sec
  sbc #$01
  cmp #$07
  bne @allowLeftMovement
  lda #$08
@allowLeftMovement:
  sta ball_x ;move ball to left 1 pixel

@read_right:
  lda JOYPAD1 ;load RIGHT bit from controller port
  and #$01
  beq spin
  lda ball_x
  clc
  adc #$01
  cmp #$f1
  bne @allowRightMovement
  lda #$f0
@allowRightMovement:
  sta ball_x ;move ball to right 1 pixel

spin:
  lda nmi_flag 
  cmp #$01
  beq start
  jmp spin


nmi:
@nmi_setup:
  pha ; store registers in stack
  tya
  pha
  txa
  pha
  lda #$01 ;set NMI flag
  sta nmi_flag

@sprite_transfer:
  ldx #$00 	; Set sprite RAM address to 0
  stx PPU_OAM_ADDR

@loop:
  lda sprites, x 	; Load 1 byte of object data from the ball
  sta PPU_OAM_DATA ;;Send the byte to the PPU
  inx ; Move to the next byte
  cpx #$18 ; See if we need to set the Y position (done once per row of pixels)
  beq @set_ball_y
  cpx #$1b ; See if we need to set the X position (done once per column of pixels)
  beq @set_ball_x
  cpx #$1c ; See if we sent the correct amount of bytes to the PPU 
           ; meaning we finished sending the information
  bne @loop ; if not send the next byte
  jmp @end_nmi ; if true end the NMI

@set_ball_y:
  lda ball_y ; Load the Y position
  sta PPU_OAM_DATA ; Send the Y position to the PPU
  inx ; Move to the next byte
  jmp @loop ; Return to send the next byte of object data

@set_ball_x:
  lda ball_x ; Load the X position
  sta PPU_OAM_DATA ; Send the X position to the PPU
  inx ; Move to the next byte
  jmp @loop ; Return to send the next byte of object data

@end_nmi:
  pla
  tax
  pla
  tay
  pla
  rti

sprites:
  ; Sprite table (ball is index $6c and $08 is the end of the table)
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00 
  .byte $6c, $00, $00, $08

palettes:
  ; Background Palette: (all blank)
  .byte $00, $00, $00, $00
  .byte $00, $00, $00, $00
  .byte $00, $00, $00, $00
  .byte $00, $00, $00, $00

  ; Sprite Palette
  .byte $0f, $00, $00, $00 ; blue ($0f), blank ($00), blank ($00), blank ($00)
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00 
  .byte $00, $00, $00, $00 

.segment "CHARS"
  ;Ball sprite
  .byte %00011000	; blank (00) blank (01) blank (10) blue (11)
  .byte %00111100
  .byte %01111110
  .byte %11111111
  .byte %11111111
  .byte %01111110
  .byte %00111100
  .byte %00011000
  .byte $00, $00, $00, $00, $00, $00, $00, $00