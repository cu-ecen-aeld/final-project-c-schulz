// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_TYPES_H
#define MQTTLOG_TYPES_H

#include <linux/types.h>
#include <linux/fs.h>               // struct file, inode, file_operations
#include <linux/cdev.h>             // struct cdev
#include <linux/mutex.h>            // struct mutex
#include <linux/wait.h>             // struct wait_queue_head_t


// struct defining an entry of the ringbuffer
#define MQTTLOG_MAX_TOPIC_LEN    128
#define MQTTLOG_MAX_PAYLOAD_LEN 1024
struct mqttlog_entry {
    __u64 sequence;
    ktime_t timestamp;

    char topic[MQTTLOG_MAX_TOPIC_LEN];
    char payload[MQTTLOG_MAX_PAYLOAD_LEN];
};

// maximum length for string-conversion buffer
#define MQTTLOG_MAX_STRING_LEN  2048


// enum for the potential json/mqtt object entries
enum mqttlog_field_type {
    MQTTLOG_FIELD_STRING_RAW,
    MQTTLOG_FIELD_STRING,
    MQTTLOG_FIELD_OBJECT,
    MQTTLOG_FIELD_ARRAY,
    MQTTLOG_FIELD_VALUE,
    MQTTLOG_FIELD_UNKNOWN
};


// struct defining the actual ringbuffer
#define MQTTLOG_RING_SIZE 128
struct mqttlog_ringbuf {
    struct mqttlog_entry entries[MQTTLOG_RING_SIZE];

    size_t write_pos;               // next write position
    size_t read_pos;                // next read position
    size_t count;                   // number of contained elements

    __u64 total_written;            // number of written messages
    __u64 total_dropped;            // number of dropped messages
};


// struct containing all device-specific structs for /dev/mqttlog
struct mqttlog_dev {
    // device info
    dev_t dev_num;                  // major/minor number
    struct cdev cdev;               // actual character device, I/O interface for kernel
    struct class *class;            // custom device class /sys/class/mqttlog
    struct device *device;          // one instance of the driver

    // actual data
    struct mqttlog_ringbuf ringbuf; // ringbuffer
    struct mutex mutex;             // mutex protecting ringbuffer

    // wait queue for blocking reads
    wait_queue_head_t read_queue;
};


// struct containing reader-specific context
struct mqttlog_file {
    // general common data
    struct mqttlog_dev *mqttlog;    // device information

    // reader-specific data
    __u64 cursor;                   // next sequence id to read
    char topic_filter[MQTTLOG_MAX_TOPIC_LEN];
};

#endif // MQTTLOG_TYPES_H