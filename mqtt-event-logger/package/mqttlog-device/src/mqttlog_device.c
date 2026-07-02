// SPDX-License-Identifier: GPL-2.0

#include <linux/module.h>
#include <linux/init.h>

#include <linux/fs.h>           // file_operations
#include <linux/cdev.h>         // struct cdev
#include <linux/device.h>       // class_create(), device_create()
#include <linux/kernel.h>       // pr_info()
// #include <linux/uaccess.h>     // copy_to_user(), copy_from_user()

#define DEVICE_NAME "mqttlog"   // -> module creates /dev/mqttlog device


MODULE_DESCRIPTION("MQTT Event Logger");
MODULE_AUTHOR("Cornelia Schulz");
MODULE_VERSION("1.0.0");
MODULE_LICENSE("GPL");


// struct containing all device-specific structs for /dev/mqttlog
struct mqttlog_dev {
    dev_t dev_num;              // major/minor number
    struct cdev cdev;           // actual character device, I/O interface for kernel
    struct class *class;        // custom device class /sys/class/mqttlog
    struct device *device;      // one instance of the driver
};
static struct mqttlog_dev mqttlog;



// open device
static int mqttlog_open(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: open\n");
    return 0;
}

// close device
static int mqttlog_release(struct inode *inode, struct file *file)
{
    pr_info("mqttlog: close\n");
    return 0;
}

// write to device (e.g. echo "..." > /dev/mqttlog)
static ssize_t mqttlog_write(struct file *file,
                             const char __user *buf,
                             size_t len,
                             loff_t *off)
{
    pr_info("mqttlog: received %zu bytes\n", len);
    return len;
}

// read from device (e.g. cat /dev/mqttlog)
static ssize_t mqttlog_read(struct file *file,
                            char __user *buf,
                            size_t len,
                            loff_t *off)
{
    return 0;
}

// file operations struct, contains the provided functions
static const struct file_operations mqttlog_fops = {
    .owner   = THIS_MODULE,
    .open    = mqttlog_open,
    .release = mqttlog_release,
    .read    = mqttlog_read,
    .write   = mqttlog_write,
};


// init module (when module is loaded)
static int __init mqttlog_device_init(void)
{
    int ret;

    // reserve a free major/minor number, returned via dev_num
    ret = alloc_chrdev_region(&mqttlog.dev_num, 0, 1, DEVICE_NAME);
    if (ret < 0)
        return ret;

    // initialize the character device, assign custom file operations
    cdev_init(&mqttlog.cdev, &mqttlog_fops);

    // register the device in the kernel
    ret = cdev_add(&mqttlog.cdev, mqttlog.dev_num, 1);
    if (ret < 0)
        return ret;

    // create custom class, available as /sys/class/mqttlog
    mqttlog.class = class_create(DEVICE_NAME);
    if (IS_ERR(mqttlog.class))
        return PTR_ERR(mqttlog.class);

    // create the actual character device
    mqttlog.device = device_create(mqttlog.class, NULL, mqttlog.dev_num, NULL, DEVICE_NAME);
    if (IS_ERR(mqttlog.device))
        return PTR_ERR(mqttlog.device);

    pr_info("mqttlog_device: device created -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module loaded\n");

    return 0;
}

// exit module (when module is unloaded)
static void __exit mqttlog_device_exit(void)
{
    // delete device /dev/mqttlog
    device_destroy(mqttlog.class, mqttlog.dev_num);

    // delete device class /sys/class/mqttlog
    class_destroy(mqttlog.class);

    // unregister character device from kernel
    cdev_del(&mqttlog.cdev);

    // release major/minor number
    unregister_chrdev_region(mqttlog.dev_num, 1);

    pr_info("mqttlog_device: device destroyed -- /dev/%s\n", DEVICE_NAME);
    pr_info("mqttlog_device: module unloaded\n");
}


// setup load/unload hooks
module_init(mqttlog_device_init);
module_exit(mqttlog_device_exit);