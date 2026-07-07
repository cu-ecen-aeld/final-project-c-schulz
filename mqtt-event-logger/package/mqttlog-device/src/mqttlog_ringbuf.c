// SPDX-License-Identifier: GPL-2.0

#include "mqttlog_ringbuf.h"

void mqttlog_ringbuf_init(struct mqttlog_ringbuf *rb)
{
    memset(rb,0,sizeof(struct mqttlog_ringbuf));
    // sets write_pos, read_pos and count to zero
}

bool mqttlog_ringbuf_empty(const struct mqttlog_ringbuf *rb)
{
    return rb && (rb->count == 0);
}

bool mqttlog_ringbuf_full(const struct mqttlog_ringbuf *rb)
{
    return rb && (rb->count == MQTTLOG_RING_SIZE);
}

int mqttlog_ringbuf_push(struct mqttlog_ringbuf *rb,
                         const struct mqttlog_entry *entry)
{
    if (!rb || !entry)
        return -EINVAL;

    // add new entry to the ringbuffer, increase write pointer
    rb->entries[rb->write_pos] = *entry;
    rb->write_pos = (rb->write_pos + 1) % MQTTLOG_RING_SIZE;

    // if ringbuffer is full, oldest entry is implicitly overwritten
    // in that case, also increase read pointer to the next newest entry
    if (mqttlog_ringbuf_full(rb))
        rb->read_pos = (rb->read_pos + 1) % MQTTLOG_RING_SIZE;

    // otherwise increase the number of contained elements
    else
        ++rb->count;

    return 0;
}

int mqttlog_ringbuf_top(const struct mqttlog_ringbuf *rb,
                        struct mqttlog_entry *entry)
{
    if (!rb)
        return -EINVAL;

    if (mqttlog_ringbuf_empty(rb))
        return -ENOENT;

    // return oldest entry, don't modify anything
    *entry = rb->entries[rb->read_pos];

    return 0;
}

void mqttlog_ringbuf_pop(struct mqttlog_ringbuf *rb)
{
    if (!rb || mqttlog_ringbuf_empty(rb))
        return;

    // increase read pointer
    rb->read_pos = (rb->read_pos + 1) % MQTTLOG_RING_SIZE;

    // reduce the number of contained elements
    --rb->count;
}
