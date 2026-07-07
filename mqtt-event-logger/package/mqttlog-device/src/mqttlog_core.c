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
    char out[len]; //[MQTTLOG_MAX_STRING_LEN];
    char tmp[MQTTLOG_MAX_STRING_LEN];
    int out_len;
    int tmp_len;
    int ret;

    // return EOF if this read has already been accomplished
    if (*off != 0)
        return 0;

    // get reader-specific cursor
    if (!(mqttlog = file->private_data))
        return -EFAULT;

    // lock ringbuffer mutex
    if (mutex_lock_interruptible(&mqttlog->mutex) != 0)
        return -EFAULT;

    // fetch messages from ringbuffer until user buffer is full or ringbuffer empty
    out_len = 0;
    while (!mqttlog_ringbuf_empty(&mqttlog->ringbuf)) {

        // retreive oldest message from ringbuffer
        ret = mqttlog_ringbuf_top(&mqttlog->ringbuf, &entry);
        if (ret) {
            pr_err("mqttlog: error fetching entry from ringbuffer\n");
            mutex_unlock(&mqttlog->mutex);
            return ret;
        }

        // convert message to string
        tmp_len = mqttlog_format_entry(&entry, tmp, sizeof(tmp));
        if (tmp_len < 0) {
            pr_err("mqttlog: error formatting entry\n");
            mutex_unlock(&mqttlog->mutex);
            return tmp_len;
        }

        // check if message fits into user buffer
        if (out_len + tmp_len > len)
            break;

        // copy string to buffer for copying to user
        memcpy(out + out_len, tmp, tmp_len);
        out_len += tmp_len;

        // actually pop message from ringbuffer
        mqttlog_ringbuf_pop(&mqttlog->ringbuf);
    }

    // unlock ringbuffer mutex because all modification is finished
    mutex_unlock(&mqttlog->mutex);

    // if not even the first message fit into buffer, return no space error
    if (out_len == 0)
        return -ENOSPC;

    // copy message into user space buffer
    ret = copy_to_user(buf, out, out_len);
    if (ret) {
        pr_err("mqttlog: error copying ringbuffer entry to user\n");
        return ret;
    }

    // increase offset by number of read bytes
    *off += out_len;

    return out_len;
}