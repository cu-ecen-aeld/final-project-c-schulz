# Makefile for building the raspberry pi image
# - update-submodule: updates all existing git submodules
# - build-image: updates submodules, creates the buildroot config and builds the image
#                1) re-uses existing config in ./buildroot/.config or
#                2) re-uses config from base-external/configs or
#                3) creates new config from default config
# - save-defconfig: save current config from ./buildroot/.config to base-external/configs
# - all: build the buildroot image
# - clean: cleanup buildroot build


# external base for additional buildroot sources
EXTERNAL_REL_BUILDROOT=../base-external
EXTERNAL_CONFIG_REL_BUILDROOT=$(EXTERNAL_REL_BUILDROOT)/configs

# defconfig from buildroot directory used as prior for the raspberry pi build
RPI_DEFCONFIG=configs/raspberrypi0w_defconfig
# place to store the modified defconfig
MODIFIED_RPI_DEFCONFIG=$(EXTERNAL_CONFIG_REL_BUILDROOT)/mqtt_rpi_defconfig
# place inside buildroot where the config needs to be stored before compiling
BUILDROOT_DIR=./buildroot
BUILDROOT_CONFIG=$(BUILDROOT_DIR)/.config

# defconfig from buildroot directory used for mqtt event logger builds
MQTT_DEFAULT_DEFCONFIG=$(RPI_DEFCONFIG)
MQTT_MODIFIED_DEFCONFIG=$(MODIFIED_RPI_DEFCONFIG)
MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT=../$(MQTT_MODIFIED_DEFCONFIG)

# wifi configuration
MQTT_WIFI_SSID=
MQTT_WIFI_PWD=

# target device for flashing (SD card)
MQTT_TARGET_DEVICE?=/dev/sde


all: build

submodule:
	git submodule init
	git submodule sync
	git submodule update

wifi: submodule
ifneq (,$(wildcard $(BUILDROOT_DIR)/$(MODIFIED_RPI_DEFCONFIG)))
ifeq (,$(MQTT_WIFI_SSID))
	@echo "WiFi SSID not configured. Try again with 'MQTT_WIFI_SSID=**** MQTT_WIFI_PWD=****'!"
	@exit 1
else ifeq (,$(MQTT_WIFI_PWD))
	@echo "WiFi password not configured. Try again with 'MQTT_WIFI_SSID=**** MQTT_WIFI_PWD=****'!"
	@exit 1
else
	sed -i "s/BR2_PACKAGE_RPI_WIFI_SSID=.*/BR2_PACKAGE_RPI_WIFI_SSID=\"$(MQTT_WIFI_SSID)\"/g" $(BUILDROOT_DIR)/$(MODIFIED_RPI_DEFCONFIG)
	sed -i "s/BR2_PACKAGE_RPI_WIFI_PWD=.*/BR2_PACKAGE_RPI_WIFI_PWD=\"$(MQTT_WIFI_PWD)\"/g"    $(BUILDROOT_DIR)/$(MODIFIED_RPI_DEFCONFIG)
endif
endif

config: submodule wifi
ifeq (,$(wildcard $(BUILDROOT_CONFIG)))
		@echo "MISSING BUILDROOT CONFIGURATION FILE"
ifneq (,$(wildcard $(MQTT_MODIFIED_DEFCONFIG)))
			@echo "USING ${MQTT_MODIFIED_DEFCONFIG}"
			$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT)
else
			@echo "USING ${MQTT_DEFAULT_DEFCONFIG}"
			@echo "Run 'make save-defconfig' to save this as the default configuration in ${MQTT_MODIFIED_DEFCONFIG}"
			@echo "Then add packages as needed to complete the installation, re-running 'make save-defconfig' as needed"
			$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MQTT_DEFAULT_DEFCONFIG)
endif
else
		@echo "USING EXISTING BUILDROOT CONFIG"
endif

build: submodule config
	@echo "To force update, delete .config or make changes using make menuconfig and build again."
	$(MAKE) -C buildroot BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT)

save-menuconfig:
	mkdir -p $(EXTERNAL_CONFIG_REL_BUILDROOT)
	$(MAKE) -C buildroot savedefconfig BR2_DEFCONFIG=$(MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT)
ifneq (,$(wildcard $(BUILDROOT_CONFIG)))
		@if ls buildroot/output/build/linux-*/.config >/dev/null 2>&1 && \
			grep -q "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE" ${BUILDROOT_CONFIG}; then \
			echo "Saving linux defconfig"; \
			$(MAKE) -C buildroot linux-update-defconfig; \
		fi
endif

menuconfig:
	$(MAKE) -C buildroot menuconfig

install:
	@echo -n "You are about to flash device $(MQTT_TARGET_DEVICE). Are you sure? [y/N]" && read ans && if [ $${ans:-'N'} = 'y' ]; then \
		dd if=./buildroot/output/images/sdcard.img of=$(MQTT_TARGET_DEVICE) status=progress; \
	fi

clean-config:
	rm -f $(BUILDROOT_CONFIG)

clean: clean-config
	$(MAKE) -C buildroot distclean