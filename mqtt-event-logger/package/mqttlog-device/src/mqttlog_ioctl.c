// SPDX-License-Identifier: GPL-2.0

#include "mqttlog_ioctl.h"

// ioctl commands
long mqttlog_ioctl(struct file *file,
                   unsigned int cmd,
                   unsigned long arg)
{
    struct mqttlog_file *ctx;

    // get reader-specific structure
    if (!(ctx = file->private_data))
        return -EFAULT;


    // implement commands
    switch (cmd) {

    case MQTTLOG_IOCTL_SET_TOPIC_FILTER:
        return mqttlog_ioctl_set_topic_filter(ctx,
                (void __user *)arg);

    case MQTTLOG_IOCTL_RESET_RINGBUFFER:
        return mqttlog_ioctl_reset_ringbuffer(ctx);

    case MQTTLOG_IOCTL_GET_STATS:
        return mqttlog_ioctl_get_stats(ctx,
                (void __user *)arg);

    default:
        return -ENOTTY;
    }
}

long mqttlog_ioctl_set_topic_filter(struct mqttlog_file *ctx,
                                    void __user *arg)
{
    struct mqttlog_topic_filter filter;

    // validate input pointer
    if (!ctx)
        return -EINVAL;

    // copy argument from user space into kernel space
    if (copy_from_user(&filter, arg, sizeof(filter)))
        return -EFAULT;

    // null-terminate
    filter.topic[MQTTLOG_MAX_TOPIC_LEN - 1] = '\0';

    // copy into reader-specific struct
    strscpy(ctx->topic_filter,
            filter.topic,
            sizeof(ctx->topic_filter));

    return 0;
}

long mqttlog_ioctl_reset_ringbuffer(struct mqttlog_file *ctx)
{
    struct mqttlog_ringbuf *rb;

    // validate input pointers
    if (!ctx || !ctx->mqttlog)
        return -EINVAL;

    // lock ringbuffer mutex
    ret = mutex_lock_interruptible(&ctx->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // reset ringbuffer and unlock mutex
    mqttlog_ringbuf_reset(&ctx->mqttlog->ringbuf);
    mutex_unlock(&ctx->mqttlog->mutex);

    return 0;
}

long mqttlog_ioctl_get_stats(struct mqttlog_file *ctx,
                             void __user *arg)
{
    struct mqttlog_stats stats;

    // validate input pointers
    if (!ctx || !ctx->mqttlog)
        return -EINVAL;

    // lock ringbuffer mutex
    ret = mutex_lock_interruptible(&ctx->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // fill stats and unlock mutex
    mqttlog_ringbuf_stats(&ctx->mqttlog->ringbuf, &stats);
    mutex_unlock(&ctx->mqttlog->mutex);

    // copy result from kernel space into user space
    if (copy_to_user(arg, &stats, sizeof(stats)))
        return -EFAULT;

    return 0;
}
