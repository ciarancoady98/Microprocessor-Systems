	AREA	Assignment2, CODE, READONLY
	IMPORT	main

; sample program makes the 4 LEDs P1.16, P1.17, P1.18, P1.19 go on and off in sequence
; (c) Mike Brady, 2011 -- 2019.

	EXPORT	start
start

;Setup pin addresses
;IO1DIR	EQU	0xE0028018
;IO1SET	EQU	0xE0028014
;IO1CLR	EQU	0xE002801C
;
;	ldr	r1,=IO1DIR
;	ldr	r2,=0x000f0000	;select P1.19--P1.16
;	str	r2,[r1]		;make them outputs
;	ldr	r1,=IO1SET
;	str	r2,[r1]		;set them to turn the LEDs off
;	ldr	r2,=IO1CLR
; r1 points to the SET register
; r2 points to the CLEAR register

;	ldr	r5,=0x00100000	; end when the mask reaches this value
;wloop	ldr	r3,=0x00010000	; start with P1.16.
;floop	str	r3,[r2]	   	; clear the bit -> turn on the LED

;delay for about a half second
;	ldr	r4,=4000000
;dloop	subs	r4,r4,#1
;	bne	dloop

;	str	r3,[r1]		;set the bit -> turn off the LED
;	mov	r3,r3,lsl #1	;shift up to next bit. P1.16 -> P1.17 etc.
;	cmp	r3,r5
;	bne	floop
;	b	wloop
	
	;
	;
	;
	;
	;
	;
	;
	
	ldr r0, =0x0000101B
	ldr r1, =ASCIIREPRESENTATION
	ldr r2, =DIVISORTABLE
	BL getDecimal
	

	
stop	B	stop

		

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
	

	
