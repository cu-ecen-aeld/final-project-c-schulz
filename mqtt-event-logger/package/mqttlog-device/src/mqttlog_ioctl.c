// SPDX-License-Identifier: GPL-2.0

#include "mqttlog_ioctl.h"
#include "mqttlog_ringbuf.h"

// ioctl commands
long mqttlog_ioctl(struct file *file,
                   unsigned int cmd,
                   unsigned long arg)
{
    struct mqttlog_file *reader;

    // get reader-specific structure
    if (!(reader = file->private_data))
        return -EFAULT;


    // implement commands
    switch (cmd) {

    case MQTTLOG_IOCTL_SET_TOPIC_FILTER:
        return mqttlog_ioctl_set_topic_filter(reader,
                (void __user *)arg);

    case MQTTLOG_IOCTL_RESET_RINGBUFFER:
        return mqttlog_ioctl_reset_ringbuffer(reader);

    case MQTTLOG_IOCTL_GET_STATS:
        return mqttlog_ioctl_get_stats(reader,
                (void __user *)arg);

    default:
        return -ENOTTY;
    }
}

long mqttlog_ioctl_set_topic_filter(struct mqttlog_file *reader,
                                    void __user *arg)
{
    struct mqttlog_topic_filter filter;

    // validate input pointer
    if (!reader)
        return -EINVAL;

    // copy argument from user space into kernel space
    if (copy_from_user(&filter, arg, sizeof(filter)))
        return -EFAULT;

    // null-terminate
    filter.topic_filter[MQTTLOG_MAX_TOPIC_LEN - 1] = '\0';

    // copy into reader-specific struct
    strscpy(reader->topic_filter,
            filter.topic_filter,
            sizeof(reader->topic_filter));

    return 0;
}

long mqttlog_ioctl_reset_ringbuffer(struct mqttlog_file *reader)
{
    int ret;

    // validate input pointers
    if (!reader || !reader->mqttlog)
        return -EINVAL;

    // lock ringbuffer mutex
    ret = mutex_lock_interruptible(&reader->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // reset ringbuffer and unlock mutex
    mqttlog_ringbuf_reset(&reader->mqttlog->ringbuf);
    mutex_unlock(&reader->mqttlog->mutex);

    return 0;
}

long mqttlog_ioctl_get_stats(struct mqttlog_file *reader,
                             void __user *arg)
{
    struct mqttlog_stats stats;
    int ret;

    // validate input pointers
    if (!reader || !reader->mqttlog)
        return -EINVAL;

    // lock ringbuffer mutex
    ret = mutex_lock_interruptible(&reader->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // fill stats and unlock mutex
    mqttlog_ringbuf_stats(&reader->mqttlog->ringbuf, &stats);
    mutex_unlock(&reader->mqttlog->mutex);

    // copy result from kernel space into user space
    if (copy_to_user(arg, &stats, sizeof(stats)))
        return -EFAULT;

    return 0;
}
