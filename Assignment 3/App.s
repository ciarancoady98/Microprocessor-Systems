	AREA	AsmTemplate, CODE, READONLY
	IMPORT	main

; sample program makes the 4 LEDs P1.16, P1.17, P1.18, P1.19 go on and off in sequence
; (c) Mike Brady, 2011 -- 2019.

	EXPORT	start
start

; INTIALISATION
;
;
;
IO1PIN	EQU	0xE0028010							;I/O Pin Register Address
IO1DIR	EQU	0xE0028018							;Set Direction Of Pins
IO1SET	EQU	0xE0028014							;Set Bits In Register (Turn off LEDS)
IO1CLR	EQU	0xE002801C							;Clear Bits In Register (Turn on LEDS)

	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000							;Select P1.19--P1.16
	str	r2,[r1]									;Make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]									;Turn the LEDs off (Set bits)
	mov r12, #0									;R12 - number we are currently working on
	mov r11, #0									;R11 - sum
	mov r10, #0									;R10 - operator
	mov r9, #0 									;R9 - last number
	mov r8, #0									;R8 - last button
	
;MAIN PROGRAM LOOP
;
;
;
mainloop
	ldr r0, =0
	b pressCheck								;Poll to see if button has been pressed
endPressCheck
	cmp r0, #0									;if(press() != notPressed)
	beq endSwitch								
	cmp r0, #0x00200000							;Comparison value for Decrease Current Number
	ble numberChange
	b operatorChange
endSwitch
	cmp r7, #0
	beq endMain
	mov r7, #0									;Reset clear flag
endMain
	b mainloop
	
;BRANCH AND LINK TO SUBROUTINES
;Required as we need to branch and link
;Can get rid of this by calculating offset with the pc
;

;Branch to the press subroutine
pressCheck
	bl press
	cmp r7, #1									;check if we just cleared
	beq endSwitch								;if we just cleared skip normal operation check
	b endPressCheck								;if we didn't clear anything find out what operation it is
	
;Branch to numberChange subroutine
numberChange
	bl numberChangeSub
	b endSwitch
	
;Branch to numberChange subroutine
operatorChange
	bl operatorChangeSub
	b endSwitch

stop	B	stop

;numberChange Subroutine
;
;R0 - button pressed
;R12 - current number
;
;Increses or decreases the current sum based
;on the button pressed
numberChangeSub
	stmfd sp!, {lr}								;Save link register to stack
	mov r8, #0									;last button = number
	cmp r0, #0x00100000							;if(buttonPressed != '+')
	beq adding	
	;subtracting
	sub r12, r12, #1							;currentNumber--
	b endNumberChange
adding											;else if(buttonPressed == '-')
	add r12, r12, #1							;currentNumber++
endNumberChange
	mov r1, r12
	bl updateDisplay							
	ldmfd sp!, { pc}
	
	
;operatorChange Subroutine
;
;R0 - button pressed
;R12 - current number
;
;Adds a plus or minus to our stack based
;on the button pressed
operatorChangeSub
	stmfd sp!, {lr}						
	mov r8, #1									;last button = operator
	cmp r10, #0									;if(firstOp) WE ARE PROBABLY UPDATING R10 AND THIS DOESNT WORK ANYMORE AS A RESULT
	beq firstNumber
	b endFirstNumber
firstNumber
	mov r11, r12								;sum = currentNumber
	b updateCurrentOp
endFirstNumber
	cmp r10, #'+'						
	bne minus
	add r11, r11, r12							;add
	b updateCurrentOp
minus
	sub r11, r11, r12							;sub


	
updateCurrentOp
	cmp r0, #0x00400000 						;if(operator != '+')
	beq addition
	;subtraction
	ldr r10, ='-'								;operator = -
	mov r9, r12									;lastNumber = currentNumber
	b endOpChange
addition
	ldr r10, ='+'								;else if(operator == '+')
	mvn r9, r12									
	add r9, r9, #1								;last number = -currentNumber
endOpChange
	mov r12, #0									;currentNumber = 0 DO I NEED THIS???
	mov r1, r11
	bl updateDisplay
	ldmfd sp!, { pc}

;press subroutine
;polls the I/O pin register to see if a 
;button has been pressed
press
	stmfd sp!, {lr}
	ldr r0, =IO1PIN													
	ldr r0, [r0]								;Poll Pin Register
	ldr r1, =0x00f00000							;Mask for Button bits
	and r0, r0, r1								;Mask out Button bits
	mvn r0, r0									;Invert all bits so we can use button bits
	and r0, r0, r1								;Mask out other bits we don't need
	cmp r0, #0x00400000							;if(operatorPressed)
	bge branchToLongPress						;check for long press
endLongPressBranch
	ldmfd sp!, {pc}
	
;Branch to long press subroutine
branchToLongPress
	bl longPress
	b endLongPressBranch
	
;long press subroutine
;polls the I/O pin register to see if a 
;button has been long pressed
longPress
	stmfd sp!, {r0,r6,lr}
	mov r5,#0									;pressDuration
	ldr r6, =50000000							;maxLongPress
	mov r7, r0									;tempButton = buttonPressed
dloop3	
	cmp r5, r6									;while(pressDuration < maxLongPress)
	beq enddloop3
	cmp r0, #0x00400000							;if(buttonPressed == '+' || buttonPressed == '-')						
	blt enddloop3
	ldr r0, =IO1PIN												
	ldr r0, [r0]								;Poll Pin Register
	ldr r1, =0x00f00000							;Mask for Button bits
	and r0, r0, r1								;Mask out Button bits
	mvn r0, r0									;Invert all bits so we can use button bits
	and r0, r0, r1								;Mask out other bits we don't need
updateButton
	cmp r0, #0									;if(buttonPressed)
	beq endUpdateButton
	mov r7, r0									;tempButton = buttonPressed
endUpdateButton
	
	add r5,r5,#1								;pressDuration++
	b dloop3									;
enddloop3
	
	ldr r6, =500000								;longPress comparison value
	cmp r5, r6									;if(pressDuration >= comparisionValue
	blt endLongPress
	cmp r7, #0x00800000							
	beq clearAll								;if(operator == '-')
	bl clearLastSub								;if(operator == '+')
endClear
	mov r7, #1									;lastOperation = clear
	b theActualEnd
endLongPress
	mov r7, #0									;lastOperation = not clear
theActualEnd
	mov r1, r11
	bl updateDisplay
	ldmfd sp!, {r0,r6,pc}
	
clearAll
	bl clearAllSub
	b endClear
	
clearAllSub
	stmfd sp!, {lr}
	mov r12, #0									;R12 - number we are currently working on
	mov r11, #0									;R11 - sum
	mov r10, #0									;R10 - operator
	mov r9, #0 									;R9 - last number
	mov r8, #0									;R8 - last button
	ldmfd sp!, {pc}
	
clearLastSub
	stmfd sp!, {lr}
	cmp r8, #0									;if(lastButton == number)
	beq numberLast
	add r11, r11, r9							;update sum
numberLast
	mov r10, #0								
	mov r9, #0 
	mov r8, #0
	mov r12, #0
	ldmfd sp!, {pc}
	
;updateDisplay subroutine
;Updates the value displayed on the LEDS
updateDisplay
	stmfd sp!, {r0-r7, lr}
	mov r0, r1, lsl #16							;Shift currentNumber to the correct position to mask
	bl reverseNumber
	ldr	r1,=IO1SET
	mov r2, #0x000f0000
	str	r2,[r1]									;Turn the LEDs off
	
	ldr	r5,=50000								;Value for delay
dloop
	cmp r5, #0								
	ble	enddloop								;while(delay > 0){
	subs r5,r5,#1								; 		delay--
	b dloop										;}
enddloop
	ldr	r1,=IO1CLR
	str	r0,[r1]									;Turn on correct LED's
	
	ldr	r5,=5000000								;Value for delay
dloop1
	cmp r5, #0								
	ble	enddloop1								;while(delay > 0){
	subs r5,r5,#1								; 		delay--
	b dloop1									;}
enddloop1
	ldmfd sp!, {r0-r7, pc}
	
;Reverse Number Subroutine
;Reverses a 4 bit binary number placing it
;in the correct position to turn on LEDS
;
;R0 number being converted
;
reverseNumber
	stmfd SP!, {lr, r3-r8}						; store registers to stack
	ldr r3, =0 									; count = 0
	ldr r4, =0 									; reversed number 
reverse
	cmp r3, #36									; while(count < number of digits to reverse){
	bge endreverse
	and r5, r0, #1 								; mask out least significant bit
	mov r0, r0, lsr #1 							; shift original number right 1 bit
	mov r4, r4, lsl #1 							; shift reversed number left 1 bit
	cmp r5, #1									; if(masked bit == 1){
	beq push1
	b endpush
push1
	orr r4, r4, #1								; mask in a 1
endpush
	add r3, r3, #1								; count++
	b reverse
endreverse
	mov r0, r4
	ldmfd SP!, {pc, r3-r8}	
	
	END