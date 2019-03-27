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
;initialising the LED
	ldr	r1,=IO0DIR
	ldr	r6,=0x00260000					; select P0.21--P0.18 --P0.17
	str	r6,[r1]							; make them outputs
	ldr	r1,=IO0SET
	str	r6,[r1]							; CLR them to turn the LEDs ON
	
	ldr	r2,=IO0CLR
	ldr r3, =0x00020000
	str r3, [r2]
	ldr r12, =1 ; lights

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

;from here, initialisation is finished, so it should be the main body of the main program
	;LDR R1, =200	; current limit
wloop	
	LDR R2, =LIGHTS
	LDR R2, [R2]
	CMP R2, #200
	BNE wloop
	;ADD R1, R1, #200 ; increase the limit
	LDR R3,=IO0PIN
	LDR R3, [R3]
	MVN R3, R3
	AND R3, R3, #0X00260000
	CMP R3, #0x00020000
	BEQ redToGreen
	CMP R3, #0x00040000
	BEQ blueToRed
	CMP R3, #0X00200000
	BEQ greenToBlue
	B wend
	
redToGreen
	LDR R3, =IO0SET
	LDR R4, =0X00260000
	STR R4, [R3] ; turn all leds off
	LDR R3, =IO0CLR
	LDR R4,=0X00200000
	STR R4, [R3] ; turn on green light
	B wend
	
blueToRed
	LDR R3, =IO0SET
	LDR R4, =0X00260000
	STR R4, [R3] ; turn all leds off
	LDR R3, =IO0CLR
	LDR R4,=0X00020000
	STR R4, [R3] ; turn on red light
	B wend
	
greenToBlue
	LDR R3, =IO0SET
	LDR R4, =0X00260000
	STR R4, [R3] ; turn all leds off
	LDR R3, =IO0CLR
	LDR R4,=0X00040000
	STR R4, [R3] ; turn on blue light
	B wend
	
wend	
	;LDR R3, =0 
	;LDR R2, =LIGHTS
	;STR R3, [R2] ; reset mem address lights
	b	wloop  		; branch always
;main program execution will never drop below the statement above.

	AREA	InterruptStuff, CODE, READONLY
irqhan	sub	lr,lr,#4
	stmfd	sp!,{r0-r1,lr}	; the lr will be restored to the pc

;this is the body of the interrupt handler

;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts
	
	LDR R1, =LIGHTS ; load address of lights
	LDR R0, [R1]
	CMP R0, #200
	BLT increment
	;reset the counter
	LDR R0, #0
	B endLedMod
increment
	ADD R0, R0, #1
endLedMod
	STR R0, [R1];store 1 in lights address

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

	
	
	AREA lights,READWRITE
LIGHTS  DCD 0
		END
