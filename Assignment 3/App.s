	AREA	AsmTemplate, CODE, READONLY
	IMPORT	main

; sample program makes the 4 LEDs P1.16, P1.17, P1.18, P1.19 go on and off in sequence
; (c) Mike Brady, 2011 -- 2019.

	EXPORT	start
start

IO1PIN	EQU	0xE0028010
IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C

	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	
	;R12 - number we are currently working on
	mov r12, #0
mainloop
	bl press
	cmp r0, #0
	beq endSwitch
	cmp r0, #0x00400000
	bge numberChange
	b operatorChange
endSwitch
	b mainloop

numberChange
	bl numberChangeSub
	mov r1, r12
	b endSwitch
	
operatorChange
	bl operatorChangeSub
	mov r1, r12
	b endSwitch

stop	B	stop

;R0 - button pressed
;R1 - current number
numberChangeSub
	stmfd sp!, {r0-r1, lr}
	cmp r0, #0x0080000
	beq adding
	;subtracting
	sub r1, r1, #1
adding
	add r1, r1, #1
	bl updateDisplay
	ldmfd sp!, {r0-r1, pc}
	
operatorChangeSub

press
	stmfd sp!, {r0-r1, lr}
	ldr r0, =IO1PIN
	ldr r0, [r0]
	ldr r1, =0x00f00000
	and r0, r0, r1
	mvn r0, r0
	and r0, r0, r1
	ldmfd sp!, {r0-r1, pc}
	
clearDisplay
	stmfd sp!, {r0-r7, lr}
	ldr	r1,=IO1SET
	str	r0,[r1]		;set them to turn the LEDs off
	ldmfd sp!, {r0-r7, pc}
	
updateDisplay
	stmfd sp!, {r0-r7, lr}
	mov r0, r1, lsl #16
	ldr	r1,=IO1SET
	mov r2, #0x000f0000
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r1,=IO1CLR
	str	r0,[r1]		;turn on the LED's
	ldmfd sp!, {r0-r7, pc}

	END