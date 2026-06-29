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
MQTT_SUBSCRIBER_DEPENDENCIES = openssl

# setup start-stop script and configure mqtt hostname
ifeq ($(BR2_PACKAGE_MQTT_SUBSCRIBER),y)
define MQTT_SUBSCRIBER_CONFIGURE_MQTT_SUBSCRIBER
	$(INSTALL) -m 0755 $(@D)/mqtt_subscriber_start-stop                $(TARGET_DIR)/etc/init.d/S99mqtt_subscriber
	$(SED) "s|%HOST%|\"$(BR2_PACKAGE_MQTT_SUBSCRIBER_MQTT_HOST)\"|g"   $(TARGET_DIR)/etc/init.d/S99mqtt_subscriber
	$(SED) "s|%TOPIC%|\"$(BR2_PACKAGE_MQTT_SUBSCRIBER_MQTT_TOPIC)\"|g" $(TARGET_DIR)/etc/init.d/S99mqtt_subscriber
endef

MQTT_SUBSCRIBER_POST_INSTALL_TARGET_HOOKS += MQTT_SUBSCRIBER_CONFIGURE_MQTT_SUBSCRIBER
endif


$(eval $(cmake-package))