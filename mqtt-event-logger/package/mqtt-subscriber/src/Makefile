# Assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# Linker and compile options
LDFLAGS ?= #-pthread -lrt
CFLAGS  ?= -g -Wall -Werror

# Folder definitions
OUTPUT_PATH ?= ../build

# Default target
all: mqtt-subscriber

folders:
	mkdir -p $(OUTPUT_PATH)
	mkdir -p $(OUTPUT_PATH)/bin
	mkdir -p $(OUTPUT_PATH)/lib

mqtt-subscriber: folders paho-mqtt-c paho-mqtt-cpp
	$(CC) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CC) $(CFLAGS) -o $(OUTPUT_PATH)/bin/mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)

paho-mqtt-c: folders

paho-mqtt-cpp: folders paho-mqtt-c

# Clean target
clean:
	rm -f *.o
	rm -rf $(OUTPUT_PATH)