        .text                   // executable code follows
        .global _start                  
_start: 
            MOV     SP, #0x200000
            MOV     R5, #0
            MOV     R6, #0
            MOV     R7, #0
            MOV     R1, #TEST_NUM

LOOP:       LDR     R2, [R1], #4
            CMP     R2, #0
            BEQ     END
            
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
            MOV     R9, #ZEROONE
            LDR     R9, [R9]
            CMP     R3, #0
            MOVEQ   PC, LR

            //Check 1 with 1010...1010
            EOR     R3, R3, R9
            BL      ONES
            MOV     R11, R0

            MOV     R0, #0
            MOV     R9, #ONEZERO   
            MOV     R3, R2         //Put the original word back into R3
            //Check 2 with 0101....0101 
            EOR     R3, R3, R9
            BL      ONES

            CMP     R0, R11
            MOVLT   R0, R11
            LSR     R0, #1
            POP     {LR, R9, R11}
            MOV     PC, LR

TEST_NUM: .word   0x00000001 //1
          .word   0x00000002 //2
          .word   0x00000003 //3    
          .word   0x00000004 //4
          .word   0x00000005 //5
          .word   0x00000006 //6
          .word   0x00000007 //7
          .word   0x00000008 //8
          .word   0x00000009 //9
          .word   0x0000000f //10
          .word   0x0

ALL1:     .word   0xffffffff
ONEZERO:  .word   0xAAAAAAAA
ZEROONE:  .word   0x55555555

          .end