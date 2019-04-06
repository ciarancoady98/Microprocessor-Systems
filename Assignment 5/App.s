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
	
	;Intialise spsr for debugging
	;mrs r1, cpsr
	;msr spsr_cxsf, r1
	
	;Branch to interrupt handler for debugging purposes
	;b irqhan
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
	;ldr	r4,=1
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
irqhan
	;Setup the return address as we want to re-excute the interrupted instruction
	sub	lr,lr,#4
	;Store the context of the thread we interrupted to the interrupt stack
	stmfd	sp!,{r0-r12,lr}
;this is the body of the interrupt handler
;switching threads
	ldr r0, =CURRENTTHREAD
	ldr r1, [r0]
	cmp r1, #-1
	beq initialSwitch
	cmp r1, #0
	beq switchToThread1
	cmp r1, #1 
	beq switchToThread0
	
initialSwitch
	;In here we setup the contexts and decide on which thread to run
	;Initialise thread contexts 
	;mov r0, sp ; save the current stack pointer
	;Set thread 1 as the running thread
	ldr r0, =CURRENTTHREAD
	ldr r1, =1
	str r1, [r0]
	;load the initial values for thread 0
	ldr sp, =THREAD0STACK
	ldr lr, =startBlinky0
	stmia sp!, {r0-r12, lr}
	;Store the spsr
	mrs r1, spsr
	str r1, [sp], #4
	;load the initial values for thread 1
	ldr sp, =THREAD1STACK
	ldr lr, =startBlinky1
	stmia sp!, {r0-r12, lr}
	;Store the spsr
	mrs r1, spsr
	str r1, [sp], #4
	;The stack pointer is now updated and ready
	;to restore thread 1
	b restoreContext
	
switchToThread1
	;Update current thread to thread 1
	ldr r0, =CURRENTTHREAD
	ldr r1, =1
	str r1, [r0]
	;Restore the context of the last thread from interrupt stack
	ldmfd sp!, {r0-r12, lr}
	;Save the context of the interrrupted thread to its stack
	ldr sp, =THREAD0STACK
	stmia sp!, {r0-r12, lr}
	;Store the spsr
	mrs r1, spsr
	str r1, [sp], #4
	;Setup the stack pointer for restore of thread 1
	ldr sp, =THREAD1STACK
	add sp, sp, #15*4
	b restoreContext
	
switchToThread0
	;Update current thread to thread 0
	ldr r0, =CURRENTTHREAD
	ldr r1, =0
	str r1, [r0]
	;Restore the context of the last thread from interrupt stack
	ldmfd sp!, {r0-r12, lr}
	;Save the context of the interrrupted thread to its stack
	ldr sp, =THREAD1STACK
	stmia sp, {r0-r12, lr}
	;Store the spsr
	mrs r1, spsr
	str r1, [sp], #4
	;Setup the stack pointer for restore of thread 0
	ldr sp, =THREAD0STACK
	add sp, sp, #15*4
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
	
	;Restore the spsr from memory to the cpsr
	ldr r0, [sp, #-4]!
	msr spsr_cxsf, r0
	;Resume the selected thread and return to the user mode
	ldmdb	sp,{r0-r12,pc}^
	
	
	AREA processStorage, READWRITE
		
THREAD0STACK SPACE 60	
THREAD1STACK SPACE 60
CURRENTTHREAD DCD -1
	END