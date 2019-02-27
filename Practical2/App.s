	AREA	AsmTemplate, CODE, READONLY
	IMPORT	main

	EXPORT	start
start

IO1DIR	EQU	0xE0028018
IO1SET	EQU	0xE0028014
IO1CLR	EQU	0xE002801C

	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
; r1 points to the SET register
; r2 points to the CLEAR register


	LDR r5,=DISPLAYNUMBER
	LDR r5, [r5]
	;load in address of codes
	LDR r7,=codes
	LDR r8,=tens1
	
;Handle sign
ifNeg
	MOVS r6, r5, LSL #1 ; shift number up so sign bit is in tmp reg to check
	BCS negg ; if carry set then its sign bit is one and it is negative
poss
	LDR r6,=10 ; if positive add 1010 to array as this is laast 4 bits of ascii code for +
	MOV r6, r6, LSL #16 ; shift it up to right format
	STR r6, [r7], #4 ;store plus in array and increment address
	B	endIfNeg
negg
	LDR r6,=11 ; if negative add 1011 to arr as this is last 4 bits of ascii code for -
	MOV r6, r6, LSL #16 ; shift to format
	STR r6, [r7], #4 ;store minus in array and increment address
	
	MVN r5, r5 ; invert input number 1s complement
	ADD r5, r5, #1	;performing 2s complement to get magnitude of signed number
endIfNeg

	CMP r5, #0
	BNE notZeroHandler
zeroHandler
	LDR	r6, =-1
	STR r6, [r7], #4
	B leds
notZeroHandler

;now we find the digits
	LDR r11,=0	;leading zero boolean
digitFinder	

	
	LDR r6, [r8], #4 ;load in power of ten and increment address
	
	MOV r9, #0	;count
	MOV r10, r5	; temp=input number
subb 
	SUB r10, r10, r6 ;temp=temp-tens[i]
	ADD r9, r9, #1 ;count++
	
	CMP r5, r10 ; if(input num > temp) loop again, if not temp has gone negative and overflowed
	BHI subb ;
	CMP r10, #0 ; if(temp=0) divided evenly
	BEQ format
;here its less than zero so we need to add back before formatting as we have gone step too far	
	SUB r9, r9, #1	;correct count, because its less than zero so one was added too much
	MUL r10, r9, r6 ; tmp=countX tens[i] to get whats been taken off
	SUB r5, r5, r10 ; update input val to reflect whats been taken off
	
format
	
	MOV r9, r9, LSL #16 ; shift count over to correct place, dont add 0x3a as only need last four bits which is a anyway
	CMP r9, #0	;need to invert zero
	BNE notZero
	MOV r9,#0x000F0000	;1111 0000 0000 ... 0000 'inverting zero'
	CMP r11, #1 ; if(leadingZero=0) 
	BNE endZero;
notZero
	MOV r11, #1 ; leadingZero=true;

	STR r9, [r7], #4 ; codes[i]=formatted count value
endZero
	
	CMP r6, #1 ; if(tens[i] =1) were at end of array and need to exit loop
	BNE digitFinder ; loop back to top


leds
	MOV r5, #0	;index
	LDR r7,=codes	;address of aray
display
	ldr r3, =-1
	STR	r3,[r2]	   	; clear the bit -> turn on the LED	
	
;delay for about a half second
	LDR	r4,=10000000
dloop1	SUBS	r4,r4,#1
	BNE	dloop1
	
	STR	r3,[r1]		;set the bit -> turn off the LED
	
wloop	LDR	r3,[r7,r5]	;get value of first code from array
	MOV r0, r3, lsr #16
	BL reverseNumber
	MOV r3, r0
	STR	r3,[r2]	   	; clear the bit -> turn on the LED	
	
;delay for about a half second
	LDR	r4,=10000000
dloop	SUBS	r4,r4,#1
	BNE	dloop
	
	STR	r3,[r1]		;set the bit -> turn off the LED
	ADD r5, r5, #4	;increment index
	
	;delay for about a half second
	LDR	r4,=10000000
dloop2	SUBS	r4,r4,#1
	BNE	dloop2
	
	CMP r5, #44 ; this is the highest the index can go as there is a max length of 11 codes as this is signed 
		    ;and therefore a range of 2 billion aprx to negative 2 bn. This is 10 seperate codes plus the +/- makes it 11 and then times 4 as there word sized.
	BNE wloop ; if not at end of codes to display loop back up
	MOV r5, #0 ; if at end reset index to 0 and start at start of codes array again to loop indefinetly
	B	display
	
	
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


	AREA tens, DATA, READONLY
	
tens1

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
	
	

DISPLAYNUMBER
	DCD 0


	

	
		
	AREA asciiCodes, DATA, READWRITE ; where we write the ascii code bits to, to light up the array

codes


	END
		
		
