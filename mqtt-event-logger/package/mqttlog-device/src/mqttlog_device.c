// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>           // MODULE_* macros
#include <linux/init.h>             // module_init(), module_exit()
#include <linux/device.h>           // class_create(), device_create()
#include <linux/kernel.h>           // pr_info()

#include "mqttlog_device.h"         // -> header containing device-level function decls
#include "mqttlog_core.h"           // -> header containing read/write function decls
#include "mqttlog_ioctl.h"          // -> header containing ioctl function decls

#define DEVICE_NAME "mqttlog"       // -> module creates /dev/mqttlog device


// struct containing all device-specific structs for /dev/mqttlog
struct mqttlog_dev mqttlog;

// file operations struct, contains the provided functions
const struct file_operations mqttlog_fops = {
    .owner          = THIS_MODULE,
    .open           = mqttlog_open,
    .release        = mqttlog_release,
    .read           = mqttlog_read,
    .write          = mqttlog_write,
    .poll           = mqttlog_poll,
    .unlocked_ioctl = mqttlog_ioctl,
    .llseek         = noop_llseek,  // don't support seek (e.g. tail)
};


// init module (when module is loaded)
int mqttlog_device_init(void)
{
    long ret;

    // initialize mqttlog struct
    memset(&mqttlog,0,sizeof(struct mqttlog_dev));
    mqttlog_init(&mqttlog);         // implemented in mqttlog_core.c

    // reserve a free major/minor number, returned via dev_num
    ret = alloc_chrdev_region(&mqttlog.dev_num, 0, 1, DEVICE_NAME);
    if (ret < 0)
        return mqttlog_device_cleanup(true, ret);

    // initialize the character device, assign custom file operations
    cdev_init(&mqttlog.cdev, &mqttlog_fops);

    // register the device in the kernel
    ret = cdev_add(&mqttlog.cdev, mqttlog.dev_num, 1);
    if (ret < 0)
        return mqttlog_device_cleanup(true, ret);

    // create custom class, available as /sys/class/mqttlog
    mqttlog.class = class_create(DEVICE_NAME);
    if (IS_ERR(mqttlog.class))
        return mqttlog_device_cleanup(true, PTR_ERR(mqttlog.class));

    // create the actual character device
    mqttlog.device = device_create(mqttlog.class, NULL, mqttlog.dev_num, NULL, DEVICE_NAME);
    if (IS_ERR(mqttlog.device))
        return mqttlog_device_cleanup(true, PTR_ERR(mqttlog.device));

    pr_info("mqttlog_device: device created -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module loaded\n");

    return 0;
}

// exit module (when module is unloaded)
void mqttlog_device_exit(void)
{
    // invoke cleanup function
    mqttlog_device_cleanup(false, 0);

    pr_info("mqttlog_device: device destroyed -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module unloaded\n");
}

int mqttlog_device_cleanup(const bool init, const long ret)
{
    // switch between error handling in initialization and regular exit
    if (init) {
        if (IS_ERR(mqttlog.class)) {
            pr_err("mqttlog_device: error creating class -- %ld\n", ret);
            goto cleanup_cdev;
        }

        if (IS_ERR(mqttlog.device)) {
            pr_err("mqttlog_device: error creating device -- %ld\n", ret);
            goto cleanup_class;
        }

        if (ret) {
            pr_err("mqttlog_device: error initializing -- %ld\n", ret);
            goto cleanup_chrdev;
        }
    }

    // delete device /dev/mqttlog
    device_destroy(mqttlog.class, mqttlog.dev_num);

cleanup_class:
    // delete device class /sys/class/mqttlog
    class_destroy(mqttlog.class);

cleanup_cdev:
    // unregister character device from kernel
    cdev_del(&mqttlog.cdev);

cleanup_chrdev:
    // release major/minor number
    unregister_chrdev_region(mqttlog.dev_num, 1);

    pr_info("mqttlog_device: cleaned up device\n");
    return ret;
}