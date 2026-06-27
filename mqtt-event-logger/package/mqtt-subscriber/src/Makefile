# assume "CROSS_COMPILE" set by buildroot
CROSS_COMPILE ?=
CC ?= $(CROSS_COMPILE)gcc

# folder definitions
BUILD_DIR = ../build
#BUILD_DIR=$(shell realpath ../build)
TARGET_DIR = ../install
INSTALL_CMD = install
CMAKE_BUILD_OPTIONS =


# linker and compile options
LDFLAGS ?= -lpaho-mqttpp3 -lpaho-mqtt3as -Wl,-rpath,"\$$ORIGIN/../lib"
CFLAGS  ?= -g -Wall -Werror -I$(BUILD_DIR)/include -L$(BUILD_DIR)/lib

# default target
all: build

# print variables
echo:
	@echo "Build directory:   " $(BUILD_DIR)
	@echo "Install directory: " $(TARGET_DIR)
	@echo "CMake options:     " $(CMAKE_BUILD_OPTIONS)
	@echo "Install command:   " $(INSTALL_CMD)

# create build folders
build-folders:
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/bin
	mkdir -p $(BUILD_DIR)/lib

# update submodules
submodules:
	git submodule init .
	git submodule sync .
	git submodule update .

##############################################################

# build mqtt subscriber
build: build-folders paho-mqtt-c paho-mqtt-cpp
	@echo "Building mqtt-subscriber into '$(BUILD_DIR)'..."
	$(CXX) $(CFLAGS) -c -o mqtt_subscriber.o mqtt_subscriber.cpp $(LDFLAGS)
	$(CXX) $(CFLAGS) -o $(BUILD_DIR)/bin/mqtt_subscriber mqtt_subscriber.o $(LDFLAGS)
	@echo "Built mqtt-subscriber."


# install mqtt subscriber
install:
	@echo "Installing mqtt-subscriber to '$(TARGET_DIR)'..."
	$(INSTALL_CMD) -d -m 0755 $(TARGET_DIR)/bin/
	$(INSTALL_CMD) -m 0755 $(BUILD_DIR)/bin/mqtt_subscriber $(TARGET_DIR)/bin/
	$(INSTALL_CMD) -d -m 0755 $(TARGET_DIR)/lib/
	$(INSTALL_CMD) -m 0755 $(BUILD_DIR)/lib/libpaho-mqttpp3.so.1.6.0 $(TARGET_DIR)/lib/
	ln -fsvr $(TARGET_DIR)/lib/libpaho-mqttpp3.so.1.6.0 $(TARGET_DIR)/lib/libpaho-mqttpp3.so.1
	ln -fsvr $(TARGET_DIR)/lib/libpaho-mqttpp3.so.1 $(TARGET_DIR)/lib/libpaho-mqttpp3.so
	$(INSTALL_CMD) -m 0755 $(BUILD_DIR)/lib/libpaho-mqtt3as.so.1.3.16 $(TARGET_DIR)/lib/
	ln -fsvr $(TARGET_DIR)/lib/libpaho-mqtt3as.so.1.3.16 $(TARGET_DIR)/lib/libpaho-mqtt3as.so.1
	ln -fsvr $(TARGET_DIR)/lib/libpaho-mqtt3as.so.1 $(TARGET_DIR)/lib/libpaho-mqtt3as.so
	@echo "Installed mqtt-subscriber."

##############################################################

# build paho.mqtt.c library
paho-mqtt-c: submodules build-folders
ifeq (,$(wildcard $(BUILD_DIR)/.paho-mqtt-c))
	@echo "Building paho-mqtt-c..."
	cmake -B paho.mqtt.c/build \
	      -S paho.mqtt.c \
	      -DPAHO_WITH_SSL=ON \
	      -DPAHO_ENABLE_TESTING=OFF \
	      -DPAHO_ENABLE_CPACK=OFF \
	      -DCMAKE_INSTALL_PREFIX=$(BUILD_DIR)
	cmake --build paho.mqtt.c/build \
	      --target install/strip
	touch ${BUILD_DIR}/.paho-mqtt-c
	@echo "Built paho-mqtt-c."
else
	@echo "Already built paho-mqtt-c. Nothing to do here."
endif
#
# plain make:
#
#	$(MAKE) -C paho.mqtt.c PAHO_BUILD_SHARED=true PAHO_WITH_SSL=true PAHO_ENABLE_TESTING=false PAHO_ENABLE_CPACK=false
#	$(MAKE) -C paho.mqtt.c uninstall prefix=$(BUILD_DIR) LDCONFIG=echo
#	$(MAKE) -C paho.mqtt.c install prefix=$(BUILD_DIR) LDCONFIG=echo

clean-paho-mqtt-c:
	rm -rf paho.mqtt.c/build
	rm -f $(BUILD_DIR)/.paho-mqtt-c


##############################################################

# build paho.mqtt.cpp library
paho-mqtt-cpp: paho-mqtt-c submodules
ifeq (,$(wildcard $(BUILD_DIR)/.paho-mqtt-cpp))
	@echo "Building paho-mqtt-cpp..."
	cmake -B paho.mqtt.cpp/build \
	      -S paho.mqtt.cpp \
	      -DPAHO_WITH_SSL=ON \
	      -DCMAKE_INSTALL_PREFIX=$(BUILD_DIR) \
	      -DCMAKE_INSTALL_RPATH="\$$ORIGIN/../lib"
	cmake --build paho.mqtt.cpp/build \
	      --target install/strip
	touch ${BUILD_DIR}/.paho-mqtt-cpp
	@echo "Built paho-mqtt-cpp."
else
	@echo "Already built paho-mqtt-cpp. Nothing to do here."
endif

clean-paho-mqtt-cpp:
	rm -rf paho.mqtt.cpp/build
	rm -f $(BUILD_DIR)/.paho-mqtt-cpp


##############################################################

# cleanup build
clean: clean-paho-mqtt-c clean-paho-mqtt-cpp
	rm -f *.o

# also cleanup build and install dir
clean-all: clean
	rm -rf $(BUILD_DIR)
	rm -rf $(TARGET_DIR)