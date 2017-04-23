#ifndef PRU_SPI_COMMON_PH
#define PRU_SPI_COMMON_PH

#define PRU_SPI_MASTER_USING_PRU_0
#define PRU_SPI_SLAVE_USING_PRU_1

#define ASSERT_LEVEL_LOW // use ASSERT_LEVEL_HIGH otherwise

#define SPI_WL 32
#define SPI_WL_BYTES (SPI_WL >> 3)

// this needs to reflect the PruSpiContext struct
#define FIRST_BUFFER 0x0 
#define SECOND_BUFFER 0x400
#define CURRENT_BUFFER_PTR 0x800
#define TRANSMISSION_LENGTH 0x804
#define RECEIVE_MAX_LENGTH 0x808


#define PRU0_CONTROL_REGISTER_OFFSET 0x22000
#define PRU1_CONTROL_REGISTER_OFFSET 0x24000
#define PRU_SPEED 200000000

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

.macro GET_PAYLOAD_ADDRESS
.mparam reg_destination
    // the payload is then at address CONST_PRUDRAM + FIRST_BUFFER
    MOV reg_destination, 0x0 // CONST_PRUDRAM
    ADD reg_destination, reg_destination, FIRST_BUFFER
.endm

.macro GET_PAYLOAD_LENGTH_MASTER
.mparam reg_destination
    // the loader will have placed the number of bytes to transmit
    // TRANSMISSION_LENGTH bytes into CONST_PRUDRAM
    MOV reg_destination, TRANSMISSION_LENGTH
    // load this in r1
    LBCO reg_destination, CONST_PRUDRAM, reg_destination, 4
.endm

.macro GET_PAYLOAD_LENGTH_SLAVE
.mparam reg_destination
    // the loader will have placed the number of bytes to transmit
    // RECEIVE_LENGTH bytes into CONST_PRUDRAM
    MOV reg_destination, RECEIVE_MAX_LENGTH
    // load this in r1
    LBCO reg_destination, CONST_PRUDRAM, reg_destination, 4
.endm


#endif
