.struct Palette
    col0 .byte
    col1 .byte
    col2 .byte
    col3 .byte
.endstruct

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