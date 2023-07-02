/* Program that finds the largest number in a list of integers	*/
            
            .text                   // executable code follows
            .global _start                  
_start:                             
            MOV     R4, #RESULT     // R4 points to result location
            LDR     R0, [R4, #4]    // R0 holds the number of elements in the list
            MOV     R1, #NUMBERS    // R1 points to the start of the list
            BL      LARGE           
            STR     R0, [R4]        // R0 holds the subroutine return value

END:        B       END             

/* Subroutine to find the largest integer in a list
 * Parameters: R0 has the number of elements in the list
 *             R1 has the address of the start of the list
 * Returns: R0 returns the largest item in the list */
LARGE:      LDR     R2, [R1]        // R2 <- [R1] store the value in memory pointed by R1
LOOP:       SUBS    R0, #1          // R0 <- R0-1 decremeant counter
            BEQ     DONE            // subroutine is over when counter is 0 (Branch if equals to 0)
			ADD     R1, #4          // R1 <- R1+4 next number
            LDR		R3, [R1]		// R3 <- [R1] store the value in memory pointed by R1 in R3
            CMP     R2, R3          // compare the current largest and current number in the loop
            BGE     LOOP            // if R2 > R1 then loop again (Branch if greater than)
            MOV     R2, R3          // R2 <- R3 else move the newly found highest value into R2
            B       LOOP            // loop again
DONE:		MOV     R0, R2          // R0 <- R2 move the highest found value into R0
            MOV		PC, LR			// PC <- LR make the next instruction adr the instruction adr in LR

RESULT:     .word   0           
N:          .word   7           // number of entries in the list
NUMBERS:    .word   4, 5, 3, 6  // the data
            .word   1, 8, 2                 

            .end                            
