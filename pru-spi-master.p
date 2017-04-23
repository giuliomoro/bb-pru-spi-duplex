.origin 0
.entrypoint START
#define USING_PRU_0 //set this according to the PRU we use

//#define BITBANG_SPI_FASTEST // allows to obtain a 10MHz symmetrical clock
#ifndef BITBANG_SPI_FASTEST
#define BITBANG_SPI_CLOCK_SLEEP 4 // a value of 0 gives a bitbang clock of 7.7 MHz. Add here additional sleep time (in 10ns).
#endif /* BITBANG_SPI_FASTEST */

#define PRU0_CONTROL_REGISTER_OFFSET 0x22000
#define PRU1_CONTROL_REGISTER_OFFSET 0x24000

#ifdef USING_PRU_0
#define PRU_CONTROL_REGISTER_OFFSET PRU0_CONTROL_REGISTER_OFFSET
#else 
#define PRU_CONTROL_REGISTER_OFFSET PRU1_CONTROL_REGISTER_OFFSET
#endif 
#define PRU_SPEED 200000000

#define SPI_WL 32
#define SPI_WL_BYTES (SPI_WL >> 3)

#define ASSERT_LEVEL 0 
#define UNASSERT_LEVEL 1
#define WAIT_AFTER_CS 1 // set to 1 as a minimum

// this needs to reflect PruSpiMasterContext
#define FIRST_BUFFER 0x0 
#define SECOND_BUFFER 0x400
#define CURRENT_BUFFER_PTR 0x800
#define TRANSMISSION_LENGTH 0x804

// these are the pins of the PRU''s own GPIOs that we want to use 
// for bitbang SPI.
#ifdef USING_PRU_0
#define BITBANG_SPI_CS_R30_PIN 5 /* P9_27 */
#define BITBANG_SPI_MISO_R31_PIN 15 /* P8_15*/
#define BITBANG_SPI_MOSI_R30_PIN 15 /* P8_11 */
#define BITBANG_SPI_SCK_R30_PIN 14 /* P8_12 */
#else
#error SPI master must be on PRU0 (because of the pinmux settings)
#endif

#define DO_SPI

#define reg_spi_addr r29
#define reg_start_scan r26
#define reg_device r25 
#define reg_num_devices r24
#define reg_scans_since_last_start_scan r23
#define reg_ticks r22
#define reg_transmission_length r21
#define reg_current_output_buffer r20 // a pointer to a location in memory where to write scan results
#define reg_log r19

#define reg_transmitted_bytes r5
#define reg_curr_word r6
#define reg_flags r7

#define FLAGS_CURRENT_BUFFER

#define TICKS_PER_START_SCAN 5
#define TICKS_PER_SECOND 1000
#define CYCLES_PER_TICK (PRU_SPEED/TICKS_PER_SECOND)


#define CONST_PRUCFG          C4
#define CONST_PRUDRAM        C24
#define CONST_PRUSHAREDRAM   C28
#define CONST_DDR            C31

// Address for the Constant table Block Index Register (CTBIR)
#define CTBIR          0x22020

// Address for the Constant table Programmable Pointer Register 0(CTPPR_0)
#define CTPPR_0         0x22028

// Address for the Constant table Programmable Pointer Register 1(CTPPR_1)
#define CTPPR_1         0x2202C

.macro COPY_BIT
.mparam output_reg, output_bit, input_reg, input_bit
QBBC CLEAR_OUTPUT_BIT, input_reg, input_bit
    SET output_reg, output_bit
    QBA DONE
CLEAR_OUTPUT_BIT:
    CLR output_reg, output_bit
    QBA DONE
    DONE:
.endm

.macro SET_CLEAR_BIT
.mparam output_reg, bit, value
    QBNE SET, value, 0
CLEAR:
    clr output_reg, bit
    QBA DONE
SET:
    set output_reg, bit
DONE:
.endm

.macro BITBANG_SPI_UNASSERT_CS
    MOV r27, UNASSERT_LEVEL
    SET_CLEAR_BIT r30, BITBANG_SPI_CS_R30_PIN, r27
.endm

.macro BITBANG_SPI_ASSERT_CS
    MOV r27, ASSERT_LEVEL
    SET_CLEAR_BIT r30, BITBANG_SPI_CS_R30_PIN, r27
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

// DELAY: Wait (busy loop) for a specified time
// Parameters:
//   count: how long to wait, in 10ns increments
//          this macr also adds a constant 10ns at the beginning 
// Uses registers: r27
.macro DELAY
.mparam count
    MOV r27, count
DELAY_LOOP:
    SUB r27, r27, 1
    QBNE DELAY_LOOP, r27, 0
.endm

.macro BUS_MODE_TX_RX
.mparam buffer, transmitLengthBytes
    BITBANG_SPI_ASSERT_CS
    /* Short delay, ~2us, to let slave device prepare */
    DELAY WAIT_AFTER_CS
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

.macro GET_PAYLOAD_ADDRESS
.mparam reg_destination
    // the payload is then at address CONST_PRUDRAM + FIRST_BUFFER
    MOV reg_destination, 0x0 // CONST_PRUDRAM
    ADD reg_destination, reg_destination, FIRST_BUFFER
.endm

.macro GET_BYTES_TO_WRITE
.mparam reg_destination
    // the loader will have placed the number of bytes to transmit
    // TRANSMISSION_LENGTH bytes into CONST_PRUDRAM
    MOV reg_destination, TRANSMISSION_LENGTH
    // load this in r1
    LBCO reg_destination, CONST_PRUDRAM, reg_destination, 4
.endm

.macro SIGNAL_ARM_OVER
    // reset word count to 0
    MOV r28, TRANSMISSION_LENGTH
    MOV r27, 0 
    SBCO r27, CONST_PRUDRAM, r28, 4
.endm

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

    MOV reg_device, 0
    MOV reg_num_devices, 4
    BITBANG_SPI_ASSERT_CS
    DELAY 1000
    BITBANG_SPI_UNASSERT_CS
    DELAY 1000
    BITBANG_SPI_ASSERT_CS
    DELAY 1000
    BITBANG_SPI_UNASSERT_CS
    DELAY 1000
WAIT_FOR_ARM:
    GET_BYTES_TO_WRITE r1
    // if there is nothing to send, wait again
    QBEQ WAIT_FOR_ARM, r1, 0

    GET_PAYLOAD_ADDRESS r2

    // transmit/receive r1 bytes from/in r2
    BUS_MODE_TX_RX r2, r1
COMMUNICATION_DONE:
    // signal ARM that the communication is over
    SIGNAL_ARM_OVER


    // and wait again
    QBA WAIT_FOR_ARM
