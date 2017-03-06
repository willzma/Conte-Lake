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

; -----------------------------------------------------------------
; Processor Initialization
	.ORIG 0x100
	XOR		Zero,Zero,Zero						; Put a zero in the Zero register
	LW		SP,StackTopVal(Zero)			; Load the initial stack-top value into the SP
	SW		Zero,LEDR(Zero)						; Turn off LEDR

; Initialize the array with numbers 13, 13+11, 13+2*11, etc.
	ADDI 	Zero,T0,Array							; T0 is CurPtr, set to start of array
	LW		T1,ArrayBytesVal(Zero)
	ADD		T1,T1,T0									; T1 is EndPtr, set to end of array
	ADDI	Zero,S1,13								; S1 is the current value of the array element for initialization
	XOR		A1,S1,A0
Init:
	SW		S1,0(T0)									; Store value into an element
	ADDI	S1,S1,11									; Add 11 to the value for next element
	ADDI	T0,T0,4										; Move to next element
	BNE		T0,T1,Init								; if(CurPtr!=EndPtr) goto Init;

; Initialization done. Now check if the array is sorted in ascending order (it should be)
	CALL	ChkAsc(Zero)


; -----------------------------------------------------------------
; This is the main loop of the program, which repeats the same work ItNum times
; The work is to sort the array in descending and then in ascending order
; Then get the median value and show it on HEX
; The iteration count is displayed on HEX
	ADDI	Zero,S1,ItNum						; We will keep the iteration count in S1
	SW		S1,HEX(Zero)						; Display loop counter
MainLoop:
	; The work is to sort the array in descending and then in ascending order
	ADDI	Zero,A0,Array
	LW		A1,ArrayBytesVal(Zero)
	ADD		A1,A1,A0
	CALL	SortDesc(Zero)				; SortDesc(Array,ArrayBytes)
	CALL	ChkDesc(Zero)					; ChkDesc()
	ADDI	Zero,A0,Array
	LW		A1,ArrayBytesVal(Zero)
	ADD		A1,A1,A0
	CALL	SortAsc(Zero)					; SortAsc(Array,ArrayBytes)
	CALL 	ChkAsc(Zero)					; ChkAsc()
	ADDI	S1,S1,-1							; Decrement iteration count
	SW		S1,HEX(Zero)					; Display the new value on HEX
	SW		S1,LEDR(Zero)					; Turn on LEDR
	BNE		S1,Zero,MainLoop			; Back to main loop

	; Sorting Done part
	ADDI  Zero,S1,99
	SW		S1,HEX(Zero)					; Show 99 on Hex
	ADDI	Zero,T0,DoneSort			; 1010101010 in T0
	SW		T0,LEDR(Zero)					; Turn on LEDR
	ADDI  Zero,S0,4000000
DoneSorting:
	ADDI	S0,S0,-1
	BEQ   S0,Zero,ShowMedian
	JMP DoneSorting(Zero)



; -----------------------------------------------------------------
; Shows Median on HEX
ShowMedian:
	ADDI	Zero,A0,Array
	LW		A1,ArrayBytesVal(Zero)			; A1 size of the array
	ADDI	Zero,T0,3
	RSHF	A1,A1,T0										; A1 now is divided by eight (*4 each element size, *2 to find element)
	ADD   A1,A1,	A0
	LW		T0,0(A1)
	SW		T0,HEX(Zero)
	ADDI	Zero,T1,AllDone
	SW		T1,LEDR(Zero)
Forever:
	JMP Forever(Zero)


; -----------------------------------------------------------------
; Verifies that the array is sorted in ascending order
; ChkAsc()
ChkAsc:
	ADDI	Zero,A0,Array
	LW		A1,ArrayBytesVal(Zero)
	ADD		A1,A1,A0
	ADDI	Zero,A2,13
LoopChkAsc:
	LW		T0,0(A0)
	BEQ		T0,A2,GoodChkAsc
ErrChkAsc:
	SW		T0,HEX(Zero)				; Put value we read on HEX
	ADDI	Zero,T1,ErrAsc
	SW		T1,LEDR(Zero)				; Turn on upper half of LEDR
	JMP		ErrChkAsc(Zero)			; Loop forever
GoodChkAsc:
	ADDI	A2,A2,11
	ADDI	A0,A0,4
	BNE		A0,A1,LoopChkAsc
	RET

; -----------------------------------------------------------------
; Verifies that the array is sorted in descending order
; ChkDesc()
ChkDesc:
	ADDI	Zero,A1,Array
	LW		A0,ArrayBytesVal(Zero)
	ADD		A0,A0,A1
	ADDI	Zero,A2,13
LoopChkDesc:
	SUBI	A0,A0,4
	LW		T1,0(A0)
	BEQ		A2,T1,GoodChkDesc
ErrChkDesc:
	SW		T1,HEX(Zero)			; Put value we read on HEX
	ADDI	Zero,T0,ErrDes
	SW		T0,LEDR(Zero)			; Turn on lower half of LEDR
	JMP		ErrChkDesc(Zero)	; Loop forever
GoodChkDesc:
	ADDI	A2,A2,11
	BNE		A1,A0,LoopChkDesc
	RET

; -----------------------------------------------------------------
SortAsc:; SortAsc(beg,end)
	; Sorts an array that starts at beg and ends at end
	; Sorts in ascending order (low to high values)
	; The sorting strategy is selection sort
	; Outer loop (ptr "i" in A0) goes from start to end
SortAscLoopI:
	BEQ   A0,A1,SortAscEndI
	LW		T0,0(A0)								; T0 will be equal to what should be in *i
  ADDI  A0,A2,4									; Inner loop (ptr "j" in A2) goes from i+4 to end
SortAscLoopJ:
  BEQ   A2,A1,SortAscEndJ
	LW		T1,0(A2)	; T1=*j
	BLE		T0,T1,SortAscNoSwap
	SW		T0,0(A2)								; *j=T0 (*j becomes what was in *i)
	ADD		T0,T1,S0								; T0=T1 (*i becomes what was in *j)
SortAscNoSwap:
	ADDI	A2,A2,4
	JMP		SortAscLoopJ(Zero)
SortAscEndJ:
	SW		T0,0(A0)	; Save T0 back into *i
	ADDI	A0,A0,4
	JMP		SortAscLoopI(Zero)
SortAscEndI:
	RET

; -----------------------------------------------------------------
SortDesc:; SortDesc(beg,end)
	; Sorts an array that starts at beg and ends at end
	; Sorts in descending order (high to low values)
	; The sorting strategy is immediate-swap selection sort
	; Outer loop (ptr "i" in T0) goes from start to end
	ADDI	A0,T0,0
SortDescLoopI:
	BEQ     T0,A1,SortDescEndI
  ADDI    T0,T1,4							; Inner loop (ptr "j" in T1) goes from i+4 to end
SortDescLoopJ:
  BEQ   T1,A1,SortDescEndJ
	LW		A2,0(T0)							; A2=*i
	LW		A3,0(T1)							; A3=*j
	BGE		A2,A3,SortDescNoSwap
	SW		A2,0(T1)							; *j=A2
	SW		A3,0(T0)							; *i=A3
SortDescNoSwap:
	ADDI	T1,T1,4
	JMP		SortDescLoopJ(Zero)
SortDescEndJ:
	ADDI	T0,T0,4
	JMP		SortDescLoopI(Zero)
SortDescEndI:
	RET

; -----------------------------------------------------------------
StackTopVal:
.WORD StkTop
ArrayBytesVal:
.WORD ArrayBytes
