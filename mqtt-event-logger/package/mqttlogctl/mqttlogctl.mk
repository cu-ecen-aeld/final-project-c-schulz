##############################################################
#
# MQTTLOGCTL
#
##############################################################

# add local directory as source
MQTTLOGCTL_VERSION = v1.0.0
MQTTLOGCTL_SITE = $(BR2_EXTERNAL_MQTT_EVENT_LOGGER_PATH)/package/mqttlogctl/src
MQTTLOGCTL_SITE_METHOD = local


# execute cargo to build package
$(eval $(cargo-package))