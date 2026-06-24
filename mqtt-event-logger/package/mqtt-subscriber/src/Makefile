# assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# linker and compile options
LDFLAGS ?= #-pthread -lrt
CFLAGS  ?= -g -Wall -Werror

# folder definitions
BUILDDIR = ../build
#BUILDDIR=$(shell realpath ../build)

# default target
all: mqtt-subscriber

# create build folders
folders:
	mkdir -p $(BUILDDIR)
	mkdir -p $(BUILDDIR)/bin
	mkdir -p $(BUILDDIR)/lib

# update submodules
submodules:
	git submodule init .
	git submodule sync .
	git submodule update .


# build mqtt subscriber
mqtt-subscriber: folders paho-mqtt-c paho-mqtt-cpp
	@echo "Building $@..."
	$(CC) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CC) $(CFLAGS) -o $(BUILDDIR)/bin/mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)
	@echo "Built $@."


# build paho.mqtt.c library
paho-mqtt-c: submodules folders
ifeq (,$(wildcard $(BUILDDIR)/.$@))
	@echo "Building $@..."
	cmake -B paho.mqtt.c/build \
	      -S paho.mqtt.c \
	      -DPAHO_WITH_SSL=ON \
	      -DPAHO_ENABLE_TESTING=OFF \
	      -DPAHO_ENABLE_CPACK=OFF \
	      -DCMAKE_INSTALL_PREFIX=$(BUILDDIR)
	cmake --build paho.mqtt.c/build \
	      --target install/strip
	touch ${BUILDDIR}/.$@
	@echo "Built $@."
else
	@echo "Already built $@. Nothing to do here."
endif
#
# plain make:
#
#	$(MAKE) -C paho.mqtt.c PAHO_BUILD_SHARED=true PAHO_WITH_SSL=true PAHO_ENABLE_TESTING=false PAHO_ENABLE_CPACK=false
#	$(MAKE) -C paho.mqtt.c uninstall prefix=$(BUILDDIR) LDCONFIG=echo
#	$(MAKE) -C paho.mqtt.c install prefix=$(BUILDDIR) LDCONFIG=echo

clean-paho-mqtt-c:
	rm -rf paho.mqtt.c/build


# build paho.mqtt.cpp library
paho-mqtt-cpp: paho-mqtt-c submodules
ifeq (,$(wildcard $(BUILDDIR)/.$@))
	@echo "Building $@..."
	cmake -B paho.mqtt.cpp/build \
	      -S paho.mqtt.cpp \
	      -DPAHO_WITH_SSL=ON \
	      -DCMAKE_INSTALL_PREFIX=$(BUILDDIR)
	cmake --build paho.mqtt.cpp/build \
	      --target install/strip
	touch ${BUILDDIR}/.$@
	@echo "Built $@."
else
	@echo "Already built $@. Nothing to do here."
endif

clean-paho-mqtt-cpp:
	rm -rf paho.mqtt.cpp/build


# cleanup build
clean: clean-paho-mqtt-c clean-paho-mqtt-cpp
	rm -f *.o
	rm -rf $(BUILDDIR)