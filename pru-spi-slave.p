#include "pru-spi-common.ph"
.origin 0
.entrypoint START

#ifdef SLAVE_USING_PRU_0
#define PRU_CONTROL_REGISTER_OFFSET PRU0_CONTROL_REGISTER_OFFSET
#else 
#define PRU_CONTROL_REGISTER_OFFSET PRU1_CONTROL_REGISTER_OFFSET
#endif 

// these are the pins of the PRU''s own GPIOs that we want to use 
// for bitbang SPI.
#ifdef SLAVE_USING_PRU_0
#error SPI slave must be on PRU1 (because of the pinmux settings)
#else
#define BITBANG_SPI_CS_R31_PIN 3 /* P8_44 */
#define BITBANG_SPI_MISO_R30_PIN 2 /* P8_43*/
#define BITBANG_SPI_MOSI_R31_PIN 0 /* P8_45 */
#define BITBANG_SPI_SCK_R31_PIN 1 /* P8_46 */
#endif

#define reg_transmitted_bytes r5
#define reg_curr_word r6
#define reg_flags r7

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
    //    incoming bit in in data.t0 ...
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

.macro STORE_RECEIVED_BYTES
    MOV r27, TRANSMISSION_LENGTH
    SBCO reg_transmitted_bytes, CONST_PRUDRAM, r27, 4
.endm

// wait till the line is asserted
.macro WAIT_FOR_CS
#ifdef ASSERT_LEVEL_LOW
    //wait for byte to clear
    WBC r31, BITBANG_SPI_CS_R31_PIN
#else
    //wait for byte to be set
    WBS r31, BITBANG_SPI_CS_R31_PIN
#endif
.endm

.macro IS_CS_ASSERTED
.mparam result
#ifdef ASSERT_LEVEL_LOW
    QBBC SET, r30, BITBANG_SPI_CS_R31_PIN
#else
    QBBS SET, r30, BITBANG_SPI_CS_R31_PIN
#endif
CLEAR:
SET:
DONE:
.endm

.macro BUS_MODE_SLAVE_RX_TX
.mparam buffer, transmitLengthBytes
    WAIT_FOR_CS
    SET R30, 2
    HALT
    MOV reg_transmitted_bytes, 0 // reg_transmitted_bytes counts how many bytes we transmitted
    // empty the destination register, so that words shorter than 32bits find it empty
    MOV reg_curr_word, 0
WRITE_BUFFER_LOOP:
    // load one word from memory
    LBBO reg_curr_word, buffer, reg_transmitted_bytes, SPI_WL_BYTES
    //BITBANG_SPI_SLAVE_RX_TX reg_curr_word
    //store received word in memory
    SBBO reg_curr_word, buffer, reg_transmitted_bytes, SPI_WL_BYTES
    // increment pointer
    ADD reg_transmitted_bytes, reg_transmitted_bytes, SPI_WL_BYTES
    // Check if CS has been unasserted in the meantime
    IS_CS_ASSERTED r27
    QBLT WRITE_BUFFER_LOOP, transmitLengthBytes, reg_transmitted_bytes
WRITE_BUFFER_LOOP_DONE:
    STORE_RECEIVED_BYTES
.endm

.macro SIGNAL_ARM_OVER
    // write the number of bytes received
    MOV r28, TRANSMISSION_LENGTH
    MOV r27, reg_transmitted_bytes
    SBCO r27, CONST_PRUDRAM, r28, 4
.endm

START:
    MOV reg_flags, 0
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
    GET_PAYLOAD_LENGTH_SLAVE r1
    // check if we are ready to receive
    QBEQ WAIT_FOR_ARM, r1, 0

    GET_PAYLOAD_ADDRESS r2
    // transmit/receive up to r1 bytes from/in r2
    BUS_MODE_SLAVE_RX_TX r2, r1
COMMUNICATION_DONE:
    // signal ARM that the communication is over
    SIGNAL_ARM_OVER
    // and wait again
    QBA WAIT_FOR_ARM
