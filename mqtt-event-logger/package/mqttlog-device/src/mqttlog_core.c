// SPDX-License-Identifier: GPL-2.0

#include <linux/kernel.h>       // pr_info()
// #include <linux/uaccess.h>     // copy_to_user(), copy_from_user()

#include "mqttlog_core.h"


// open device
int mqttlog_open(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: open\n");
    return 0;
}

// close device
int mqttlog_release(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: close\n");
    return 0;
}

// write to device (e.g. echo "..." > /dev/mqttlog)
ssize_t mqttlog_write(struct file *file,
                             const char __user *buf,
                             size_t len,
                             loff_t *off)
{
    pr_info("mqttlog: received %zu bytes\n", len);
    return len;
}

// read from device (e.g. cat /dev/mqttlog)
ssize_t mqttlog_read(struct file *file,
                            char __user *buf,
                            size_t len,
                            loff_t *off)
{
    return 0;
}