; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

.ORIG 0x100

xor s0, s0, s0
xor fp, fp, fp
xor sp, sp, sp
addi	s0,s0,1
sw		s0,LEDR(sp)
WaitPress1:
lw		t1,KEY(fp)
sw		t1,HEX(fp)
beq		t1,Zero,WaitPress1
WaitRelease1:
lw		t1,KEY(fp)
sw		t1,HEX(fp)
bne		t1,fp,WaitRelease1
LOP:
br LOP
