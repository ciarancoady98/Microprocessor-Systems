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
	ldr r11, =SUM 								;Address in memory where we store our "stack"
	mov r12, #0									;R12 - number we are currently working on
	
	
;MAIN PROGRAM LOOP
;
;
;
mainloop
	ldr r0, =0
	bl press									;Poll to see if button has been pressed
												;Comparison value for Increase Current Number
	;ldr r0, =0x00100000
	cmp r0, #1									;if(press() != notPressed)
	beq endSwitch								
	cmp r0, #0x00200000							;Comparison value for Decrease Current Number
	ble numberChange
	b operatorChange
endSwitch
	b mainloop
	
;BRANCH AND LINK TO SUBROUTINES
;Recuired as we need to branch and link
;Can get rid of this by calculating offset with the pc
;
numberChange
	;mov r1, r12
	bl numberChangeSub
	b endSwitch
	
operatorChange
	;mov r1, r12
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
	;check if we are reversing
	and r2, r0, #1								;Mask out long press bit
	cmp r2, #1
	beq longPressOperator
longPressOperator
	str r12, [r11] 								;Store current number to our "stack"
	add r11, r11, #4 							;Increment stack address (full ascending stack)
	cmp r0, #0x00400000 						;if(operator != '+')
	beq addition
	;subtraction
	ldr r3, ='-'						
	str r3, [r11]								;pushToStack('-')
	b endOpChange
addition
	ldr r3, ='+'								;else if(operator == '+')
	str r3, [r11]								;pushToStack('+')
endOpChange
	add r11, r11, #4 							;Increment stack address
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
	bl longPress
	ldmfd sp!, {pc}
	
;longPress subroutine
;checks if press duration is longer than just one press
longPress
	stmfd sp!, {lr}
	mov r2, r0									;Temp store intial button press
	;wait delay time
	ldr	r5,=5000000								;Value for delay
dloop2
	cmp r5, #0								
	ble	enddloop2								;while(delay > 0){
	subs r5,r5,#1								; 		delay--
	b dloop2									;}
enddloop2
	ldr r0, =IO1PIN													
	ldr r0, [r0]								;Poll Pin Register
	ldr r1, =0x00f00000							;Mask for Button bits
	and r0, r0, r1								;Mask out Button bits
	mvn r0, r0									;Invert all bits so we can use button bits
	and r0, r0, r1								;Mask out other bits we don't need
	cmp r0, r2
	bne notLong
	;long press has occured
	orr r0, r0, #1								;Note this is a long press
	b endLong
notLong
	mov r0, r2									;button = temp
endLong
	ldmfd sp!, {pc}
	
;clearDisplay subroutine
;Turns off all LEDS
clearDisplay
	stmfd sp!, {r0-r7, lr}
	ldr	r1,=IO1SET
	str	r0,[r1]									;Turn the LEDs off
	ldmfd sp!, {r0-r7, pc}
	
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
	stmfd SP!, {lr, r3-r8}						;store registers to stack
	ldr r3, =0 									;count = 0
	ldr r4, =0 									;reversed number 
reverse
	cmp r3, #36									;while(count < number of digits to reverse){
	bge endreverse
	and r5, r0, #1 								;mask out least significant bit
	mov r0, r0, lsr #1 							;shift original number right 1 bit
	mov r4, r4, lsl #1 							;shift reversed number left 1 bit
	cmp r5, #1									;if(masked bit == 1){
	beq push1
	b endpush
push1
	orr r4, r4, #1								;mask in a 1
endpush
	add r3, r3, #1								;count++
	b reverse
endreverse
	mov r0, r4				
	ldmfd SP!, {pc, r3-r8}	

	
		
	AREA	DATA, READWRITE 
		
SUM SPACE 50
	
	END