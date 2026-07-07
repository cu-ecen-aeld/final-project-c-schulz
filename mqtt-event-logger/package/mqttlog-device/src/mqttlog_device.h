// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_DEVICE_H
#define MQTTLOG_DEVICE_H

#include "mqttlog_types.h"

// init/exit functions (when module is loaded/unloaded)
int  mqttlog_device_init(void);
void mqttlog_device_exit(void);
int  mqttlog_device_cleanup(const bool init, const long ret);

#endif // MQTTLOG_DEVICE_H