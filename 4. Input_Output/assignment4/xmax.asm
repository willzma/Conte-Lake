; Addresses for I/O
.NAME	HEX  = 0xFFFFF000
.NAME	LEDR = 0xFFFFF020
.NAME	KDATA= 0xFFFFF080
.NAME	KCTRL= 0xFFFFF084
.NAME	SDATA= 0xFFFFF090
.NAME	SCTRL= 0xFFFFF094
.NAME	TCNT = 0xFFFFF100
.NAME	TLIM = 0xFFFFF104
.NAME	TCTL = 0xFFFFF108

.ORIG 0x100
; 0x3E0 - upper half, 0x1F - lower half

xor zero, zero, zero

; Speed control init
xor sp,sp,sp
addi sp,sp,2
xor fp,fp,fp
addi fp,fp,500

; Set initial state. S0 holds our state.
xor s0,s0,s0
addi s0,s0,1
addi zero,t0,0x3E0
sw t0,LEDR(zero)

xor a0,a0,a0 ; Holding bit: if on, use has not release key yet

TOP:
; Displays current speed
sw sp,HEX(zero)

; Set upper bound of timer to fp/4 second
sw fp,TLIM(zero)

; Speed control
lw t0,KDATA(zero)
andi t0,t0,3
xor t1,t1,t1
addi t1,t1,1


bne a0,zero,HOLDING ; skip key checks if button is held

bne t0,t1,INCREASE_DONE
xor a1,a1,a1
addi a1,a1,8
bge sp,a1,INCREASE_DONE
addi sp,sp,1
addi fp,fp,250
addi a0,a0,1
INCREASE_DONE:

addi t1,t1,1
bne t0,t1,DECREASE_DONE
xor a1,a1,a1
addi a1,a1,1
ble sp,a1,DECREASE_DONE
subi sp,sp,1
subi fp,fp,250
addi a0,a0,1
DECREASE_DONE:

HOLDING:

lw t0,KDATA(zero)
andi t0,t0,3
bne zero,t0,SKIP
xor a0,a0,a0
SKIP:

; Checks if the ready bit is set
lw t0,TCTL(zero)
beq zero,t0,TOP ; Jump to end if ready bit not set
sw zero,TCTL(zero) ; Clear the ready bit

; Switching logic
xor s1, s1, s1 ; state comparator
beq s0, s1, STATE0
addi s1, s1, 1
beq s0, s1, STATE1
addi s1, s1, 1
beq s0, s1, STATE2
addi s1, s1, 1
beq s0, s1, STATE3
addi s1, s1, 1
beq s0, s1, STATE4
addi s1, s1, 1
beq s0, s1, STATE5
addi s1, s1, 1
beq s0, s1, STATE6
addi s1, s1, 1
beq s0, s1, STATE7
addi s1, s1, 1
beq s0, s1, STATE8
addi s1, s1, 1
beq s0, s1, STATE9
addi s1, s1, 1
beq s0, s1, STATE10
addi s1, s1, 1
beq s0, s1, STATE11
addi s1, s1, 1
beq s0, s1, STATE12
addi s1, s1, 1
beq s0, s1, STATE13
addi s1, s1, 1
beq s0, s1, STATE14
addi s1, s1, 1
beq s0, s1, STATE15
addi s1, s1, 1
beq s0, s1, STATE16
addi s1, s1, 1
beq s0, s1, STATE17

; STATE 1 in XMAX
STATE0:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE1:
xor s2, s2, s2
sw s2,LEDR(zero)
br END
STATE2:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE3:
xor s2, s2, s2
sw s2,LEDR(zero)
br END
STATE4:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE5:
xor s2, s2, s2
sw s2,LEDR(zero)
br END

; STATE 2 in XMAX
STATE6:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)
br END
STATE7:
xor s2, s2, s2
sw s2,LEDR(zero)
br END
STATE8:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)
br END
STATE9:
xor s2, s2, s2
sw s2,LEDR(zero)
br END
STATE10:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)
br END
STATE11:
xor s2, s2, s2
sw s2,LEDR(zero)
br END

; STATE 3 in XMAX
STATE12:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE13:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)
br END
STATE14:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE15:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)
br END
STATE16:
xor s2, s2, s2
addi s2, s2, 0x3E0
sw s2,LEDR(zero)
br END
STATE17:
xor s2, s2, s2
addi s2, s2, 0x1F
sw s2,LEDR(zero)

xor s0,s0,s0 ; Roll back to state 0
addi s0,s0,-1 ; Set to negative state, because will be incremented in next step
END:
addi s0,s0,1 ; increment state
br TOP

