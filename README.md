PRU bitbanging master/slave SPI bus.

MASTER PRU 0
CS out  P9_27 R30)5 0x1a4 0x25
MISO in P8_15 R31.15 0x03c 0x26
MOSI out P8_11 R30.15 0x034 0x26
SCK out P8_12 R30.14 0x030 0x26

SLAVE PRU 1
CS in P8_44 R31.3 0x0ac 0x26
MISO out P8_43 R30.2 0x0a8 0x25
MOSI in P8_45 R31.0 0x0a0 0x26
SCK in P8_46 R31.1 0x0a4 0x26
