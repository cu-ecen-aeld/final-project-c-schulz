// SPDX-License-Identifier: GPL-2.0

#include <linux/kernel.h>       // pr_info()
#include <linux/uaccess.h>      // copy_to_user(), copy_from_user()

#include "mqttlog_core.h"
#include "mqttlog_parser.h"
#include "mqttlog_ringbuf.h"


// init struct
void mqttlog_init(struct mqttlog_dev *mqttlog)
{
    // initialize ringbuffer
    mqttlog_ringbuf_init(&mqttlog->ringbuf);
}

// open device
int mqttlog_open(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: open\n");

    // initialize reader-specific cursor
    file->private_data = container_of(inode->i_cdev, struct mqttlog_dev, cdev);

    return 0;
}

// close device
int mqttlog_release(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: close\n");

    // reset reader-specific cursor
    file->private_data = NULL;

    return 0;
}

// write to device (e.g. echo "..." > /dev/mqttlog)
ssize_t mqttlog_write(struct file *file,
                      const char __user *buf,
                      size_t len,
                      loff_t *off)
{
    struct mqttlog_entry entry;
    struct mqttlog_dev *mqttlog;
    char *kbuf;
    int ret;

    pr_info("mqttlog: received %zu bytes\n", len);
    if (len == 0)
        return 0;


    // 1) copy message into kernel space
    // allocate temporary kernel buffer (+1 for terminating '\0')
    kbuf = kmalloc(len + 1, GFP_KERNEL);
    if (!kbuf)
        return -ENOMEM;

    // copy message from userspace into kernel space
    if (copy_from_user(kbuf, buf, len)) {
        kfree(kbuf);
        pr_err("mqttlog: error copying message to kernel\n");
        return -EFAULT;
    }

    // null-terminate string
    kbuf[len] = '\0';


    // 2) parse and print message
    // parse the message and store it into a new entry
    memset(&entry, 0, sizeof(entry));
    ret = mqttlog_parse_message(kbuf, len, &entry);

    // free temporary kernel buffer
    kfree(kbuf);

    // return error or success
    if (ret) {
        pr_err("mqttlog: error parsing message\n");
        return ret;
    }

    // print received message
    mqttlog_print_entry(&entry);


    // 3) modify ringbuffer
    // get reader-specific cursor
    if (!(mqttlog = file->private_data))
        return -EFAULT;

    // lock ringbuffer mutex
    if (mutex_lock_interruptible(&mqttlog->mutex) != 0)
        return -EFAULT;

    // insert received message into ringbuffer
    ret = mqttlog_ringbuf_push(&mqttlog->ringbuf, &entry);
    mutex_unlock(&mqttlog->mutex);
    if (ret) {
        pr_err("mqttlog: error pushing entry to ringbuffer\n");
        return ret;
    }

    // 4) return
    // increase offset by number of written bytes
    *off += len;

    return len;
}

// read from device (e.g. cat /dev/mqttlog)
ssize_t mqttlog_read(struct file *file,
                     char __user *buf,
                     size_t len,
                     loff_t *off)
{
    struct mqttlog_entry entry;
    struct mqttlog_dev *mqttlog;
    char out[MQTTLOG_MAX_STRING_LEN];
    int out_len;
    int ret;

    // return EOF if this read has already been accomplished
    if (*off != 0)
        return 0;


    // 1) fetch message from ringbuffer
    // get reader-specific cursor
    if (!(mqttlog = file->private_data))
        return -EFAULT;

    // lock ringbuffer mutex
    if (mutex_lock_interruptible(&mqttlog->mutex) != 0)
        return -EFAULT;

    // retreive oldest message from ringbuffer
    ret = mqttlog_ringbuf_pop(&mqttlog->ringbuf, &entry);
    mutex_unlock(&mqttlog->mutex);
    if (ret) {
        pr_err("mqttlog: error fetching entry from ringbuffer\n");
        return ret;
    }


    // 2) convert message to string
    // convert mqttlog entry to string
    out_len = mqttlog_format_entry(&entry, out, sizeof(out));


    // 3) copy message into user space
    // if message does not fit into buffer, return error
    if (out_len > len)
        return -EINVAL;

    // copy message to buffer
    ret = copy_to_user(buf, out, out_len);
    if (ret) {
        pr_err("mqttlog: error copying ringbuffer entry to user\n");
        return ret; // -EFAULT;
    }


    // 4) return
    // increase offset by number of read bytes
    *off += out_len;

    return out_len;
}