// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_CORE_H
#define MQTTLOG_CORE_H

#include "mqttlog_types.h"

// function definitions
void    mqttlog_init   (struct mqttlog_dev *mqttlog);
int     mqttlog_open   (struct inode *inode, struct file *file);
int     mqttlog_release(struct inode *inode, struct file *file);
ssize_t mqttlog_write  (struct file *file, const char __user *buf, size_t len, loff_t *off);
ssize_t mqttlog_read   (struct file *file,       char __user *buf, size_t len, loff_t *off);

#endif // MQTTLOG_CORE_H