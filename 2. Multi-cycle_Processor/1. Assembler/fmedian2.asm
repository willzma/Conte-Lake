; Addresses for I/O
.NAME	HEX= 0xFFFFF000
.NAME	LEDR=0xFFFFF020
.NAME	KEY= 0xFFFFF080
.NAME	SW=  0xFFFFF090

; The stack is at the top of memory
.NAME	StkTop=65536

;  Number of sorting iterations
.NAME	ItNum=4

; The array starts at data address 0x1000 and has 4096 elements (16kB)
.NAME	Array=0x1000
.NAME	ArrayBytes=0x4000

; LED Errors
.NAME ErrDes=0x01F 						; Lower Half on
.NAME ErrAsc=0x3E0						; Upper Half on
.NAME DoneSort=0x2AA 					; 1010101010
.NAME AllDone=0x2AA 					;

	.ORIG 0x100
	XOR		Zero,Zero,Zero						; Put a zero in the Zero register
	LW		SP,StackTopVal(Zero)			; Load the initial stack-top value into the SP
	SW      SP,HEX(Zero)

StackTopVal:
.WORD StkTop
