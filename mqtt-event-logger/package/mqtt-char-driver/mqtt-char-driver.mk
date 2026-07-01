##############################################################
#
# MQTT CHAR DRIVER
#
##############################################################

# add local directory as source
MQTT_CHAR_DRIVER_VERSION = v1.0.0
MQTT_CHAR_DRIVER_SITE = $(BR2_EXTERNAL_MQTT_EVENT_LOGGER_PATH)/package/mqtt-char-driver/src
MQTT_CHAR_DRIVER_SITE_METHOD = local

# execute make to build package
$(eval $(kernel-module))
$(eval $(generic-package))