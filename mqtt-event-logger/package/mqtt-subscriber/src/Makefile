# Assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# Linker and compile options
LDFLAGS ?= #-pthread -lrt
CFLAGS  ?= -g -Wall -Werror

# Default target
all: mqtt-subscriber

mqtt-subscriber: paho-mqtt-c paho-mqtt-cpp
	$(CC) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CC) $(CFLAGS) -o mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)

paho-mqtt-c:

paho-mqtt-cpp:

# Clean target
clean:
	rm -f mqtt_subscriber *.o