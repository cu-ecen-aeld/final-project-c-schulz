// SPDX-License-Identifier: GPL-2.0

#include <linux/kernel.h>           // pr_info()
#include <linux/uaccess.h>          // copy_to_user(), copy_from_user()

#include "mqttlog_core.h"
#include "mqttlog_parser.h"
#include "mqttlog_ringbuf.h"


// init struct
void mqttlog_init(struct mqttlog_dev *mqttlog)
{
    // initialize ringbuffer aand mutex
    mqttlog_ringbuf_init(&mqttlog->ringbuf);
    mutex_init(&mqttlog->mutex);

    // initialize wait queue
    init_waitqueue_head(&mqttlog->read_queue);
}

// open device
int mqttlog_open(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: open\n");
    struct mqttlog_file *ctx;
    int ret;

    // allocate reader-specific cursor
    ctx = kmalloc(sizeof(*ctx), GFP_KERNEL);
    if (!ctx)
        return -ENOMEM;

    // assign global mqttlog_dev member and initialize read position
    ctx->mqttlog = container_of(inode->i_cdev, struct mqttlog_dev, cdev);
    ret = mqttlog_ringbuf_top_sequence(&ctx->mqttlog->ringbuf, &ctx->next_sequence);
    if (ret)
        return ret;

    // store in reader-specific private data
    file->private_data = ctx;

    return 0;
}

// close device
int mqttlog_release(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: close\n");
    struct mqttlog_file *ctx;

    // reset reader-specific cursor
    ctx = file->private_data;
    kfree(ctx);

    // reset reader-specific private data to nullptr
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
    struct mqttlog_file *ctx;
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
    if (!(ctx = file->private_data))
        return -EFAULT;

    // lock ringbuffer mutex
    ret = mutex_lock_interruptible(&ctx->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // insert received message into ringbuffer
    ret = mqttlog_ringbuf_push(&ctx->mqttlog->ringbuf, &entry);
    mutex_unlock(&ctx->mqttlog->mutex);
    if (ret) {
        pr_err("mqttlog: error pushing entry to ringbuffer\n");
        return ret;
    }

    // wake up reader
    wake_up_interruptible(&ctx->mqttlog->read_queue);

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
    struct mqttlog_file *ctx;
    char out[len]; //[MQTTLOG_MAX_BUFFER_LEN];
    char tmp[MQTTLOG_MAX_STRING_LEN];
    int out_len;
    int tmp_len;
    int ret;

    // get reader-specific cursor
    if (!(ctx = file->private_data))
        return -EFAULT;

    // non-blocking mode:
    // if no data is available, return immediately
    if (file->f_flags & O_NONBLOCK) {
        if (!mqttlog_ringbuf_has_data(&ctx->mqttlog->ringbuf, ctx->next_sequence)) {
            return -EAGAIN;
        }
    }
    // blocking mode:
    // sleep until ringbuffer has new data
    else {
        ret = wait_event_interruptible(ctx->mqttlog->read_queue,
            mqttlog_ringbuf_has_data(&ctx->mqttlog->ringbuf, ctx->next_sequence));

        if (ret) {          // -RESTARTSYS received
            pr_debug("mqttlog: aborted while waiting for wakeup\n");
            return ret;
        }
    }

    // lock ringbuffer mutex
    // don't lock before, combination with wait might provoke deadlocks
    ret = mutex_lock_interruptible(&ctx->mqttlog->mutex);
    if (ret) {              // should be -RESTARTSYS
        pr_debug("mqttlog: aborted while locking mutex\n");
        return ret;
    }

    // fetch messages from ringbuffer until user buffer is full or everything was read
    out_len = 0;
    while (true) {

        // retreive message from ringbuffer, use reader-specific read pointer
        ret = mqttlog_ringbuf_read_sequence(&ctx->mqttlog->ringbuf, &ctx->next_sequence, &entry);
        if (ret == -ENOENT) // nothing left to read
            break;
        if (ret) {          // other error
            pr_err("mqttlog: error fetching entry from ringbuffer\n");
            mutex_unlock(&ctx->mqttlog->mutex);
            return ret;
        }

        // convert message to string
        tmp_len = mqttlog_format_entry(&entry, tmp, sizeof(tmp));
        if (tmp_len < 0) {
            pr_err("mqttlog: error formatting entry\n");
            mutex_unlock(&ctx->mqttlog->mutex);
            return tmp_len;
        }

        // check if message fits into user buffer
        if (out_len + tmp_len > len)
            break;

        // copy string to buffer for copying to user
        memcpy(out + out_len, tmp, tmp_len);
        out_len += tmp_len;

        // don't modify ringbuffer, only modify reader-specific read pointer
        // this step is done here s.t. no data gets lost in case buffer is too small
        mqttlog_ringbuf_next_sequence(&ctx->mqttlog->ringbuf, &ctx->next_sequence);
    }

    // unlock ringbuffer mutex because all modification is finished
    mutex_unlock(&ctx->mqttlog->mutex);

    // if not even the first message fit into buffer, return no space error
    if (out_len == 0)
        return -ENOBUFS;

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

// poll device
__poll_t mqttlog_poll(struct file *file,
                      poll_table *wait)
{
    struct mqttlog_file *ctx;
    __poll_t mask = 0;

    // get reader-specific cursor
    if (!(ctx = file->private_data))
        return mask;

    // register this file with the wait queue
    // if no data is available, poll will sleep here
    poll_wait(file, &ctx->mqttlog->read_queue, wait);

    // check whether ringbuffer has data to read and set poll flags
    if (mqttlog_ringbuf_has_data(&ctx->mqttlog->ringbuf, ctx->next_sequence))
        mask |= POLLIN | POLLRDNORM;

    return mask;
}