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

# define build commands
define MQTT_SUBSCRIBER_BUILD_CMDS
	$(MAKE)
endef

# define install commands
define MQTT_SUBSCRIBER_INSTALL_TARGET_CMDS
	$(MAKE) install INSTALL_CMD=$(INSTALL) BUILD_DIR=$(@D) TARGET_DIR=$(TARGET_DIR)/usr
endef

$(eval $(generic-package))