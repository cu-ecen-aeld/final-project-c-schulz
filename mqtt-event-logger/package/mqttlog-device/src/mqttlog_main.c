// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>       // MODULE_* macros
#include <linux/init.h>         // module_init(), module_exit()

#include "mqttlog_device.h"     // -> header containing struct and function decls


MODULE_DESCRIPTION("MQTT Event Logger");
MODULE_AUTHOR("Cornelia Schulz");
MODULE_VERSION("1.0.0");
MODULE_LICENSE("GPL");


// forward local functions to device functions
static int __init mqttlog_init(void)
{
    return mqttlog_device_init();
}

static void __exit mqttlog_exit(void)
{
    mqttlog_device_exit();
}


// setup load/unload hooks
module_init(mqttlog_init);
module_exit(mqttlog_exit);