	; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address to get actual register address
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset	equ	2
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10
VectAddr	equ	0x30
VectAddr0	equ	0x100
VectCtrl0	equ	0x200

Timer0ChannelNumber	equ	4	; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5		; UM, Table 58
	
IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
		
IO0DIR	EQU	0xE0028008
IO0SET	EQU	0XE0028004
IO0CLR	EQU	0XE002800C
IO0PIN 	EQU 0XE0028000

	AREA	InitialisationAndMain, CODE, READONLY
	IMPORT	main

; (c) Mike Brady, 2014 -- 2019.

	EXPORT	start
start
; initialisation code

; Initialise the VIC
	ldr	r0,=VIC			; looking at you, VIC!

	ldr	r1,=irqhan
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (may not be needed)

; Initialise Timer 0
	ldr	r0,=T0			; looking at you, Timer 0!

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]

	ldr	r1,=(14745600/200)-1	 ; 5 ms = 1/200 second
	str	r1,[r0,#MR0]

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]
	
;stack stuff 

initLoop B initLoop

	;thread 0
	AREA	blinky0, CODE, READONLY
	
startBlinky0
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	
	
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
; r1 points to the SET register
; r2 points to the CLEAR register
floop
	ldr	r0,=0x00010000	;select P1.19--P1.16
	str r0, [r2]
;delay for about a half second
	ldr	r4,=4000000
dloop	subs	r4,r4,#1
	bne	dloop
	
	str r0, [r1]
	;delay for about a half second
	ldr	r4,=4000000
dloop2	subs	r4,r4,#1
	bne	dloop2
	
	b floop

;end blinky1


;thread 1
	AREA	blinky1, CODE, READONLY
	
startBlinky1	

	ldr	r1,=IO0DIR
	ldr	r2,=0X00260000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	
	
	ldr	r1,=IO0SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO0CLR
	
	
; r1 points to the SET register
; r2 points to the CLEAR register
floopb2
	ldr	r0,=0X00200000	;select P1.19--P1.16
	str r0, [r2]
;delay for about a half second
	ldr	r4,=4000000
dloopb2	subs	r4,r4,#1
	bne	dloopb2
	
	str r0, [r1]
	;delay for about a half second
	ldr	r4,=4000000
dloopb22	subs	r4,r4,#1
	bne	dloopb22
	
	b floopb2

;end blinky 2

;interrupt stuff
	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	stmfd	sp!,{r0-r1,lr}	; the lr will be restored to the pc

;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts
;switching threads
	ldr r0, =CURRENTTHREAD
	ldr r1, [r0]
	cmp r1, #-1
	beq initialSwitch
	cmp r1, #0
	beq switchTo1
	cmp r1, #1
	beq switchTo0
	
initialSwitch
	ldr r1, =0
	str r1, [r0]
	;update cpsr
	LDR R2, =INITIALISATIONCOUNT
	LDR R3, [R2]
	ADD R3, R3, #1
	STR R3, [R2]
	mrs r0, cpsr
	ldr r1, =0xFFFFFFE0
	and r0, r0, r1
	ldr r1, =0x00000010
	orr r0, r0, r1
	msr cpsr_f, r0
	B startBlinky0
	
	
switchTo1
	ldr r2, =THREAD0REG
	stmfa r2, {r0-r15}
	LDR R2, =INITIALISATIONCOUNT
	LDR R3, [R2]
	CMP R3, #2
	BGE restoreContext
	ADD R3, R3, #1
	STR R3, [R2]
	B startBlinky1
	
restoreContext
	ldr r2, =THREAD1REG
	ldmfa r2, {r0-r15}
	sub r2, r2, #4
	mrs r0, cpsr
	mov r2, r0
	
	
switchTo0
	ldr r2, =THREAD1REG
	stmfa r2, {r0-r15}
	LDR R2, =INITIALISATIONCOUNT
	LDR R3, [R2]
	CMP R3, #2
	BGE restoreContext1
	ADD R3, R3, #1
	STR R3, [R2]
	B startBlinky0
	
restoreContext1
	ldr r2, =THREAD0REG
	sub r2, r2, #4*13
	ldr r2, [r2]
	msr cpsr_f, r2
	ldr r2, =THREAD0REG
	ldmfa r2, {r0-r15}
	

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC

	ldmfd	sp!,{r0-r1,pc}^	; return from interrupt, restoring pc from lr
				; and also restoring the CPSR
				
	AREA processStorage, READWRITE
THREAD0STACK SPACE 200 
THREAD0REG SPACE 16
	
THREAD1STACK SPACE 200
THREAD1REG SPACE 16
	
CURRENTTHREAD DCD -1
	
INITIALISATIONCOUNT DCD 0 
	END