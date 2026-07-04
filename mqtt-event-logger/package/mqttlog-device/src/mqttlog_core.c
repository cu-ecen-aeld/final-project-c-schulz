// SPDX-License-Identifier: GPL-2.0

#include <linux/kernel.h>       // pr_info()
#include <linux/uaccess.h>      // copy_to_user(), copy_from_user()

#include "mqttlog_core.h"
#include "mqttlog_parser.h"


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
    char *kbuf;
    struct mqttlog_entry entry;
    int ret;

    pr_info("mqttlog: received %zu bytes\n", len);
    if (len == 0)
        return 0;

    // allocate temporary kernel buffer (+1 for terminating '\0')
    kbuf = kmalloc(len + 1, GFP_KERNEL);
    if (!kbuf)
        return -ENOMEM;

    // copy message from userspace into kernel space
    if (copy_from_user(kbuf, buf, len)) {
        kfree(kbuf);
        return -EFAULT;
    }

    // null-terminate string
    kbuf[len] = '\0';

    // parse the message and store it into a new entry
    memset(&entry, 0, sizeof(entry));
    ret = mqttlog_parse_message(kbuf, len, &entry);

    // free temporary kernel buffer
    kfree(kbuf);

    // return error or success
    if (ret)
        return ret;

    // print received message
    mqttlog_print_message(&entry);

    // TODO: mqttlog_ringbuf_push()

    return len;
}

// read from device (e.g. cat /dev/mqttlog)
ssize_t mqttlog_read(struct file *file,
                     char __user *buf,
                     size_t len,
                     loff_t *off)
{
    // mqttlog_ringbuf_pop()
    // copy_to_user()

    return 0;
}