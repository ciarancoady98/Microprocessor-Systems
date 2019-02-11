	AREA	Assignment2, CODE, READONLY
	IMPORT	main

	EXPORT	start
start

;Setup pin addresses
IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C
	
	ldr r0, =DISPLAYNUMBER				; number to be displayed
	ldr r0, [r0]
	ldr r1, =ASCIIREPRESENTATION		; space in memory for converted number
	ldr r2, =DIVISORTABLE				; table of values to convert digits
	
	bl getDecimal
	
	ldr	r1,=IO1DIR
	ldr	r6,=0x000f0000					; select P1.19--P1.16
	str	r6,[r1]							; make them outputs
	ldr	r1,=IO1SET
	str	r6,[r1]							; set them to turn the LEDs off
	ldr	r2,=IO1CLR
	ldr r3, =ASCIIREPRESENTATION
	
; r1 points to the SET register
; r2 points to the CLEAR register
; r3 points to the start of the decimal representation

wloop	
	ldr r0, [r3]
	bl reverseNumber
	mov r4, r0
	cmp r4, #-1
	beq endwloop
	str	r4,[r2]	   						; clear the bit -> turn on the LED
	ldr	r5,=40000000					; delay for about a half second
dloop
	cmp r5, #0								
	ble	enddloop						; while(delay > 0){
	subs r5,r5,#1						; 	delay--
	b dloop								; }
enddloop
	
	str	r6,[r1]							; set the bit -> turn off the LED
	add r3, r3, #4						; decimal representation address ++
	b	wloop
endwloop

stop	B	stop

;Reverse Number Subroutine
;Reverses the last 4 bits of a binary number
;then shifts it into the correct position to 
;be used as a mask with pin outputs
;
;R0 number being converted
;

reverseNumber

	stmfd SP!, {lr, r3-r8}				; store registers to stack
	ldr r3, =0 							; count = 0
	ldr r4, =0 							; reversed number 
reverse
	cmp r3, #4							; while(count < number of digits to reverse){
	bge endreverse
	and r5, r0, #1 						; mask out least significant bit
	mov r0, r0, lsr #1 					; shift original number right 1 bit
	mov r4, r4, lsl #1 					; shift reversed number left 1 bit
	cmp r5, #1							; if(masked bit == 1){
	beq push1
	b endpush
push1
	orr r4, r4, #1						; mask in a 1
endpush
	add r3, r3, #1						; count++
	b reverse
endreverse
	mov r0, r4, lsl #16					; shift reversed number to correct position
	ldmfd SP!, {pc, r3-r8}		


;Convert to Decimal Subroutine
;Converts a Unsigned interger to its decimal digits
;and saves it in memory
;
;R0 - number being converted
;R1 - memory address of space for decimal digits
;R2 - memory address of divisor table
;

getDecimal
	stmfd SP!, {lr, r3-r8}				; Store registers to stack
	
	ldr r6, =0							; bool corrected = true;
	cmp r0, #0							; if(number is negative){
	bge positive
	ldr r4, ='-'						; load negative sign
	str r4, [r1]						; store sign to memory space
	add r1, r1, #4						; digitAddress++
										; }
	ldr r4, =0xffffffff					; max negative number
	cmp r0, r4							; if(number == max negative number)
	bne complement
	sub r0, r0, #1						; subtract 1 to allow for conversion
	ldr r6, =1							; bool corrected = false
complement
	mvn r0, r0							; invert the bits
	add r0, r0, #1						; 2's complement
	b endsign
positive
	ldr r4, ='+'						; load positive sign
	str r4, [r1]						; store sign to memory space
	add r1, r1, #4						; digitAddress++
endsign	

	ldr r4, =0 							; Divisor table index = 0;
for
	cmp r4, #10							; for(index < divisorTable.length){
	bge endfor
	ldr r3, [r2] 						; load value at divisor table
if1
	cmp r0, r3							; if(numberBeingConverted >= divisor){
	blt endif1
	ldr r5, =0 							; digitCount = 0;
while
	cmp r0, r3							; while(numberBeingConverted >= divisor){
	blt endwh
	sub r0, r0, r3						; numberBeingConverted -= divisor
	add r5, r5, #1						; digitCount++
	cmp r6, #0							
	beq noOverflow						; if(|number| > max positive number)
	add r0, r0, #1						; add 1 to correct conversion
	ldr r6, =0							; bool corrected = true;
noOverflow
	b while
endwh
	;put decimal number into memory
	str r5, [r1]						; store digit to memory space
	ldr r5, =0							; digitCount = 0
	add r1, r1, #4						; digitAddress++
endif1
	add r4, r4, #1						; index++
	add r2, r2, #4						; divisorTableAddress++
	b for
endfor
	;terminate the string
	ldr r5, =-1							; load -1 as terminating character			
	str r5, [r1]						; store to digitAddress
	ldmfd SP!, {pc, r3-r8}				
		
	AREA	Table, DATA, READONLY
		
DISPLAYNUMBER
	DCD -4
			
DIVISORTABLE		
	DCD 1000000000
	DCD 100000000
	DCD 10000000
	DCD 1000000
	DCD 100000
	DCD 10000
	DCD 1000
	DCD 100
	DCD 10
	DCD 1
		
	AREA	AsciiConversion, READWRITE
		
ASCIIREPRESENTATION SPACE 12
	
	END
	

	
