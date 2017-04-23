#include "pru-spi-common.ph"
.origin 0
.entrypoint START

//#define BITBANG_SPI_FASTEST // allows to obtain a 10MHz symmetrical clock
#ifndef BITBANG_SPI_FASTEST
#define BITBANG_SPI_CLOCK_SLEEP 4 // a value of 0 gives a bitbang clock of 7.7 MHz. Add here additional sleep time (in 10ns).
#endif /* BITBANG_SPI_FASTEST */

#ifdef PRU_SPI_MASTER_USING_PRU_0
#define PRU_CONTROL_REGISTER_OFFSET PRU0_CONTROL_REGISTER_OFFSET
#else 
#define PRU_CONTROL_REGISTER_OFFSET PRU1_CONTROL_REGISTER_OFFSET
#endif 


// these are the pins of the PRU''s own GPIOs that we want to use 
// for bitbang SPI.
#ifdef PRU_SPI_MASTER_USING_PRU_0
#define BITBANG_SPI_CS_R30_PIN 5 /* P9_27 */
#define BITBANG_SPI_MISO_R31_PIN 15 /* P8_15*/
#define BITBANG_SPI_MOSI_R30_PIN 15 /* P8_11 */
#define BITBANG_SPI_SCK_R30_PIN 14 /* P8_12 */
#else
#error SPI master must be on PRU0 (because of the pinmux settings)
#endif

.macro BITBANG_SPI_UNASSERT_CS
#ifdef ASSERT_LEVEL_LOW
    set r30, BITBANG_SPI_CS_R30_PIN
#else
    clr r30, BITBANG_SPI_CS_R30_PIN
#endif
.endm

.macro BITBANG_SPI_ASSERT_CS
#ifdef ASSERT_LEVEL_LOW
    clr r30, BITBANG_SPI_CS_R30_PIN
#else
    set r30, BITBANG_SPI_CS_R30_PIN
#endif
.endm

.macro BITBANG_SPI_TX_RX
.mparam data
    // r28 is our pointer to the current bit in the input/output word
    MOV r28, 0

BITBANG_LOOP:
    // 1) set clock low and at the same time write the output bit.
    //    Prepare the value to write to r30:
    //    read the current value ...
    MOV r27, r30
    //    ... clear the clock bit (clock low) ...
    CLR r27, BITBANG_SPI_SCK_R30_PIN
    //    ... copy the leftmost bit from the data to be written ...
    COPY_BIT r27, BITBANG_SPI_MOSI_R30_PIN, data, (SPI_WL - 1)
    //    ... now that r27 is ready with the clock and data out value,
    //        write it to r30 at once
    MOV r30, r27
    // do some house keeping before sleeping:
    //    we shift the input word left, so we discard the 
    //    bit we just wrote and we make room for the 
    //    incoming bit in data.t0 ...
    LSL data, data, 1
    // we increment the bit counter here
    ADD r28, r28, 1
    // 2) wait while holding the clock low
    //   DELAY times and NOP have been tweaked using a scope
    //   in order to obtain a symmetrical clock
#ifdef BITBANG_SPI_FASTEST
    DELAY 3
#else
    MOV r27, r27 // NOP, to make clock symmetric
    DELAY 4 + BITBANG_SPI_CLOCK_SLEEP
#endif /* BITBANG_SPI_FASTEST */
    // 3) clock goes high: this triggers the slave to write its
    //    output bit to the MISO line
    SET r30, BITBANG_SPI_SCK_R30_PIN
    // 4) wait while holding clock high
#ifndef BITBANG_SPI_FASTEST
    DELAY 1 + BITBANG_SPI_CLOCK_SLEEP
#endif /* ifndef BITBANG_SPI_FASTEST */
    // 5) we read the input:
    // ... and we fill bit 0 with the one we read from r31
    COPY_BIT data, 0, r31, BITBANG_SPI_MISO_R31_PIN
    QBNE BITBANG_LOOP, r28, SPI_WL

    // always make sure we pull the clock line down when we are done
    CLR r30, BITBANG_SPI_SCK_R30_PIN
.endm

.macro BUS_MODE_MASTER_TX_RX
.mparam buffer, transmitLengthBytes
    BITBANG_SPI_ASSERT_CS
    /* Short delay, ~2us, to let slave device prepare */
    DELAY DELAY_AFTER_CS
    MOV reg_transmitted_bytes, 0 // reg_transmitted_bytes counts how many bytes we transmitted
    // empty the destination register, so that words shorter than 32bits find it empty
    MOV reg_curr_word, 0
WRITE_BUFFER_LOOP:
    // load one word from memory
    LBBO reg_curr_word, buffer, reg_transmitted_bytes, SPI_WL_BYTES
    BITBANG_SPI_TX_RX reg_curr_word
    //store received word in memory
    SBBO reg_curr_word, buffer, reg_transmitted_bytes, SPI_WL_BYTES
    // increment pointer
    ADD reg_transmitted_bytes, reg_transmitted_bytes, SPI_WL_BYTES
    QBLT WRITE_BUFFER_LOOP, transmitLengthBytes, reg_transmitted_bytes
RECEIVE_DONE:
    BITBANG_SPI_UNASSERT_CS
.endm

.macro SIGNAL_ARM_OVER
    // reset word count to 0
    MOV r28, TRANSMISSION_LENGTH
    MOV r27, 0 
    SBCO r27, CONST_PRUDRAM, r28, 4
.endm

/*
.macro GET_CYCLE_COUNTER
.mparam out
    MOV r27, PRU_CONTROL_REGISTER_OFFSET
    LBBO out, r27, 0x000C, 4
.endm

.macro CLEAR_CYCLE_COUNTER
    MOV r27, PRU_CONTROL_REGISTER_OFFSET
    MOV r28, 0
    SBBO r28, r27, 0x000C, 4
.endm

.macro ENABLE_CYCLE_COUNTER
    MOV r28, PRU_CONTROL_REGISTER_OFFSET
    // Load content of the control register into r27
    LBBO r27, r28, 0, 4
    // Enable cycle counter
    OR r27, r27, 1 << 3
    // Store the new control register value
    SBBO r27, r28, 0, 4
.endm

.macro WAIT_FOR_TICK
WAIT_FOR_TICK_LOOP:
    GET_CYCLE_COUNTER r27
    MOV r28, CYCLES_PER_TICK
    QBGE WAIT_FOR_TICK_LOOP, r27, r28
    CLEAR_CYCLE_COUNTER
.endm
*/

START:
    MOV r30, 0 // turn off all outputs
    MOV r0, PRU_CONTROL_REGISTER_OFFSET
    // Set up c24 and c25 offsets with CTBIR register
    // Thus C24 points to start of PRU RAM
    OR  r3, r0, 0x20      // CTBIR0
    MOV r2, 0
    SBBO r2, r3, 0, 4

    // Enable OCP master port
    LBCO      r0, C4, 4, 4
    CLR     r0, r0, 4   // Clear SYSCFG[STANDBY_INIT] to enable OCP master port
    SBCO      r0, C4, 4, 4

WAIT_FOR_ARM:
    GET_PAYLOAD_LENGTH_MASTER r1
    // if there is nothing to send, wait again
    QBEQ WAIT_FOR_ARM, r1, 0

    GET_PAYLOAD_ADDRESS r2

    // transmit/receive r1 bytes from/in r2
    BUS_MODE_MASTER_TX_RX r2, r1
COMMUNICATION_DONE:
    // signal ARM that the communication is over
    SIGNAL_ARM_OVER


    // and wait again
    QBA WAIT_FOR_ARM
