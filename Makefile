BELA_PATH?=/root/Bela
OUTPUT=DemoPruSpi

#CC=clang
#CXX=clang++
OPT_FLAGS ?= -g -march=armv7-a -mtune=cortex-a8 -mfloat-abi=hard -mfpu=neon -ftree-vectorize -DNDEBUG -Wall -U_FORTIFY_SOURCE
PRU_OBJS ?= pru-spi-master.bin #pru-spi-slave.bin

CFLAGS ?= -I/usr/xenomai/include -I$(BELA_PATH)/include $(OPT_FLAGS)
CPPFLAGS ?= $(CFLAGS) -std=c++11
LDFLAGS ?= -L/usr/xenomai/lib -L/root/Bela/lib/
LDLIBS = -lrt -lnative -lxenomai -lprussdrv
OBJS ?= PruSpiMaster.o
DEMO_OBJS ?= DemoPruSpi.o $(OBJS)
OLD_OBJS ?= main.o loader.o $(OBJS)
LIB_OBJS = $(OBJS:.o=.fpic.o)
LIB_SO ?= libkeys.so
LIB_A ?= libkeys.a

DEMO_DEPS := $(notdir $(DEMO_OBJS:.o=.d))
OLD_DEPS := $(notdir $(OLD_OBJS:.o=.d))
LIB_DEPS := $(notdir $(LIB_OBJS:.o=.d))

all: $(PRU_OBJS) $(OUTPUT)

spi-pru: $(OLD) $(PRU_OBJS)
	@#an empty recipe

%.bin: %.p
	pasm -V2 -L -b $(@:%.bin=%.p) > /dev/null

#$(OUTPUT_LIB): lib DemoPruSpi.o
#	$(CXX) $(LDFLAGS) -L. -o $(OUTPUT_STATIC) DemoKeys.o $(LIB_A) $(LDLIBS)
#	$(CXX) $(LDFLAGS) -L. -o $(OUTPUT_SHARED) DemoKeys.o -lkeys $(LDLIBS) 

$(OUTPUT): $(DEMO_OBJS)
	$(CXX) $(LDFLAGS) -o "$@" $(DEMO_OBJS) $(LDLIBS)

%.o: %.cpp
	$(CXX) -std=c++11 -MMD -MP -MF"$(@:%.o=%.d)" "$<" -o "$@" -c $(CFLAGS)

#%.fpic.o: %.cpp
#	$(CXX) -std=c++11 -MMD -MP -MF"$(@:%.o=%.d)" "$<" -o "$@" -c $(CFLAGS) -fPIC

clean:
	rm -rf *.o *.bin $(OUTPUT) $(LIB_SO) $(LIB_A)

#lib: $(LIB_SO) $(LIB_A)

#$(LIB_SO): $(LIB_OBJS) $(PRU_OBJS)
#	gcc -shared -Wl,-soname,$(LIB_SO) $(LDLIBS) \
#    -o $(LIB_SO) $(LIB_OBJS) $(LDFLAGS)

#$(LIB_A): $(LIB_OBJS) $(PRU_OBJS) $(LIB_DEPS)
#	ar rcs $(LIB_A) $(LIB_OBJS)

-include $(DEMO_DEPS) $(LIB_DEPS)
run: all
	./$(OUTPUT)

.PHONY: all lib run
