/* Program that counts consecutive 1's */

        .text                   // executable code follows
        .global _start                  
_start:                             
        MOV     R4, #TEST_NUM   // load the data word ...
        MOV     R5, #0          // R5 will have the result

LOOP:   LDR     R1, [R4], #4    // into R1 goes the word at the R1 adr then post increament R1 adr to the next word
        CMP     R1, #0          // loop until the data contains no more 1's
        BEQ     END             
        MOV     R0, #0          // R0 will hold the result
        BL      ONES            // call the sub routine
        CMP     R5, R0          // is the number in R0 the newest longest seq?
        MOVLT   R5, R0          // if it is then put it in R5
        B       LOOP            
END:    B       END  

ONES:   CMP     R1, #0          // loop until the data contains no more 1's
        MOVEQ   PC, LR             
        LSR     R2, R1, #1      // perform SHIFT, followed by AND
        AND     R1, R1, R2      
        ADD     R0, #1          // count the string length so far
        B       ONES 

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

          .end                            
