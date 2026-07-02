// SPDX-License-Identifier: GPL-2.0

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>

MODULE_DESCRIPTION("MQTT Character Driver");
MODULE_AUTHOR("Cornelia Schulz");
MODULE_VERSION("1.0.0");
MODULE_LICENSE("GPL");

static int __init mqtt_char_driver_init(void)
{
    pr_info("mqtt_char_driver: module loaded\n");
    return 0;
}

static void __exit mqtt_char_driver_exit(void)
{
    pr_info("mqtt_char_driver: module unloaded\n");
}

module_init(mqtt_char_driver_init);
module_exit(mqtt_char_driver_exit);