.segment "HEADER"
  .byte $4E, $45, $53, $1A ; .byte "NES", $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  .addr reset
  ;; External interrupt IRQ (unused)
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
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs
  inx		; now X = 0
  stx PPU_CTRL	; disable NMI
  stx PPU_MASK 	; disable rendering
  stx DMC_FREQ 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit PPU_STATUS
  bpl vblankwait1

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

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit PPU_STATUS
  bpl vblankwait2

main:
load_palettes:
  lda PPU_STATUS
  lda #$3f
  sta PPU_ADDRESS
  lda #$00
  sta PPU_ADDRESS
  ldx #$00
@loop:
  lda palettes, x
  sta PPU_DATA
  inx
  cpx #$20
  bne @loop

enable_rendering:
  lda #%10000000	; Enable NMI
  sta PPU_CTRL
  lda #%00010000	; Enable Sprites
  sta PPU_MASK

set_ball_pos:
  lda #$08
  sta ball_x
  lda #$10
  sta ball_y

forever:
  jmp forever

nmi:
  pha 
  tya
  pha
  txa
  pha ;store registers
@move_ball:
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
  and #$01
  beq @read_down
  lda ball_y
  sec
  sbc #$01
  sta ball_y ;raise ball by 1 pixel
@read_down:
  lda JOYPAD1 ;load DOWN bit from controller port
  and #$01
  beq @read_left
  lda ball_y
  clc
  adc #$01
  sta ball_y ;lower ball by 1 pixel
@read_left:
  lda JOYPAD1 ;load LEFT bit from controller port
  and #$01
  beq @read_right
  lda ball_x
  sec
  sbc #$01
  sta ball_x ;move ball to left 1 pixel
@read_right:
  lda JOYPAD1 ;load RIGHT bit from controller port
  and #$01
  beq @end_move
  lda ball_x
  clc
  adc #$01
  sta ball_x ;move ball to right 1 pixel
@end_move:
  ldx #$00 	; Set SPR-RAM address to 0
  stx PPU_OAM_ADDR
@loop:
  lda hello, x 	; Load the hello message into SPR-RAM
  sta PPU_OAM_DATA
  inx
  cpx #$18
  beq @set_ball_y
  cpx #$1b
  beq @set_ball_x
  cpx #$1c
  bne @loop
  jmp @end_nmi
@set_ball_y:
  lda ball_y
  sta PPU_OAM_DATA
  inx
  jmp @loop
@set_ball_x:
  lda ball_x
  sta PPU_OAM_DATA
  inx
  jmp @loop
@end_nmi:
  pla
  tax
  pla
  tay
  pla
  rti

hello:
  .byte $00, $00, $00, $00 ;$03
  .byte $00, $00, $00, $00 ;$07
  .byte $00, $00, $00, $00 ;$0b
  .byte $00, $00, $00, $00 ;$0f
  .byte $00, $00, $00, $00 ;$13
  .byte $00, $00, $00, $00 ;$17
  .byte $6c, $00, $00, $08 ;$1b

palettes:
  ; Background Palette
  .byte $0f, $00, $00, $00 ;$03
  .byte $0f, $00, $00, $00 ;$07
  .byte $0f, $00, $00, $00 ;$0b
  .byte $0f, $00, $00, $00 ;$0f

  ; Sprite Palette
  .byte $0f, $12, $20, $00 ;$03
  .byte $00, $00, $00, $00 ;$07
  .byte $00, $00, $00, $00 ;$0b
  .byte $00, $00, $00, $00 ;$0f

; Character memory
.segment "CHARS"
  .byte %00011000	; H (00)
  .byte %00111100
  .byte %01111110
  .byte %11111111
  .byte %11111111
  .byte %01111110
  .byte %00111100
  .byte %00011000
  .byte $00, $00, $00, $00, $00, $00, $00, $00