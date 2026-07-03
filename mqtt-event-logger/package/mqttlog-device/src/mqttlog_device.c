// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>       // MODULE_* macros
#include <linux/init.h>         // module_init(), module_exit()
#include <linux/device.h>       // class_create(), device_create()
#include <linux/kernel.h>       // pr_info()

#include "mqttlog_device.h"     // -> header containing device-level struct and function decls
#include "mqttlog_core.h"       // -> header containing read/write function decls
#define DEVICE_NAME "mqttlog"   // -> module creates /dev/mqttlog device


// struct containing all device-specific structs for /dev/mqttlog
struct mqttlog_dev mqttlog;

// file operations struct, contains the provided functions
const struct file_operations mqttlog_fops = {
    .owner   = THIS_MODULE,
    .open    = mqttlog_open,
    .release = mqttlog_release,
    .read    = mqttlog_read,
    .write   = mqttlog_write,
};


// init module (when module is loaded)
int mqttlog_device_init(void)
{
    int ret;

    // reserve a free major/minor number, returned via dev_num
    ret = alloc_chrdev_region(&mqttlog.dev_num, 0, 1, DEVICE_NAME);
    if (ret < 0)
        return ret;

    // initialize the character device, assign custom file operations
    cdev_init(&mqttlog.cdev, &mqttlog_fops);

    // register the device in the kernel
    ret = cdev_add(&mqttlog.cdev, mqttlog.dev_num, 1);
    if (ret < 0)
        return ret;

    // create custom class, available as /sys/class/mqttlog
    mqttlog.class = class_create(DEVICE_NAME);
    if (IS_ERR(mqttlog.class))
        return PTR_ERR(mqttlog.class);

    // create the actual character device
    mqttlog.device = device_create(mqttlog.class, NULL, mqttlog.dev_num, NULL, DEVICE_NAME);
    if (IS_ERR(mqttlog.device))
        return PTR_ERR(mqttlog.device);

    pr_info("mqttlog_device: device created -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module loaded\n");

    return 0;
}

// exit module (when module is unloaded)
void mqttlog_device_exit(void)
{
    // delete device /dev/mqttlog
    device_destroy(mqttlog.class, mqttlog.dev_num);

    // delete device class /sys/class/mqttlog
    class_destroy(mqttlog.class);

    // unregister character device from kernel
    cdev_del(&mqttlog.cdev);

    // release major/minor number
    unregister_chrdev_region(mqttlog.dev_num, 1);

    pr_info("mqttlog_device: device destroyed -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module unloaded\n");
}