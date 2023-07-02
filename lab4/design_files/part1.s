               .equ      EDGE_TRIGGERED,    0x1
               .equ      LEVEL_SENSITIVE,   0x0
               .equ      CPU0,              0x01    // bit-mask; bit 0 represents cpu0
               .equ      ENABLE,            0x1

               .equ      KEY0,              0b0001
               .equ      KEY1,              0b0010
               .equ      KEY2,              0b0100
               .equ      KEY3,              0b1000

               .equ      IRQ_MODE,          0b10010
               .equ      SVC_MODE,          0b10011

               .equ      INT_ENABLE,        0b01000000
               .equ      INT_DISABLE,       0b11000000
/*********************************************************************************
 * Initialize the exception vector table
 ********************************************************************************/
                .section .vectors, "ax"

                B        _start             // reset vector
                .word    0                  // undefined instruction vector
                .word    0                  // software interrrupt vector
                .word    0                  // aborted prefetch vector
                .word    0                  // aborted data vector
                .word    0                  // unused vector
                B        IRQ_HANDLER        // IRQ interrupt vector
                .word    0                  // FIQ interrupt vector

/*********************************************************************************
 * Main program
 ********************************************************************************/
                .text
                .global  _start
_start:        
                /* Set up stack pointers for IRQ and SVC processor modes */
                MOV     R0, #0b10010            // R0 <- gets the IRQ mode bit code
                MSR     CPSR, R0                // CPSR <- gets mode code for IRQ
                //WE ARE IN IRQ MODE
                LDR     SP, =0x40000            // set SP of the IRQ mode

                MOV     R0, #0b10011            // R0 <- gets the SVC mode bit code
                MSR     CPSR, R0                // CPSR <- gets mode bit codes for SVC mode
                //WE ARE BACK IN SVC MODE
                LDR     SP, =0x20000            // set SP of the IRQ mode

                BL       CONFIG_GIC              // configure the ARM generic interrupt controller

                // Configure the KEY pushbutton port to generate interrupts
                LDR     R1, =0xff200058         // Address of the Key Interrupts
                MOV     R0, #0b1111             // R0 <- 0b1111 We need to store 1 for all keys that we need to enable interrupts
                STR     R0, [R1]                // [R1] <- R0 enable interrupts for all keys

                // enable IRQ interrupts in the processor
                MOV     R0, #0b00010011         // disable the interrupt masking by setting I to 0
                MSR     CPSR, R0                
IDLE:
                B        IDLE                    // main program simply idles

IRQ_HANDLER:
                PUSH     {R0-R7, LR}
    
                /* Read the ICCIAR in the CPU interface */
                LDR      R4, =0xFFFEC100
                LDR      R5, [R4, #0x0C]         // read the interrupt ID

CHECK_KEYS:
                CMP      R5, #73
UNEXPECTED:     BNE      UNEXPECTED              // if not recognized, stop here
    
                BL       KEY_ISR
EXIT_IRQ:
                /* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R5, [R4, #0x10]
    
                POP      {R0-R7, LR}
                SUBS     PC, LR, #4

/*****************************************************0xFF200050***********************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine checks which KEY(s) have been pressed. It writes to HEX3-0
 ***************************************************************************************/
                .global  KEY_ISR
KEY_ISR:
                PUSH    {R4-R12}
                LDR     R4, =0b00111111             // bit code for writing zero on hex
                LDR     R5, =0b00000110             // bit code for writing one on hex
                LDR     R6, =0b01011011             // bit code for writing Two on hex
                LDR     R7, =0b01001111             // bit code for writing three on hex

                LSL     R5, #8                      // shift R5 since it has to be displayed on HEX1    
                LSL     R6, #16                     // shift R6 since it has to be displayed on HEX2
                LSL     R7, #24                     // shift R7 since it has to be displayed on HEX3

                MOV     R8, #0

                LDR     R9, =0xFF200050             // R9 gets the address of the key port
                LDR     R10, =0xFF200020            // R10 gets the address of the Hex0-3 displays

                LDR     R0, [R9, #0xC]              // R0 gets the edge capture register of the KEY Port

                CMP     R0, #0b1000
                ORREQ   R8, R7
                CMP     R0, #0b100
                ORREQ   R8, R6
                CMP     R0, #0b10
                ORREQ   R8, R5
                CMP     R0, #0b1
                ORREQ   R8, R4

                LDR     R11, [R10]
                // If a hex was on before then due to XORing that bit code with itself again will basically close it 
                // but if the bit code was ZORed with 0s then it would turn the HEX disp ON as per the bit code
                EOR     R8, R11
                STR     R8, [R10]                     

                STR     R0, [R9, #0xC]              //Clear Edge Capture by storing whatever was in it back into it     

                POP    {R4-R12}
                MOV      PC, LR
/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                /* Enable the KEYs interrupts */
                MOV      R0, #73
                MOV      R1, #CPU0
                /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
                BL       CONFIG_INTERRUPT

                /* configure the GIC CPU interface */
                LDR      R0, =0xFFFEC100        // base address of CPU interface
                /* Set Interrupt Priority Mask Register (ICCPMR) */
                LDR      R1, =0xFFFF            // enable interrupts of all priorities levels
                STR      R1, [R0, #0x04]
                /* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
                 * allows interrupts to be forwarded to the CPU(s) */
                MOV      R1, #1
                STR      R1, [R0]
    
                /* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
                 * allows the distributor to forward interrupts to the CPU interface(s) */
                LDR      R0, =0xFFFED000
                STR      R1, [R0]    
    
                POP      {PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
                PUSH     {R4-R5, LR}
    
                /* Configure Interrupt Set-Enable Registers (ICDISERn). 
                 * reg_offset = (integer_div(N / 32) * 4
                 * value = 1 << (N mod 32) */
                LSR      R4, R0, #3               // calculate reg_offset
                BIC      R4, R4, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED100
                ADD      R4, R2, R4               // R4 = address of ICDISER
    
                AND      R2, R0, #0x1F            // N mod 32
                MOV      R5, #1                   // enable
                LSL      R2, R5, R2               // R2 = value

                /* now that we have the register address (R4) and value (R2), we need to set the
                 * correct bit in the GIC register */
                LDR      R3, [R4]                 // read current register value
                ORR      R3, R3, R2               // set the enable bit
                STR      R3, [R4]                 // store the new register value

                /* Configure Interrupt Processor Targets Register (ICDIPTRn)
                  * reg_offset = integer_div(N / 4) * 4
                  * index = N mod 4 */
                BIC      R4, R0, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED800
                ADD      R4, R2, R4               // R4 = word address of ICDIPTR
                AND      R2, R0, #0x3             // N mod 4
                ADD      R4, R2, R4               // R4 = byte address in ICDIPTR

                /* now that we have the register address (R4) and value (R2), write to (only)
                 * the appropriate byte */
                STRB     R1, [R4]
    
                POP      {R4-R5, PC}

                .end   
