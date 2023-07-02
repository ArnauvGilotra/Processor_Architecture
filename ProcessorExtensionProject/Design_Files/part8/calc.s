DEPTH 4096
START: mv sp, =0x1000	
	   mv r4, =0x4000 //key address
	   
POLL_FIRST_NUMBER: ld r0, [r4]
				   and r0, #0x1 //checking if key 1 pressed
				   cmp r0, #0x1
				   bne POLL_FIRST_NUMBER //no key pressed
				   bl READ_SWITCHES
				   push r2 //pushed first number
				   mv r0, r2
				   mv r2, #0x10
				   bl REG
				   b POLL_SECOND_NUMBER
				  
POLL_SECOND_NUMBER: ld r0, [r4]
					and r0, #0x2 //key 2
				    cmp r0, #0x2
				    bne POLL_SECOND_NUMBER //no key pressed
				    bl READ_SWITCHES
				    push r2 //pushed second number
				    mv r0, r2
				    mv r2, #0x10
				    bl REG
				    b STORE_OPERATOR

STORE_OPERATOR: ld r0, [r4]
				and r0, #0x4 //key 3
				cmp r0, #0x4
				bne STORE_OPERATOR //no key pressed
				bl READ_SWITCHES
				push r2 //pushed operator switches value
				b CHECK_OPERATION

				  				   
// read_switches returns number in r2
READ_SWITCHES: mv r2, =0x3000 //switches
			   ld r2, [r2]
			   and r2, #0xf //only read the first four switches
			   mv pc, lr
			   
			   
CHECK_OPERATION: pop r2 //get switch status for operation
				 mv r3, r2
				 pop r2 
				 mv r1, r2 //second number
				 pop r2
				 mv r0, r2 //first number
				 mv r2, r3 //holds the switch value for operation again
				 and r3, #0x1 //SUM
				 cmp r3, #0x1
				 beq SUM
				 mv r3, r2
				 and r3, #0x2 //SUB
				 cmp r3, #0x2
				 beq SUB			 
				 mv r3, r2
				 and r3, #0x4 //MUL
				 cmp r3, #0x4
				 beq MULTIPLY
				 mv r3, r2
				 and r3, #0x8 //DIV
				 cmp r3, #0x8
				 beq DIVIDE					 
				 b END

END: b END
	
SUM: add r0, r1
	 b REG

SUB: sub r0, r1
	 b REG
	 
MULTIPLY: cmp r0, #0 //checking if 0
		  beq PRODUCT_ZERO
		  cmp r1, #0
		  beq PRODUCT_ZERO
		  push r2
		  mv r2, r0
MULTIPLY_LOOP:
	 	  sub r1, #1
		  cmp r1, #0
	 	  beq END_MULTIPLY //since we do not have mveq
		  add r0, r2
	 	  b MULTIPLY_LOOP
PRODUCT_ZERO: mv r0, #0
END_MULTIPLY: pop r2
			  b REG

DIVIDE: cmp r0, r1
		bmi DIVIDE_ZERO
		cmp r1, #0
		beq DIVIDE_ZERO
		push r2
		mv r2, #0 //use r2 as the counter
DIVIDE_LOOP: sub r0, r1
			 cmp r0, #0
			 bmi END_DIVIDE
			 add r2, #1
			 cmp r0, #0
			 beq END_DIVIDE 
			 b DIVIDE_LOOP
DIVIDE_ZERO: mv r0, #0
			 mv pc, lr
END_DIVIDE: mv r0, r2
			pop r2 
			b REG
			
DISPLAY_LED: mv r1, =0x1000
			 st  r0, [r1]
			 cmp r2, #0x10
			 bne END
			 mv pc, lr
			
			
REG:   push r1
       push r2
       push r3

       mv   r2, =0x2000 // point to HEX0

       mv   r3, #0            // used to shift digits
DIGIT: mv   r1, r0            // the register to be displayed
       lsr  r1, r3            // isolate digit
       and  r1, #0xF          // "    "  "  "
       add  r1, #SEG7         // point to the codes
       ld   r1, [r1]          // get the digit code
       st   r1, [r2]
       add  r2, #1            // point to next HEX display
       add  r3, #4            // for shifting to the next digit
       cmp  r3, #16           // done all digits?
       bne  DIGIT
       
       pop  r3
       pop  r2
       pop  r1
       
	   b DISPLAY_LED

SEG7:  .word 0b00111111       // '0'
       .word 0b00000110       // '1'
       .word 0b01011011       // '2'
       .word 0b01001111       // '3'
       .word 0b01100110       // '4'
       .word 0b01101101       // '5'
       .word 0b01111101       // '6'
       .word 0b00000111       // '7'
       .word 0b01111111       // '8'
       .word 0b01100111       // '9'
       .word 0b01110111       // 'A' 1110111
       .word 0b01111100       // 'b' 1111100
       .word 0b00111001       // 'C' 0111001
       .word 0b01011110       // 'd' 1011110
       .word 0b01111001       // 'E' 1111001
       .word 0b01110001       // 'F' 1110001