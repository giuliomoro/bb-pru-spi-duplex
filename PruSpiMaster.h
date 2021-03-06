#ifndef PRUSPIMASTER_H_INCLUDED
#define PRUSPIMASTER_H_INCLUDED

#include "PruSpiContext.h"
#include <string.h>
#include <native/task.h>
#include <unistd.h>

#define PRU_SPI_MASTER_NUM 0


class PruSpiMaster
{
public:
	PruSpiMaster() :
		_pruInited(false)
		, _pruEnabled(false)
		, _isPruRunning(false)
		, _isLoopRunning(false)
		, context(NULL)
	{ }

	~PruSpiMaster()
	{
		cleanup();
	}


	/**
	 * Enables the PRU.
	 *
	 */
	int init();

	/**
	 * Starts the PRU loop
	 */
	int start(volatile int* shouldStop, void(*callback)(void*) = NULL, void* arg = NULL);

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

    bool isTransmissionDone()
    {
        return context->length == 0;
    }

	int getBuffer()
	// inlined for speed
	{
		return context->buffer;
	}

    void startTransmission(unsigned int length)
    {
        context->length = length;
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
	uint8_t* buffers[2];
	const unsigned int _loopTaskPriority = 90;
	const char* _loopTaskName = "PruSpiMaster";
};
#endif /* PRUSPIMASTER_H_INCLUDED */
