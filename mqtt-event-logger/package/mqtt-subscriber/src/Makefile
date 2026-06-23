# Assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# Linker and compile options
LDFLAGS ?= #-pthread -lrt
CFLAGS  ?= -g -Wall -Werror

# Folder definitions
BUILDDIR = $(shell realpath ../build)

# Default target
all: mqtt-subscriber

folders:
	mkdir -p $(BUILDDIR)
	mkdir -p $(BUILDDIR)/bin
	mkdir -p $(BUILDDIR)/lib

submodules:
	git submodule init .
	git submodule sync .
	git submodule update .


mqtt-subscriber: folders paho-mqtt-c paho-mqtt-cpp
	$(CC) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CC) $(CFLAGS) -o $(BUILDDIR)/bin/mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)


paho-mqtt-c: submodules folders
	$(MAKE) -C paho.mqtt.c PAHO_BUILD_SHARED=true PAHO_WITH_SSL=true PAHO_ENABLE_TESTING=false PAHO_ENABLE_CPACK=false
	$(MAKE) -C paho.mqtt.c uninstall prefix=$(BUILDDIR) LDCONFIG=echo
	$(MAKE) -C paho.mqtt.c install prefix=$(BUILDDIR) LDCONFIG=echo

clean-paho-mqtt-c:
	$(MAKE) -C paho.mqtt.c clean


paho-mqtt-cpp: paho-mqtt-c submodules

clean-paho-mqtt-cpp:
	$(MAKE) -C paho.mqtt.cpp clean


# Clean target
clean: clean-paho-mqtt-c #clean-paho-mqtt-cpp
	rm -f *.o
	rm -rf $(BUILDDIR)