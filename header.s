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

.segment "STARTUP" ; unused rn but compiler yells at me :(