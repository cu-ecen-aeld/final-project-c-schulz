# assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# linker and compile options
LDFLAGS ?= -lpaho-mqttpp3 -lpaho-mqtt3as -Wl,-rpath,"\$$ORIGIN/../lib"
CFLAGS  ?= -g -Wall -Werror -I$(BUILDDIR)/include -L$(BUILDDIR)/lib

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
	$(CXX) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CXX) $(CFLAGS) -o $(BUILDDIR)/bin/mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)
	@echo "Built $@."


# build paho.mqtt.c library
paho-mqtt-c: submodules folders
ifeq (,$(wildcard $(BUILDDIR)/.paho-mqtt-c))
	@echo "Building paho-mqtt-c..."
	cmake -B paho.mqtt.c/build \
	      -S paho.mqtt.c \
	      -DPAHO_WITH_SSL=ON \
	      -DPAHO_ENABLE_TESTING=OFF \
	      -DPAHO_ENABLE_CPACK=OFF \
	      -DCMAKE_INSTALL_PREFIX=$(BUILDDIR)
	cmake --build paho.mqtt.c/build \
	      --target install/strip
	touch ${BUILDDIR}/.paho-mqtt-c
	@echo "Built paho-mqtt-c."
else
	@echo "Already built paho-mqtt-c. Nothing to do here."
endif
#
# plain make:
#
#	$(MAKE) -C paho.mqtt.c PAHO_BUILD_SHARED=true PAHO_WITH_SSL=true PAHO_ENABLE_TESTING=false PAHO_ENABLE_CPACK=false
#	$(MAKE) -C paho.mqtt.c uninstall prefix=$(BUILDDIR) LDCONFIG=echo
#	$(MAKE) -C paho.mqtt.c install prefix=$(BUILDDIR) LDCONFIG=echo

clean-paho-mqtt-c:
	rm -rf paho.mqtt.c/build
	rm -f $(BUILDDIR)/.paho-mqtt-c


# build paho.mqtt.cpp library
paho-mqtt-cpp: paho-mqtt-c submodules
ifeq (,$(wildcard $(BUILDDIR)/.paho-mqtt-cpp))
	@echo "Building paho-mqtt-cpp..."
	cmake -B paho.mqtt.cpp/build \
	      -S paho.mqtt.cpp \
	      -DPAHO_WITH_SSL=ON \
	      -DCMAKE_INSTALL_PREFIX=$(BUILDDIR) \
	      -DCMAKE_INSTALL_RPATH="\$$ORIGIN/../lib"
	cmake --build paho.mqtt.cpp/build \
	      --target install/strip
	touch ${BUILDDIR}/.paho-mqtt-cpp
	@echo "Built paho-mqtt-cpp."
else
	@echo "Already built paho-mqtt-cpp. Nothing to do here."
endif

clean-paho-mqtt-cpp:
	rm -rf paho.mqtt.cpp/build
	rm -f $(BUILDDIR)/.paho-mqtt-cpp


# cleanup build
clean: clean-paho-mqtt-c clean-paho-mqtt-cpp
	rm -f *.o
	rm -rf $(BUILDDIR)