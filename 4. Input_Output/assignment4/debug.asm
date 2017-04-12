; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

.ORIG 0x100

jal	RA,func(Zero)
addi Zero,T1,1
addi Zero,T1,1
addi Zero,T1,1
br end
func:
sw RA, HEX(Zero)
sw Zero, HEX(Zero)

ret
end:
sw T1, HEX(Zero)
br end