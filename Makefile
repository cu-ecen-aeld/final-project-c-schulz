# Makefile for building the raspberry pi image
# - update-submodule: updates all existing git submodules
# - build-image: updates submodules, creates the buildroot config and builds the image
#                1) re-uses existing config in ./buildroot/.config or
#                2) re-uses config from base_external/configs or
#                3) creates new config from default config
# - save-defconfig: save current config from ./buildroot/.config to base_external/configs
# - all: build the buildroot image
# - clean: cleanup buildroot build


# external base for additional buildroot sources
EXTERNAL_REL_BUILDROOT=../base_external

# defconfig from buildroot directory used as prior for the raspberry pi build
RPI_DEFCONFIG=configs/raspberrypi0w_defconfig
# place to store the modified defconfig
MODIFIED_RPI_DEFCONFIG=base_external/configs/mqtt_rpi_defconfig

# defconfig from buildroot directory used for mqtt event logger builds
MQTT_DEFAULT_DEFCONFIG=$(RPI_DEFCONFIG)
MQTT_MODIFIED_DEFCONFIG=$(MODIFIED_RPI_DEFCONFIG)
MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT=../$(MQTT_MODIFIED_DEFCONFIG)


all: build-image

update-submodule:
	git submodule init
	git submodule sync
	git submodule update

build-image: update-submodule
ifeq (,$(wildcard ./buildroot/.config))
		@echo "MISSING BUILDROOT CONFIGURATION FILE"

ifneq (,$(wildcard $(MQTT_MODIFIED_DEFCONFIG)))
			@echo "USING ${MQTT_MODIFIED_DEFCONFIG}"
			$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT)
else
			@echo "Run 'make save-defconfig' to save this as the default configuration in ${MQTT_MODIFIED_DEFCONFIG}"
			@echo "Then add packages as needed to complete the installation, re-running 'make save-defconfig' as needed"
			$(MAKE) -C buildroot defconfig BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT) BR2_DEFCONFIG=$(MQTT_DEFAULT_DEFCONFIG)
endif
else
		@echo "USING EXISTING BUILDROOT CONFIG"
		@echo "To force update, delete .config or make changes using make menuconfig and build again."
		$(MAKE) -C buildroot BR2_EXTERNAL=$(EXTERNAL_REL_BUILDROOT)
endif

save-defconfig:
	mkdir -p ./base_external/configs/
	$(MAKE) -C buildroot savedefconfig BR2_DEFCONFIG=$(MQTT_MODIFIED_DEFCONFIG_REL_BUILDROOT)

ifneq (,$(wildcard buildroot/.config))
		@if ls buildroot/output/build/linux-*/.config >/dev/null 2>&1 && \
			grep -q "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE" buildroot/.config; then \
			echo "Saving linux defconfig"; \
			$(MAKE) -C buildroot linux-update-defconfig; \
		fi
endif

clean:
	$(MAKE) -C buildroot distclean