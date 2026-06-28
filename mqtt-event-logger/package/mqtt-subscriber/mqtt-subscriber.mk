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

$(eval $(cmake-package))
