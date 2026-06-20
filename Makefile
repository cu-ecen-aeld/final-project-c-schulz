# Makefile for building the raspberry pi image
# - update-submodule: updates all existing git submodules
# - build-image: updates submodules, creates the buildroot config and builds the image
#                1) re-uses existing config in ./buildroot/.config or
#                2) re-uses config from mqtt-event-logger/configs or
#                3) creates new config from default config
# - save-defconfig: save current config from ./buildroot/.config to mqtt-event-logger/configs
# - all: build the buildroot image
# - clean: cleanup buildroot build


# place inside buildroot where the config needs to be stored before compiling
BUILDROOT_DIR=buildroot
BUILDROOT_CONFIG=$(BUILDROOT_DIR)/.config

# external base for additional buildroot sources
EXTERNAL_DIR=mqtt-event-logger
EXTERNAL_REL_BUILDROOT=../$(EXTERNAL_DIR):../buildroot-externals

# config file to store the current build config (rpi or qemu)
DEFCONFIG_CONFIG=.config


###
# parameters for raspberry pi build
QEMU_BUILD=false

# defconfig from buildroot directory used as prior for the raspberry pi build
RPI_DEFCONFIG=configs/raspberrypi0w_defconfig
# place to store the modified defconfig
MODIFIED_RPI_DEFCONFIG=$(EXTERNAL_DIR)/configs/mqtt_rpi_defconfig
MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT=../$(MODIFIED_RPI_DEFCONFIG)

# variables for wifi configuration
WIFI_SSID=
WIFI_PWD=

# target device for flashing (SD card)
TARGET_DEVICE?=/dev/sde


###
# parameters for qemu build
QEMU_DEFCONFIG=configs/qemu_arm_versatile_defconfig
MODIFIED_QEMU_DEFCONFIG=$(EXTERNAL_DIR)/configs/mqtt_qemu_defconfig
MODIFIED_QEMU_DEFCONFIG_REL_BUILDROOT=../$(MODIFIED_QEMU_DEFCONFIG)


ifeq (false,$(QEMU_BUILD))
	DEFCONFIG=$(RPI_DEFCONFIG)
	MODIFIED_DEFCONFIG=$(MODIFIED_RPI_DEFCONFIG)
	MODIFIED_DEFCONFIG_REL_BUILDROOT=$(MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT)
else
	DEFCONFIG=$(QEMU_DEFCONFIG)
	MODIFIED_DEFCONFIG=$(MODIFIED_QEMU_DEFCONFIG)
	MODIFIED_DEFCONFIG_REL_BUILDROOT=$(MODIFIED_QEMU_DEFCONFIG_REL_BUILDROOT)
endif




###
# make targets

# by default, build image
all: build

# print main build parameters
echo:
	@echo QEMU_BUILD: $(QEMU_BUILD)
	@echo DEFCONFIG: $(MODIFIED_DEFCONFIG)

# update all submodules
submodule:
	git submodule init
	git submodule sync
	git submodule update

# configure wifi settings in custom config with ssid and password
wifi:
ifneq (true,$(QEMU_BUILD))
ifneq (,$(wildcard $(MODIFIED_DEFCONFIG)))
ifeq (,$(WIFI_SSID))
	@echo "WiFi SSID not configured. Try again with 'WIFI_SSID=**** WIFI_PWD=****'!"
	@exit 1
else ifeq (,$(WIFI_PWD))
	@echo "WiFi password not configured. Try again with 'WIFI_SSID=**** WIFI_PWD=****'!"
	@exit 1
else
	sed -i "s/BR2_PACKAGE_RPI_WIFI_SSID=.*/BR2_PACKAGE_RPI_WIFI_SSID=\"$(WIFI_SSID)\"/g" $(MODIFIED_DEFCONFIG)
	sed -i "s/BR2_PACKAGE_RPI_WIFI_PWD=.*/BR2_PACKAGE_RPI_WIFI_PWD=\"$(WIFI_PWD)\"/g"    $(MODIFIED_DEFCONFIG)
endif
endif
endif

# reset wifi settings in custom config (to not accidentally push them on github)
reset-wifi:
ifneq (true,$(QEMU_BUILD))
ifneq (,$(wildcard $(MODIFIED_DEFCONFIG)))
	sed -i "s/BR2_PACKAGE_RPI_WIFI_SSID=.*/BR2_PACKAGE_RPI_WIFI_SSID=\"****\"/g" $(MODIFIED_DEFCONFIG)
	sed -i "s/BR2_PACKAGE_RPI_WIFI_PWD=.*/BR2_PACKAGE_RPI_WIFI_PWD=\"****\"/g"   $(MODIFIED_DEFCONFIG)
endif
endif

# configure buildroot build with saved config; configure wifi settings for rpi build
config: submodule
ifneq (,$(wildcard $(MODIFIED_DEFCONFIG)))
	@echo "USING ${MODIFIED_DEFCONFIG}"
	$(MAKE) wifi
	$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MODIFIED_DEFCONFIG_REL_BUILDROOT)
	$(MAKE) reset-wifi
else
	@echo "USING ${DEFCONFIG}"
	@echo "Run 'make save-defconfig' to save this as the default configuration in ${MODIFIED_DEFCONFIG}"
	@echo "Then add packages as needed to complete the installation, re-running 'make save-defconfig' as needed"
	$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(DEFCONFIG)
endif

# compile buildroot image; when switching between qemu and rpi build, clean buildroot build first
build: submodule
ifneq (,$(wildcard $(DEFCONFIG_CONFIG)))
	@if [ ! "${DEFCONFIG}" = "$$(cat ${DEFCONFIG_CONFIG})" ]; then \
		echo "CONFIG CHANGED -> CLEAN BUILD"; \
		$(MAKE) clean; \
	fi
endif
	rm -f $(DEFCONFIG_CONFIG)
ifeq (,$(wildcard $(BUILDROOT_CONFIG)))
	@echo "MISSING BUILDROOT CONFIGURATION FILE"
	$(MAKE) config
else
	@echo "USING EXISTING BUILDROOT CONFIG"
endif
	@echo "To force update, delete buildroot/.config or make changes using make menuconfig and build again."
	echo "$(DEFCONFIG)" > $(DEFCONFIG_CONFIG)
	$(MAKE) -C buildroot BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT)

# save current buildroot configuration to ./mqtt-event-logger/configs/mqtt_*_defconfig
save-menuconfig:
	mkdir -p $(basename $(MODIFIED_DEFCONFIG_REL_BUILDROOT))
	$(MAKE) -C buildroot savedefconfig BR2_DEFCONFIG=$(MODIFIED_DEFCONFIG_REL_BUILDROOT)
	$(MAKE) reset-wifi
ifneq (,$(wildcard $(BUILDROOT_CONFIG)))
	@if ls buildroot/output/build/linux-*/.config >/dev/null 2>&1 && \
		grep -q "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE" ${BUILDROOT_CONFIG}; then \
		echo "Saving linux defconfig"; \
		$(MAKE) -C buildroot linux-update-defconfig; \
	fi
endif

# execute menuconfig in buildroot folder to customize build
menuconfig:
	$(MAKE) -C buildroot menuconfig

# flash buildroot image to device (default: /dev/sde, modify with TARGET_DEVICE=/dev/xy)
install:
ifneq (false,$(QEMU_BUILD))
	@echo -n "You are about to flash device $(TARGET_DEVICE). Are you sure? [y/N]" && read ans && if [ $${ans:-'N'} = 'y' ]; then \
		dd if=./buildroot/output/images/sdcard.img of=$(TARGET_DEVICE) status=progress; \
	fi
else
	@echo "TARGET UNDEFINED FOR QEMU_BUILD=true!"
endif

# delete buildroot configuration
clean-config: reset-wifi
	rm -f $(BUILDROOT_CONFIG)

# cleanup buildroot build
clean: clean-config
	$(MAKE) -C buildroot distclean