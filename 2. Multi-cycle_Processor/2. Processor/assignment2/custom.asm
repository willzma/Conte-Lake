; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

	.ORIG 0x100
	
gaylord:
	addi	s1,s1,1
	sw		s1,HEX(Zero)
	br      gaylord