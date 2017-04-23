#include "PruSpiMaster.h"
#include <unistd.h>
#include <signal.h>


volatile int gShouldStop = 0;
void catch_function(int signo){
	gShouldStop = 1;
}

void masterCallback(void* arg)
{
	printf("Callback called\n");
}

PruSpiMaster* master;
int main()
{
    master = new PruSpiMaster();
	if(master->init() < 0)
	{
		fprintf(stderr, "Aborting\n");
		return 1;
	}

	master->start(&gShouldStop, masterCallback, NULL);

	signal(SIGINT, catch_function);
    while(!gShouldStop){
        int* buf = (int*)master->getData();
        int length = 0x200;
        for(int n = 0; n < length; ++n)
            buf[n] = n + 1;
        int transmissionLength = length * sizeof(int);
        master->startTransmission(transmissionLength);
        printf("Transmitting\n");
        master->waitForTransmissionToComplete();
        printf("Transmitted\n");
            
        usleep(100000);
    }
	master->startTransmission(0);
	return 0;
}

