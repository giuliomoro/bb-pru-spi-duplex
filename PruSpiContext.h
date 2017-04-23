#ifndef PRUSPICONTEXT_H
#define PRUSPICONTEXT_H

#include <inttypes.h>

#define PRU_DATA_BUFFER_SIZE 0x400

typedef struct {
	uint8_t buffers[PRU_DATA_BUFFER_SIZE * 2];
	uint32_t buffer;
    uint32_t length;
    uint32_t receiveLength;
} PruSpiContext;

#endif
