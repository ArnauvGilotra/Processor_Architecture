.text
.global _start
 
_start:     LDR     R4, =0xff200050 //R4 gets the address of the key data registers
            LDR     R5, =0xff200020 //R5 gets the hex base address
            MOV     R0, #0 //R0 will hold the counter number to display
            MOV     R1, #0
 
key:        LDR     R6, [R4] //R6 gets the value inside the data reg
            CMP     R6, #0
            BEQ     key

            CMP     R6, #8 //key 3
            BGE     clear

            CMP     R6, #4 //key 2
            BGE     sub1

            CMP     R6, #2 //key 1
            BGE     add1

            CMP     R6, #0 //key 0
            BGE     reset 


reset:      LDR     R6, [R4]
            CMP     R6, #0
            BNE     reset //poll until the key is released
            MOV     R0, #0
            B       Display   

add1:       LDR     R6, [R4]
            CMP     R6, #0
            BNE     add1 //poll until the key is released
            CMP     R0, #9
            ADDLT   R0, #1
            B       Display

sub1:       LDR     R6, [R4]
            CMP     R6, #0
            BNE     sub1 //poll until the key is released
            CMP     R0, #0
            SUBGT   R0, #1
            B       Display

clear:      LDR     R6, [R4]
            CMP     R6, #0
            BNE     clear //poll until the key is released
            STR     R1, [R5]
            B       key


Display:    MOV     R9, #BIT_CODES
            ADD     R9, R0
            LDRB    R9, [R9]       
            MOV     R12, R9              // save bit code
            STR     R12, [R5]            // display the numbers
            B       key

BIT_CODES:  .byte   0b00111111, 0b00000110, 0b01011011, 0b01001111
            .byte   0b01100110, 0b01101101, 0b01111101, 0b00000111
            .byte   0b01111111, 0b01101111