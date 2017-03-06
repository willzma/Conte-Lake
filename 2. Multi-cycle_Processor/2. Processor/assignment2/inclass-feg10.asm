.NAME    HEX= 0xFFFFF000
.NAME    LEDR=0xFFFFF020
.NAME    KEY= 0xFFFFF080
.NAME    SW=  0xFFFFF090

.ORIG 0x100
; Put a zero in the Zero register
    XOR        Zero,Zero,Zero
    xor        a2,a2,a3   ;a2 = a2 ^ a3  == 0
    sub        a0,a0,a2   ;a0 = a0 - a2  == 0
    add        a0,a1,a0   ;a0 = a1 + a0 == 0
    addi       t1,fp,-8   ; t1 = fp - 8 = -8
    bne        a0,t1,AluWorks
AluFailed:
    sw         a0,HEX(Zero)
    br         AluFailed
AluWorks:
    addi       s0,s0,1
    sw         s0,LEDR(Zero)
    addi       a1,fp,1
Forever:
    br         Forever

