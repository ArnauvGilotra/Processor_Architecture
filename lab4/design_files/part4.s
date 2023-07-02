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

/* ********************************************************************************
 * This program demonstrates use of interrupts with assembly code. The program 
 * responds to interrupts from a timer and the pushbutton KEYs in the FPGA.
 *
 * The interrupt service routine for the timer increments a counter that is shown
 * on the red lights LEDR by the main program. The counter can be stopped/run by 
 * pressing any of the KEYs.
 ********************************************************************************/
                .text
                .global  _start
_start:        
                /* Set up stack pointers for IRQ and SVC processor modes */
                MOV      R0, #0b10010010           // R0 <- gets the IRQ mode bit code
                MSR      CPSR, R0                // CPSR <- gets mode code for IRQ
                //WE ARE IN IRQ MODE
                LDR      SP, =0x40000            // set SP of the IRQ mode

                MOV      R0, #0b10010011            // R0 <- gets the SVC mode bit code
                MSR      CPSR, R0                // CPSR <- gets mode bit codes for SVC mode
                //WE ARE BACK IN SVC MODE
                LDR      SP, =0x20000            // set SP of the IRQ mode

                MOV      R0, #0b10010011         // enable the interrupt masking by setting I to 1
                MSR      CPSR, R0 

                BL       CONFIG_GIC         // configure the ARM generic interrupt controller

                BL       CONFIG_PRIV_TIMER  // configure the timer
                BL       CONFIG_TIMER       // configure the FPGA interval timer
                BL       CONFIG_KEYS        // configure the pushbutton KEYs

                MOV      R0, #0b00010011         // disable the interrupt masking by setting I to 0
                MSR      CPSR, R0

                LDR      R5, =0xFF200000    // LEDR base address
                LDR      R6, =0xFF200020    // HEX3-0 base address
LOOP:
                LDR      R3, COUNT          // global variable
                STR      R3, [R5]           // light up the red lights
                LDR      R4, HEX_code       // global variable
                STR      R4, [R6]           // show the time in format SS:DD

                B        LOOP                            

/* Global variables */
                .global  COUNT
COUNT:          .word    0x0                // used by timer
                .global  RUN
RUN:            .word    0x1                // initial value to increment COUNT
                .global  TIME
TIME:           .word    0x0                // used for real-time clock
                .global  HEX_code
HEX_code:       .word    0x0

/* Configure the A9 Private Timer to create interrupts every 0.25 seconds */
CONFIG_PRIV_TIMER:
                ... Code not shown 
                MOV      PC, LR
                   
/* Configure the FPGA interval timer to create interrupts at 0.01 second intervals */
CONFIG_TIMER:
                ... Code not shown 
                MOV      PC, LR

/* Configure the pushbutton KEYS to generate interrupts */
CONFIG_KEYS:
                ... Code not shown 
                MOV      PC, LR

/*--- IRQ ---------------------------------------------------------------------*/
IRQ_HANDLER:
                ... Code not shown 

                SUBS     PC, LR, #4

/****************************************************************************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine toggles the RUN global variable.
 ***************************************************************************************/
                .global  KEY_ISR
KEY_ISR:        
                ... Code not shown 
                MOV      PC, LR

/******************************************************************************
 * A9 Private Timer interrupt service routine
 *                                                                          
 * This code toggles performs the operation COUNT = COUNT + RUN
 *****************************************************************************/
                .global  PRIV_TIMER_ISR
PRIV_TIMER_ISR:
                ... Code not shown 
                MOV      PC, LR

/******************************************************************************
 * Interval timer interrupt service routine
 *                                                                          
 * This code performs the operation ++TIME, and produces HEX_code
 *****************************************************************************/
                .global  TIMER_ISR
TIMER_ISR:
                PUSH {R1-R12}

                MOV     R0, R6
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

                POP {R1-R12}

                MOV      PC, LR

/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                /* Enable A9 Private Timer interrupts */
                MOV      R0, #29
                MOV      R1, #CPU0
                BL       CONFIG_INTERRUPT
                
                /* Enable FPGA Timer interrupts */
                MOV      R0, #72
                MOV      R1, #CPU0
                BL       CONFIG_INTERRUPT

                /* Enable KEYs interrupts */
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

// ---
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
