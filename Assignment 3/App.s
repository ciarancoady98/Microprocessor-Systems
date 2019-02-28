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
	ldr r11, =SUM ;sum in mem
	str r11, [r11]
	
	;R12 - number we are currently working on
	mov r12, #0
mainloop
	;bl press
	ldr r0, =0x00800000
	cmp r0, #0
	beq endSwitch
	cmp r0, #0x00400000
	bge numberChange
	b operatorChange
endSwitch
	b mainloop

numberChange
	;mov r1, r12
	bl numberChangeSub
	b endSwitch
	
operatorChange
	;mov r1, r12
	bl operatorChangeSub
	b endSwitch

stop	B	stop

;R0 - button pressed
;R12 - current number
numberChangeSub
	stmfd sp!, {lr}
	cmp r0, #0x00800000
	beq adding
	;subtracting
	sub r12, r12, #1
	b endNumberChange
adding
	add r12, r12, #1
	
endNumberChange
	
	mov r1, r12
	bl updateDisplay
	ldmfd sp!, { pc}
	
operatorChangeSub
	stmfd sp!, {lr}
	str r12, [r11] ; store num
	add r11, r11, #4 ; inc address
	cmp r0, #0x00200000 ; +
	beq addition
	;subtraction
	ldr r3, ='-'
	str r3, [r11]
	b endOpChange

addition
	ldr r3, ='+'
	str r3, [r11]
endOpChange
	add r11, r11, #4 ; inc adr
	ldmfd sp!, { pc}
	
press
	stmfd sp!, {lr}
	ldr r0, =IO1PIN
	ldr r0, [r0]
	ldr r1, =0x00f00000
	and r0, r0, r1
	mvn r0, r0
	and r0, r0, r1
	ldmfd sp!, {pc}
	
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
	
	ldr	r5,=40000000
dloop
	cmp r5, #0								
	ble	enddloop						; while(delay > 0){
	subs r5,r5,#1						; 	delay--
	b dloop	
	
enddloop
	ldr	r1,=IO1CLR
	str	r0,[r1]		;turn on the LED's
	ldmfd sp!, {r0-r7, pc}

	
		
	AREA	DATA, READWRITE 
		
SUM SPACE 50
	
	END