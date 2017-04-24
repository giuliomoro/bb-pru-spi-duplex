#include "PruSpiMaster.h"
#include "PruSpiSlave.h"
#include <unistd.h>
#include <signal.h>


volatile int gShouldStop = 0;
void catch_function(int signo){
	gShouldStop = 1;
}

PruSpiMaster master;
PruSpiSlave slave;
int main()
{
	if(master.init() < 0)
	{
		fprintf(stderr, "Aborting\n");
		return 1;
	}
    if(slave.init() < 0)
    {
		fprintf(stderr, "Aborting\n");
		return 1;
    }

	master.start(&gShouldStop);
    slave.start(&gShouldStop);

    int length = 0x200;
    int originalMasterBuf[length];
    int originalSlaveBuf[length];
	signal(SIGINT, catch_function);
    while(!gShouldStop){
        int* masterBuf = (int*)master.getData();
        int* slaveBuf = (int*)slave.getData();
        for(int n = 0; n < length; ++n){
            int masterValue = n + 1;
            originalMasterBuf[n] = masterValue;
            masterBuf[n] = masterValue;
            int slaveValue = n * 2 + 1;
            originalSlaveBuf[n] = slaveValue;
            slaveBuf[n] = slaveValue;
        }
        int transmissionLength = length * sizeof(int);
        slave.enableReceive(transmissionLength);

        master.startTransmission(transmissionLength);
        printf("Transmitting\n");
        slave.waitForTransmissionToComplete();
        printf("Completed: master sent %d bytes, slave received %d bytes\n", transmissionLength, slave.getLastTransmissionLength());
        int errors = 0;
        for(int n = 0; n < length; ++n)
        {
            if(slaveBuf[n] != originalMasterBuf[n]){
                printf("MOSI error: transmitted %d received %d\n", originalMasterBuf[n], slaveBuf[n]);
                ++errors;
            }

            if(masterBuf[n] != originalSlaveBuf[n]){
                printf("MISO error: transmitted %d received %d\n", originalSlaveBuf[n], masterBuf[n]);
                ++errors;
            }
        }
        if(errors)
            printf("%d errors during transmission\n", errors);
        else
        {
            printf("SUCCESS: data integrity verified\n");
        }
        usleep(100000);
    }
	return 0;
}

