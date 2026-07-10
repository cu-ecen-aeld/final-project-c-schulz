// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_IOCTL_H
#define MQTTLOG_IOCTL_H

#include <linux/ioctl.h>
#include "mqttlog_types.h"

#define MQTTLOG_IOCTL_MAGIC 'M'     // magic seed

// struct for runtime statistics
struct mqttlog_stats {
    __u64 events_written;
    __u64 events_dropped;
    __u32 buffer_size;
    __u32 buffer_used;
};

// struct for reader configuration
struct mqttlog_topic_filter {
    char topic_filter[MQTTLOG_MAX_TOPIC_LEN];
};


// IOCTL commands

// write command to specify a reader-specific topic filter
#define MQTTLOG_IOCTL_SET_TOPIC_FILTER \
    _IOW(MQTTLOG_IOCTL_MAGIC, 0x01, struct mqttlog_topic_filter)

// command to reset the ringbuffer
#define MQTTLOG_IOCTL_RESET_RINGBUFFER \
    _IO (MQTTLOG_IOCTL_MAGIC, 0x02)

// read command to retreive statistics
#define MQTTLOG_IOCTL_GET_STATS \
    _IOR(MQTTLOG_IOCTL_MAGIC, 0x03, struct mqttlog_stats)


// actual IOCTL implementation
long mqttlog_ioctl(struct file *file, unsigned int cmd, unsigned long arg);
long mqttlog_ioctl_set_topic_filter(struct mqttlog_file *reader, void __user *arg);
long mqttlog_ioctl_reset_ringbuffer(struct mqttlog_file *reader);
long mqttlog_ioctl_get_stats       (struct mqttlog_file *reader, void __user *arg);

#endif // MQTTLOG_IOCTL_H