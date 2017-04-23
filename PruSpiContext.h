#ifndef PRUSPICONTEXT_H
#define PRUSPICONTEXT_H

#include <inttypes.h>

#define PRU_DATA_BUFFER_SIZE 0x400

typedef struct {
	uint8_t buffers[PRU_DATA_BUFFER_SIZE * 2];
	uint32_t buffer; // current buffer (0 or 1)
    uint32_t length; // length of the transmission (bytes). 
    // Master sets this before beginning, PRU resets it to 0 when done.
    // Slave can read this after transmission to check how many bytes 
    // were effectively transmitted
    uint32_t slaveMaxTransmissionLength; // unused by Master
    // Slave uses this as max length of the transmission, PRU resets it to 0 when done
} PruSpiContext;

#endif
