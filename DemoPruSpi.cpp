#include "PruSpiMaster.h"
#include "PruSpiSlave.h"
#include <unistd.h>
#include <signal.h>


volatile int gShouldStop = 0;
void catch_function(int signo){
	gShouldStop = 1;
}

void masterCallback(void* arg)
{
	printf("Master callback called\n");
}

void slaveCallback(void* arg)
{
    printf("Slave callback called\n");
}

PruSpiMaster* master;
PruSpiSlave* slave;
int main()
{
    master = new PruSpiMaster();
    slave = new PruSpiSlave();
	if(master->init() < 0)
	{
		fprintf(stderr, "Aborting\n");
		return 1;
	}
    if(slave->init() < 0)
    {
		fprintf(stderr, "Aborting\n");
		return 1;
    }

	master->start(&gShouldStop, masterCallback, NULL);
    slave->start(&gShouldStop, slaveCallback, NULL);

    int length = 0x200;
    int transmitBuf[length];
	signal(SIGINT, catch_function);
    //while(!gShouldStop){
        int* buf = (int*)master->getData();
        for(int n = 0; n < length; ++n){
            int value = n + 1;
            transmitBuf[n] = value;
            buf[n] = value;
        }
        int transmissionLength = length * sizeof(int);
        slave->enableReceive(transmissionLength);
        master->startTransmission(transmissionLength);
        printf("Transmitting\n");
        master->waitForTransmissionToComplete();
        printf("Transmitted\n");
            
        buf = (int*)slave->getData();
        int errors = 0;
        for(int n = 0; n < length; ++n)
        {
            if(buf[n] != transmitBuf[n]){
                if(errors < 5)
                    printf("Transmission error: transmitted %d received %d\n", transmitBuf[n], buf[n]);
                ++errors;
            }
        }
        if(errors)
            printf("%d errors during transmission\n", errors);
        else
        {
            printf("SUCCESS!\n");
            gShouldStop = 1;
        }
        usleep(100000);
    //}
    while(!gShouldStop);
	master->startTransmission(0);
	return 0;
}

