##############################################################
#
# MQTT CHAR DRIVER
#
##############################################################

# add local directory as source
MQTT_CHAR_DRIVER_VERSION = v1.0.0
MQTT_CHAR_DRIVER_SITE = $(BR2_EXTERNAL_MQTT_EVENT_LOGGER_PATH)/package/mqtt-char-driver/src
MQTT_CHAR_DRIVER_SITE_METHOD = local

# setup start-stop script
ifeq ($(BR2_PACKAGE_MQTT_CHAR_DRIVER),y)
define MQTT_CHAR_DRIVER_INSTALL_INIT_SCRIPT
	$(INSTALL) -m 0755 $(@D)/mqtt_char_driver_start-stop $(TARGET_DIR)/etc/init.d/S98mqtt-char-driver
endef

MQTT_CHAR_DRIVER_POST_INSTALL_TARGET_HOOKS += MQTT_CHAR_DRIVER_INSTALL_INIT_SCRIPT
endif


# execute make to build package
$(eval $(kernel-module))
$(eval $(generic-package))