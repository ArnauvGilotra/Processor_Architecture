.text
.global _start

_start:     MOV		SP, #0x20000
			LDR     R4, =0xff20005c //R4 gets the address of the edge capture key reg
            LDR     R5, =0xff200020
            MOV     R6, #0 //R0 will hold the counter number to display
            LDR     R3, =0xFFFEC600
            LDR     R7, =2000000
            STR     R7, [R3], #8 //store in val and post incremeant to control reg
            LDR     R7, =0x03
            STR     R7, [R3], #4
            MOV     R12, #0

Main_l:     MOV     R0, R6
            BL      DIVIDE

            MOV     R9, #BIT_CODES
            ADD     R9, R0 // Ones digit in R0
            LDRB    R9, [R9]
            MOV     R10, R9

            MOV     R0, R1
            BL      DIVIDE

            MOV     R9, #BIT_CODES
            ADD     R9, R0 // Tens digit in R0
            LDRB    R9, [R9]
            LSL     R9, #8
            ORR     R10, R9

            MOV     R0, R1
            BL      DIVIDE

            MOV     R9, #BIT_CODES
            ADD     R9, R0 // hundred digit in R0
            LDRB    R9, [R9]
            LSL     R9, #16
            ORR     R10, R9

            MOV     R0, R1
            BL      DIVIDE

            MOV     R9, #BIT_CODES
            ADD     R9, R0 // Thousands digit in R0
            LDRB    R9, [R9]
            LSL     R9, #24
            ORR     R10, R9

            STR     R10, [R5] 

key:        LDR     R11, [R4]
            CMP     R11, #0 //R11 holds edge cap reg. if not zero then a key was pressed
            EORNE   R12, #1 // XORing the last bit of R12, last bit 0 XOR 1 = 1, last bit 1 XOR 1 = 0. 
            CMP     R11, #0 // edge cap not zero that means key was pressed
            STRNE   R11, [R4] // we reset by putting whatever was there in the edge cap reg back into it 

            CMP     R12, #1 //make this 0 if you want the counter to start after a key press 
            //or 1 if you want the counter to start automatically
            BEQ     key //poll in press until R12 is 1 that indicates we count up. 
            LDR     R7, [R3]
            CMP     R7, #1
            BEQ     add1
            B       key

DIVIDE:     MOV    	R2, #0
CONT:       CMP    	R0, #10         	// modified for modular divisor
            BLT    	DIV_END
            SUB    	R0, #10        	 	// modified for modular divisor
            ADD    	R2, #1
            B      	CONT
DIV_END:    MOV    	R1, R2     			// tens in R1, ones in R0
			MOV		PC, LR

add1:       PUSH    {R4}
            LDR     R4, =0x176f
            STR     R7, [R3]
            CMP     R6, R4
            BGE     reset
            ADD     R6, #1
            POP     {R4}
            B       Main_l

reset:      POP     {R4}
            MOV     R6, #0
            B       Main_l

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111
            .byte   0b01100110, 0b01101101, 0b01111101, 0b00000111
            .byte   0b01111111, 0b01101111
            .skip   2      // pad with 2 bytes to maintain word alignment

            .end