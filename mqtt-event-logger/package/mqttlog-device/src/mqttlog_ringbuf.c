// SPDX-License-Identifier: GPL-2.0

#include "mqttlog_ringbuf.h"

// initialize ringbuffer
void mqttlog_ringbuf_init(struct mqttlog_ringbuf *rb)
{
    memset(rb,0,sizeof(struct mqttlog_ringbuf));
    // sets write_pos, read_pos and count to zero
}

// is ringbuffer empty?
bool mqttlog_ringbuf_empty(const struct mqttlog_ringbuf *rb)
{
    return rb && (rb->count == 0);
}

// is ringbuffer full?
bool mqttlog_ringbuf_full(const struct mqttlog_ringbuf *rb)
{
    return rb && (rb->count == MQTTLOG_RING_SIZE);
}

// add new entry, if necessary overwrite oldest entry
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

// return oldest entry
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

// remove oldest entry
void mqttlog_ringbuf_pop(struct mqttlog_ringbuf *rb)
{
    if (!rb || mqttlog_ringbuf_empty(rb))
        return;

    // increase read pointer
    rb->read_pos = (rb->read_pos + 1) % MQTTLOG_RING_SIZE;

    // reduce the number of contained elements
    --rb->count;
}

// return sequence id at current read position
int mqttlog_ringbuf_top_sequence(const struct mqttlog_ringbuf *rb,
                                 u64* next_sequence)
{
    if (!rb || !next_sequence)
        return -EINVAL;

    if (mqttlog_ringbuf_empty(rb))
        *next_sequence = 0;
    else
        *next_sequence = rb->entries[rb->read_pos].sequence;

    return 0;
}

// return entry at specified position
int mqttlog_ringbuf_read_sequence(const struct mqttlog_ringbuf *rb,
                                  u64* next_sequence,
                                  struct mqttlog_entry *entry)
{
    size_t custom_read_pos;

    if (!rb || !next_sequence)
        return -EINVAL;

    if (mqttlog_ringbuf_empty(rb))
        return -ENOENT;

    // search from read begin until specified sequence id is found
    custom_read_pos = rb->read_pos;
    do {
        // if ringbuffer is already further than next sequence, skip a few
        if (rb->entries[custom_read_pos].sequence > *next_sequence)
            *next_sequence = rb->entries[custom_read_pos].sequence;

        // found sequence id, return entry
        if (rb->entries[custom_read_pos].sequence == *next_sequence) {
            *entry = rb->entries[custom_read_pos];
            return 0;
        }

        // advance to next position in ringbuffer
        custom_read_pos = (custom_read_pos + 1) % MQTTLOG_RING_SIZE;
    }
    while (custom_read_pos != rb->write_pos);

    // if entry with specified sequence id is not (yet) available, return ENOENT
    return -ENOENT;
}

// increase custom position pointer
void mqttlog_ringbuf_next_sequence(const struct mqttlog_ringbuf *rb,
                                   u64* next_sequence)
{
    if (!rb || !next_sequence)
        return;

    // increase sequence id
    ++(*next_sequence);
}

// check whether ringbuffer has data to provide
bool mqttlog_ringbuf_has_data(const struct mqttlog_ringbuf *rb,
                              const u64 next_sequence)
{
    size_t custom_read_pos;

    if (!rb || mqttlog_ringbuf_empty(rb))
        return false;

    // search from read begin until specified sequence id is found
    custom_read_pos = rb->read_pos;
    do {
        // if sequence id is found or sequence ids need to be skipped, return true
        if (rb->entries[custom_read_pos].sequence >= next_sequence)
            return true;

        // advance to next position in ringbuffer
        custom_read_pos = (custom_read_pos + 1) % MQTTLOG_RING_SIZE;
    }
    while (custom_read_pos != rb->write_pos);

    // if entry with specified sequence id is not (yet) available, return false
    return false;
}