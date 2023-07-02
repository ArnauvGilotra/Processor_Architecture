.define LED_ADDRESS 0x10 
.define HEX_ADDRESS 0x20 
.define SW_ADDRESS 0x30
.define SPEED_1 0xFF


            mv r3, #0x00

MAIN_LOOP:  mvt r4, #LED_ADDRESS
            // r3 holds the external counter value
            add r3, #1
            st  r3, [r4]

            // poll the switches into r1
            mvt r2, #SW_ADDRESS
            ld  r1, [r2]

            sub r1, #0x0
            bpl BEGIN_OUTER

            b MAIN_LOOP

BEGIN_OUTER: add r1, #0x2
OUTER_LOOP: sub r1, #1
            bne INNER_LOOP
            b   MAIN_LOOP

INNER_LOOP: mvt  r0, #SPEED_1
            b   DELAY

DELAY:      sub r0, #1
            bne DELAY
            b   OUTER_LOOP