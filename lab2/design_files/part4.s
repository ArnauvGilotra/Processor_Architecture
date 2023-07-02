/* Subroutine to convert the digits from 0 to 9 to be shown on a HEX display.
 *    Parameters: R0 = the decimal value of the digit to be displayed
 *    Returns: R0 = bit patterm to be written to the HEX display
 */
 .global _start

SEG7_CODE:  MOV     R1, #BIT_CODES  
            ADD     R1, R0         // index into the BIT_CODES "array"
            LDRB    R0, [R1]       // load the bit pattern (to be returned)
            MOV     PC, LR              

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110
            .byte   0b01101101, 0b01111101, 0b00000111, 0b01111111, 0b01100111
            .skip   2      // pad with 2 bytes to maintain word alignment

_start: 
            MOV     SP, #0x200000
            MOV     R5, #0
            MOV     R6, #0
            MOV     R7, #0
            MOV     R1, #TEST_NUM

LOOP:       LDR     R2, [R1], #4
            CMP     R2, #0
            BEQ     DISPLAY
            
            //Find the longest seq of 1s
            MOV     R3, R2
            MOV     R0, #0
            BL      ONES
            CMP     R5, R0
            MOVLT   R5, R0
            //Done

            //Find the the longest seq of 0s
            MOV     R3, R2
            MOV     R0, #0
            BL      ZEROS
            CMP     R6, R0
            MOVLT   R6, R0
            //Done

            //Find the the longest seq of 0s
            MOV     R3, R2
            MOV     R0, #0
            BL      ALTERNATE
            CMP     R7, R0
            MOVLT   R7, R0
            //Done
            B       LOOP
END:        B       END

ONES:       PUSH {R4}
ONES_LOOP:  CMP R3, #0
            BEQ ONES_END
            LSR R4, R3, #1
            AND R3, R4
            ADD R0, #1
            B ONES_LOOP
ONES_END:   POP {R4}
            MOV PC, LR 

ZEROS:      PUSH    {LR, R8}
            MOV     R8, #ALL1
            LDR     R8, [R8]
            CMP     R3, R8         // Check if the word is only 1s
            MOVEQ   PC, LR          //if it is then we go back to loop as the longest seq is 0
            EOR     R3, R3, R8
            BL      ONES
            POP     {LR, R8}
            MOV     PC, LR

ALTERNATE:  PUSH    {LR, R9, R11}
            MOV     R0, #0
			MOV		R9, #ZEROONE
            LDR     R9, [R9]
            CMP     R3, #0
            MOVEQ   PC, LR

            //Check 1 with 1010...1010
            EOR     R3, R3, R9
            BL      ONES
            MOV     R11, R0

            MOV     R0, #0
			MOV		R9, #ONEZERO
            LDR     R9, [R9]   
            MOV     R3, R2         //Put the original word back into R3
            //Check 2 with 0101....0101 
            EOR     R3, R3, R9
            BL      ONES

            CMP     R0, R11
            MOVLT   R0, R11
            POP     {LR, R9, R11}
            MOV     PC, LR

DIVIDE:     MOV    R2, #0
CONT:       CMP    R0, #10           // R0 <- R1 Any divisor
            BLT    DIV_END
            SUB    R0, #10           // R0 <- R1 Any division
            ADD    R2, #1
            B      CONT
DIV_END:    MOV    R1, R2           // quotient in R1 (remainder in R0)
            MOV    PC, LR

TEST_NUM: //.word   0x00000001 //1
          //.word   0x00000002 //2
          //.word   0x00000003 //3    
          //.word   0x00000004 //4
          //.word   0x00000005 //5
          //.word   0x00000006 //6
          //.word   0x00000007 //7
          //.word   0x00000008 //8
          //.word   0x00000009 //9
          .word   0b00000010101011111 //10
          .word   0x0

ALL1:     .word   0xffffffff
ONEZERO:  .word   0xAAAAAAAA
ZEROONE:  .word   0x55555555


/* Display R5 on HEX1-0, R6 on HEX3-2 and R7 on HEX5-4 */
DISPLAY:    //PUSH    {R9,R10,R11,R8}
            LDR     R8, =0xFF200020 // base address of HEX3-HEX0
            MOV     R0, R5          // display R5 on HEX1-0
            BL      DIVIDE          // ones digit will be in R0; tens
                                    // digit in R1
            MOV     R9, R1          // save the tens digit
            BL      SEG7_CODE       
            MOV     R4, R0          // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit
                                    // code
            BL      SEG7_CODE       
            LSL     R0, #8
            ORR     R4, R0          
//---
            MOV     R0, R6          //R0 <- R6 
            BL      DIVIDE          // ones digit will be in R0; tens
                                    // digit in R1
            MOV     R9, R1          // save the tens digit
            BL      SEG7_CODE
            MOV     R10, R0         // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit
                                    //code
            BL      SEG7_CODE       
            LSL     R0, #8          
            ORR     R10, R0         

            LSL     R10, #16        //push it 16 bits 
            ORR     R4, R10         //ORR it so that we are able to display since the HEX display share the same word
//---
            STR     R4, [R8]        // display the numbers from R6 and R5
            LDR     R8, =0xFF200030 // base address of HEX5-HEX4
//---
            MOV     R0, R7          // display R7 on HEX5-4
            BL      DIVIDE          // ones digit will be in R0; tens
                                    // digit in R1
            MOV     R9, R1          // save the tens digit
            BL      SEG7_CODE
            MOV     R4, R0          // save bit code
            MOV     R0, R9          // retrieve the tens digit, get bit
                                    //code
            BL      SEG7_CODE
            LSL     R0, #8
            ORR     R4, R0
//---
            STR     R4, [R8]        // display the number from R7
            BL       END

            .end