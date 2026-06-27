##############################################################
#
# MQTT SUBSCRIBER
#
##############################################################

# add local directory as source
MQTT_SUBSCRIBER_VERSION = v1.0.0
MQTT_SUBSCRIBER_SITE = $(BR2_EXTERNAL_MQTT_EVENT_LOGGER_PATH)/package/mqtt-subscriber/src
MQTT_SUBSCRIBER_SITE_METHOD = local

# add openssl as dependency (required for paho mqtt library)
MQTT_SUBSCRIBER_DEPENDENCIES = openssl libopenssl
MQTT_SUBSCRIBER_CMAKE_BUILD_OPTIONS = " \
	-DOPENSSL_LIB_SEARCH_PATH=$(TARGET_DIR)/usr/lib \
    -DOPENSSL_INC_SEARCH_PATH=$(TARGET_DIR)/usr/include/openssl;$(TARGET_DIR)/usr/include \
	-DCMAKE_TOOLCHAIN_FILE=$(@D)/paho.mqtt.c/cmake/toolchain.linux-arm11.cmake"

# define build commands
define MQTT_SUBSCRIBER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) clean
	$(TARGET_MAKE_ENV) $(MAKE) BUILD_DIR=. CMAKE_BUILD_OPTIONS="$(MQTT_SUBSCRIBER_CMAKE_BUILD_OPTIONS)"
endef

# define install commands
define MQTT_SUBSCRIBER_INSTALL_TARGET_CMDS
	$(MAKE) install INSTALL_CMD=$(INSTALL) BUILD_DIR=. TARGET_DIR=$(TARGET_DIR)/usr
endef

$(eval $(generic-package))