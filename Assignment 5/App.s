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
	
;Initialise thread contexts 
	ldr r1, =CURRENTTHREAD
	ldr r2, =0
	str r2, [r1] ;set thread 0 as active
	
	;initialise thread 0 stack
	ldr r0, =THREAD0STACK
	ldr r1, =THREAD0SP
	str r0, [r1]
	
	ldr r0, =THREAD1STACK
	ldr r1, =THREAD1SP
	str r0, [r1]

	ldr r1, =0
	str r1, [r0]
	LDR R2, =INITIALISATIONCOUNT
	LDR R3, [R2]
	ADD R3, R3, #1
	STR R3, [R2]
	mrs r0, cpsr
	;ldr r1, =0xFFFFFFE0
	;and r0, r0, r1
	;ldr r1, =0x00000010
	;orr r0, r0, r1
	
	ldr r4, =THREAD0CPSR
	str r0, [r4]
	ldr r4, =THREAD1CPSR
	str r0, [r4]
	
	ldr r3, =startBlinky1
	mov lr, r3
	ldr r4, =THREAD1PC
	str r3, [r4]
	
	ldr r4, =THREAD1SP
	mov sp, r4
	stmfd	sp!,{r0-r12,lr}
	str sp, [r4]
	
	ldr r3, =startBlinky0
	mov lr, r3
	
	ldr r4, =THREAD0SP
	mov sp, r4
	stmfd	sp!,{r0-r12,lr}
	str sp, [r4]
	
	B restoreContext
	b irqhan
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
	;ldr	r4,=4000000
	ldr	r4,=1
dloop	subs	r4,r4,#1
	bne	dloop
	
	str r0, [r1]
	;delay for about a half second
	ldr	r4,=1
dloop2	subs	r4,r4,#1
	bne	dloop2
	b irqhan
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
	ldr	r4,=1
dloopb2	subs	r4,r4,#1
	bne	dloopb2
	
	str r0, [r1]
	;delay for about a half second
	ldr	r4,=1
dloopb22	subs	r4,r4,#1
	bne	dloopb22
	b irqhan
	b floopb2

;end blinky 2

;interrupt stuff
	AREA	InterruptStuff, CODE, READONLY
irqhan
	sub	lr,lr,#4
	stmfd	sp!,{r0-r12,lr}	; the lr will be restored to the pc
	
;this is the body of the interrupt handler
;switching threads
	ldr r0, =CURRENTTHREAD
	ldr r1, [r0]
	cmp r1, #0
	beq switchTo1
	cmp r1, #1
	beq switchTo0

switchTo0
	;set this thread as the new active thread
	ldr r1, =CURRENTTHREAD
	ldr r2, =0
	str r2, [r1] ;set thread 0 as active
	
	;spsr -> thread 1 cpsr
	ldr r3, =THREAD1CPSR
	mrs r4, spsr
	str r4, [r3]
	
	;save thread 1 stuff to its stack and memory
	ldr r5, =THREAD1PC
	str lr, [r5]
	ldmfd	sp!,{r0-r12,lr}
	ldr r5, =THREAD1SP
	ldr sp, [sp]
	stmfd	sp!,{r0-r12,lr}
	str sp, [r5]
	
	
	;restore thread 0 pc
	ldr lr, =THREAD0PC
	ldr lr, [lr]
	
	;restore thread 0 sp
	ldr sp, =THREAD0SP
	ldr sp, [sp]
	
	;restore cpsr to spsr
	ldr r0, =THREAD0CPSR
	ldr r0, [r0]
	msr spsr_cxsf, r0
	
	b restoreContext
	
switchTo1
	;set this thread as the new active thread
	ldr r1, =CURRENTTHREAD
	ldr r2, =1
	str r2, [r1] ;set thread 1 as active
	
	;spsr -> thread 0 cpsr
	ldr r3, =THREAD0CPSR
	mrs r4, spsr
	str r4, [r3]
	
	;save thread 0 stuff to its stack and memory
	ldr r5, =THREAD0PC
	str lr, [r5]
	ldmfd	sp!,{r0-r12,lr}
	ldr r5, =THREAD0SP
	ldr sp, [r5]
	stmfd	sp!,{r0-r12,lr}
	str sp, [r5]
	
	
	
	;restore thread 1 pc
	ldr lr, =THREAD1PC
	ldr lr, [lr]
	
	;restore thread 1 sp
	ldr sp, =THREAD1SP
	ldr sp, [sp]
	
	;restore cpsr to spsr
	ldr r0, =THREAD1CPSR
	ldr r0, [r0]
	msr spsr_cxsf, r0

	b restoreContext

restoreContext

;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC


;restore context
;at this point the lr, sp and cpsr are ready for the thread we are switching to
	mrs r0, spsr
	msr cpsr_cxsf, r0
	;restore thread registers
	ldmfd	sp!,{r0-r12,lr}
	bx lr
	
	
	AREA processStorage, READWRITE
THREAD0STACK SPACE 400 
THREAD0PC SPACE 4
THREAD0SP SPACE 4
THREAD0CPSR SPACE 4
	
THREAD1STACK SPACE 400
THREAD1PC SPACE 4
THREAD1SP SPACE 4
THREAD1CPSR SPACE 4
	
CURRENTTHREAD DCD 0
	
INITIALISATIONCOUNT DCD 0 
	END