# Makefile for building the raspberry pi image
# - update-submodule: updates all existing git submodules
# - build-image: updates submodules, creates the buildroot config and builds the image
#                1) re-uses existing config in ./buildroot/.config or
#                2) re-uses config from mqtt-event-logger/configs or
#                3) creates new config from default config
# - save-defconfig: save current config from ./buildroot/.config to mqtt-event-logger/configs
# - all: build the buildroot image
# - clean: cleanup buildroot build


# external base for additional buildroot sources
EXTERNAL_DIR=mqtt-event-logger
EXTERNAL_REL_BUILDROOT=../$(EXTERNAL_DIR):../buildroot-externals

# defconfig from buildroot directory used as prior for the raspberry pi build
RPI_DEFCONFIG=configs/raspberrypi0w_defconfig
# place to store the modified defconfig
MODIFIED_RPI_DEFCONFIG=$(EXTERNAL_DIR)/configs/mqtt_rpi_defconfig
MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT=../$(MODIFIED_RPI_DEFCONFIG)

# place inside buildroot where the config needs to be stored before compiling
BUILDROOT_DIR=buildroot
BUILDROOT_CONFIG=$(BUILDROOT_DIR)/.config

# variables for wifi configuration
WIFI_SSID=
WIFI_PWD=

# target device for flashing (SD card)
TARGET_DEVICE?=/dev/sde


all: build

submodule:
	git submodule init
	git submodule sync
	git submodule update

wifi:
ifneq (,$(wildcard $(MODIFIED_RPI_DEFCONFIG)))
ifeq (,$(WIFI_SSID))
	@echo "WiFi SSID not configured. Try again with 'WIFI_SSID=**** WIFI_PWD=****'!"
	@exit 1
else ifeq (,$(WIFI_PWD))
	@echo "WiFi password not configured. Try again with 'WIFI_SSID=**** WIFI_PWD=****'!"
	@exit 1
else
	sed -i "s/BR2_PACKAGE_RPI_WIFI_SSID=.*/BR2_PACKAGE_RPI_WIFI_SSID=\"$(WIFI_SSID)\"/g" $(MODIFIED_RPI_DEFCONFIG)
	sed -i "s/BR2_PACKAGE_RPI_WIFI_PWD=.*/BR2_PACKAGE_RPI_WIFI_PWD=\"$(WIFI_PWD)\"/g"    $(MODIFIED_RPI_DEFCONFIG)
endif
endif

reset-wifi:
ifneq (,$(wildcard $(MODIFIED_RPI_DEFCONFIG)))
	sed -i "s/BR2_PACKAGE_RPI_WIFI_SSID=.*/BR2_PACKAGE_RPI_WIFI_SSID=\"****\"/g" $(MODIFIED_RPI_DEFCONFIG)
	sed -i "s/BR2_PACKAGE_RPI_WIFI_PWD=.*/BR2_PACKAGE_RPI_WIFI_PWD=\"****\"/g"   $(MODIFIED_RPI_DEFCONFIG)
endif

config:
ifneq (,$(wildcard $(MODIFIED_RPI_DEFCONFIG)))
	@echo "USING ${MODIFIED_RPI_DEFCONFIG}"
	$(MAKE) wifi
	$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT)
	$(MAKE) reset-wifi
else
	@echo "USING ${RPI_DEFCONFIG}"
	@echo "Run 'make save-defconfig' to save this as the default configuration in ${MODIFIED_RPI_DEFCONFIG}"
	@echo "Then add packages as needed to complete the installation, re-running 'make save-defconfig' as needed"
	$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(RPI_DEFCONFIG)
endif

build: submodule
ifeq (,$(wildcard $(BUILDROOT_CONFIG)))
	@echo "MISSING BUILDROOT CONFIGURATION FILE"
	$(MAKE) config
else
	@echo "USING EXISTING BUILDROOT CONFIG"
endif
	@echo "To force update, delete .config or make changes using make menuconfig and build again."
	$(MAKE) -C buildroot BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT)

save-menuconfig:
	mkdir -p $(basename $(MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT))
	$(MAKE) -C buildroot savedefconfig BR2_DEFCONFIG=$(MODIFIED_RPI_DEFCONFIG_REL_BUILDROOT)
	$(MAKE) reset-wifi
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
	@echo -n "You are about to flash device $(TARGET_DEVICE). Are you sure? [y/N]" && read ans && if [ $${ans:-'N'} = 'y' ]; then \
		dd if=./buildroot/output/images/sdcard.img of=$(TARGET_DEVICE) status=progress; \
	fi

clean-config:
	rm -f $(BUILDROOT_CONFIG)

clean: clean-config
	$(MAKE) -C buildroot distclean