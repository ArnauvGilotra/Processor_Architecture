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

                  BL       CONFIG_GIC         // configure the ARM generic
                                              // interrupt controller
                  BL       CONFIG_PRIV_TIMER  // configure A9 Private Timer
                  BL       CONFIG_KEYS        // configure the pushbutton
                                              // KEYs port

/* Enable IRQ interrupts in the ARM processor */
                  MOV      R0, #0b00010011         // disable the interrupt masking by setting I to 0
                  MSR      CPSR, R0
                  LDR      R5, =0xFF200000    // LEDR base address
LOOP:                                          
                  LDR      R3, COUNT          // global variable
                  STR      R3, [R5]           // write to the LEDR lights
                  B        LOOP                
          

/* Global variables */
                .global  COUNT
COUNT:          .word    0x0                  // used by timer
                .global  RUN
RUN:            .word    0x1                  // initial value to increment COUNT

/* Configure the A9 Private Timer to create interrupts at 0.25 second intervals */
CONFIG_PRIV_TIMER:                             
                LDR      R1, =0xfffec600       // priv timer adr
                LDR      R0, =50000000         // value for 0.25sec
                STR      R0, [R1]            

                MOV      R0, #0b111
                STR      R0, [R1, #0x8]        // Enable Timeer with auto reload and interrup

                MOV      PC, LR
                   
/* Configure the pushbutton KEYS to generate interrupts */
CONFIG_KEYS:                                    
                LDR      R1, =0xff200058         // Address of the Key Interrupts
                MOV      R0, #0b1111             // R0 <- 0b1111 We need to store 1 for all keys that we need to enable interrupts
                STR      R0, [R1]                // [R1] <- R0 enable interrupts for all keys
                MOV      PC, LR

/*--- IRQ ---------------------------------------------------------------------*/
IRQ_HANDLER:
                PUSH     {R0-R7, LR}
    
                /* Read the ICCIAR in the CPU interface */
                LDR      R0, =0xFFFEC100
                LDR      R1, [R0, #0x0C]         // read the interrupt ID

                CMP     R1, #73                 // if the interrupt ID is 73 then its the KEY PORT which generated the interrupt
                BLEQ    KEY_ISR

                CMP     R1, #73                 // check again whether it was key before exiting 
                BEQ     EXIT_IRQ

                CMP     R1, #29                 // if the interrupt ID is 29 then its the KEY PORT which generated the interrupt
                BLEQ    PRIV_TIMER_ISR

                CMP     R1, #29                 // for keys
                BEQ     EXIT_IRQ
UNEXPECTED:     BNE     UNEXPECTED

EXIT_IRQ:
                /* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R1, [R0, #0x10]
    
                POP      {R0-R7, LR}
                SUBS     PC, LR, #4

/****************************************************************************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine toggles the RUN global variable.
 ***************************************************************************************/
                .global  KEY_ISR
KEY_ISR:        PUSH     {R3 - R9}
                LDR      R5, =0xFF20005C             // R5 gets the edge capture reg
                LDR      R5, [R5]
                CMP      R5, #1                      // check if it was the key0
                BNE      change_speed                // if not equals then it was some other key hence branch to changing speed       
                LDR      R3, RUN                     // was key 0 so we toggle  
                MOV      R4, #1
                EOR      R4, R3                      // XORing a bit 1 basically toggles 0 xor 1 = 1 1 xor 1 = 0
                STR      R4, RUN
                B        done                       // IRQ has been handled... clear egde cap

change_speed:   LDR     R7, =0xfffec600             // R7 gets the adr of the timer
                MOV     R6, #0b110                  // code to make the timer stop   
                STR     R6, [R7, #0x8]              // put it in the reg
                LDR     R6, [R7]                    // get the timer load value into R6
                CMP     R5, #2                      // was it key1?
                LSREQ   R6, #1                      // LSR load val or divide by 2 hence doubling the speed 
                CMP     R5,# 4                      // was it key2? 
                LSLEQ   R6, #1                      // LSL load val or multiply by 2 hence halfing the speed
                STR     R6, [R7]                    // store it back into the load val register
                MOV     R6, #0b111                  // and start the timer
                STR     R6, [R7, #0x8]              // store the start code 

done:           LDR     R3, =0xFF20005C             // R3 gets the adr of the key edge cap
                LDR     R4, [R3]                    // store whatever was in the edge cap in R4
                STR     R4, [R3]                    // put that back in the egde cap reg to clear it
                POP     {R3 - R9}
                MOV     PC, LR

/******************************************************************************
 * A9 Private Timer interrupt service routine
 *                                                                          
 * This code toggles performs the operation COUNT = COUNT + RUN
 *****************************************************************************/
                .global    TIMER_ISR
PRIV_TIMER_ISR: PUSH     {R5-R9}
                LDR      R5, COUNT                   // get current count
                LDR      R6, RUN                     // R6 gets whatever is the value of RUN (1 or 0)
                LDR      R7, =0b1111111111           // there are 8 leds so this is the max they can show

                CMP      R5, R7                      // COUNT value in R5 has to less than the max supported by the 8 LEDs
                ADDLE    R5, R6                      // if R6 is one this will add 1 other wise adding 0 means it is stable
                CMP      R5, R7                      // if R5 is already 1111 1111 then thats the max and we got back to 0
                MOVGT    R5, #0
                STR      R5, COUNT                   // str R5 val in count as instructed

                LDR      R8, =0xFFFEC60C             // R8 gets the adr of the priv timer
                LDR      R9, [R8]                    // R9 gets whatever is the priv timer reg
                STR      R9, [R8]                    // put that exact thing back in to clear it
                
                POP      {R5-R9}
                MOV      PC, LR
/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                MOV      R0, #29
                MOV      R1, #CPU0
                BL       CONFIG_INTERRUPT
                
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