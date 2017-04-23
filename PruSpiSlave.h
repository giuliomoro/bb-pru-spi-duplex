#ifndef PRUSPISLAVE_H_INCLUDED
#define PRUSPISLAVE_H_INCLUDED

#include <string.h>
#include <native/task.h>
#include <unistd.h>
#include "PruSpiContext.h"

#define PRU_SPI_SLAVE_NUM 1

class PruSpiSlave
{
public:
	PruSpiSlave() :
		_pruInited(false)
		, _pruEnabled(false)
		, _isPruRunning(false)
		, _isLoopRunning(false)
		, context(NULL)
	{ }

	~PruSpiSlave()
	{
		cleanup();
	}


	/**
	 * Enables the PRU.
	 */
	int init();

	/**
	 * Starts the PRU loop in continuous scan mode:
	 * it will periodically request frames from the connected devices.
	 */
	int start(volatile int* shouldStop, void(*callback)(void*), void* arg);

	/**
	 * Stops the PRU loop.
	 */
	void stop();

	/**
	 * Checks whether the thread should stop.
	 */
	bool shouldStop()
	// inlined for speed
	{
		return _shouldStop || *_externalShouldStop;
	}

	/**
	 * Disables the PRU and resets all the internal states.
	 */
	void cleanup();

    void waitForTransmissionToComplete(int sleepTime = 1000);

    unsigned int getLastTransmissionLength()
    {
        return context->length;
    }

    bool isTransmissionDone()
    {
        // PRU will set salveMaxTransmissionLength to 0 when it's done transmitting
        return context->slaveMaxTransmissionLength == 0;
    }

	int getBuffer()
	// inlined for speed
	{
		return context->buffer;
	}

    void enableReceive(unsigned int maxLength)
    {
        context->length = 0;
        context->slaveMaxTransmissionLength = maxLength;
    }

	uint8_t* getData()
	// inlined for speed
	{
		return &context->buffers[PRU_DATA_BUFFER_SIZE * context->buffer];
	}

	static void loop(void* arg);

private:
	bool _pruInited;
	bool _pruEnabled;
	bool _isPruRunning;
	bool _isLoopRunning;
	RT_TASK _loopTask;
	volatile int _shouldStop;
	volatile int* _externalShouldStop;
	uint8_t* _pruMem;
	unsigned int _numBoards;
	void(*_callback)(void*);
	void* _callbackArg;
	PruSpiContext* volatile context;
	const unsigned int _loopTaskPriority = 90;
	const char* _loopTaskName = "PruSpiSlave";
};
#endif /* PRUSPIMASTER_H_INCLUDED */

