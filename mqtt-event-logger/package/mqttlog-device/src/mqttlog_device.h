// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_DEVICE_H
#define MQTTLOG_DEVICE_H

#include <linux/fs.h>           // struct file_operations
#include <linux/cdev.h>         // struct cdev

// struct containing all device-specific structs for /dev/mqttlog
struct mqttlog_dev {
    dev_t dev_num;              // major/minor number
    struct cdev cdev;           // actual character device, I/O interface for kernel
    struct class *class;        // custom device class /sys/class/mqttlog
    struct device *device;      // one instance of the driver
};

// init/exit functions (when module is loaded/unloaded)
int  mqttlog_device_init(void);
void mqttlog_device_exit(void);
int  mqttlog_device_cleanup(const bool init, const long ret);

#endif // MQTTLOG_DEVICE_H