##############################################################
#
# MQTT CHAR DRIVER
#
##############################################################

# add local directory as source
MQTTLOG_DEVICE_VERSION = v1.0.0
MQTTLOG_DEVICE_SITE = $(BR2_EXTERNAL_MQTT_EVENT_LOGGER_PATH)/package/mqttlog-device/src
MQTTLOG_DEVICE_SITE_METHOD = local

# setup start-stop script
ifeq ($(BR2_PACKAGE_MQTTLOG_DEVICE),y)
define MQTTLOG_DEVICE_INSTALL_INIT_SCRIPT
	$(INSTALL) -m 0755 $(@D)/mqttlog_start-stop $(TARGET_DIR)/etc/init.d/S98mqttlog
endef

MQTTLOG_DEVICE_POST_INSTALL_TARGET_HOOKS += MQTTLOG_DEVICE_INSTALL_INIT_SCRIPT
endif


# execute make to build package
$(eval $(kernel-module))
$(eval $(generic-package))