// SPDX-License-Identifier: GPL-2.0

#include "mqttlog_ringbuf.h"

// initialize ringbuffer
void mqttlog_ringbuf_init(struct mqttlog_ringbuf *rb)
{
    memset(rb,0,sizeof(struct mqttlog_ringbuf));
    // sets write_pos, read_pos, count, total_written and total_dropped to zero
}

// reset ringbuffer
void mqttlog_ringbuf_reset(struct mqttlog_ringbuf *rb)
{
    // reset entries
    memset(rb->entries,0,sizeof(rb->entries));

    // reset write_pos, read_pos and count
    rb->write_pos = 0;
    rb->read_pos  = 0;
    rb->count     = 0;

    // don't reset global sequence number
    // don't reset total_written and total_dropped
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

// return statistics
void mqttlog_ringbuf_stats(const struct mqttlog_ringbuf *rb,
                           struct mqttlog_stats *stats)
{
    if (!rb || !stats)
        return;

    memset(stats, 0, sizeof(*stats));

    stats->events_written = rb->total_written;
    stats->events_dropped = rb->total_dropped;
    stats->buffer_size    = MQTTLOG_RING_SIZE;
    stats->buffer_used    = rb->count;
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
    ++rb->total_written;        // stats: one more message was received

    // if ringbuffer is full, oldest entry is implicitly overwritten
    // in that case, also increase read pointer to the next newest entry
    if (mqttlog_ringbuf_full(rb)) {
        rb->read_pos = (rb->read_pos + 1) % MQTTLOG_RING_SIZE;
        ++rb->total_dropped;    // stats: one more message was overwritten/dropped
    }

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
                                 __u64 *cursor)
{
    if (!rb || !cursor)
        return -EINVAL;

    if (mqttlog_ringbuf_empty(rb))
        *cursor = 0;
    else
        *cursor = rb->entries[rb->read_pos].sequence;

    return 0;
}

// return entry at specified position
int mqttlog_ringbuf_read_sequence(const struct mqttlog_ringbuf *rb,
                                  __u64 *cursor,
                                  const char *topic_filter,
                                  struct mqttlog_entry *entry)
{
    size_t custom_read_pos;
    const struct mqttlog_entry* candidate;

    if (!rb || !cursor)
        return -EINVAL;

    if (mqttlog_ringbuf_empty(rb))
        return -ENOENT;

    // search from read begin until specified sequence id is found
    custom_read_pos = rb->read_pos;
    do {
        candidate = &rb->entries[custom_read_pos];

        // if ringbuffer is already further than next sequence, skip a few
        if (candidate->sequence > *cursor)
            *cursor = candidate->sequence;

        // found sequence id, return entry if topic matches filter
        if (candidate->sequence == *cursor) {
            if (mqttlog_topic_matches(topic_filter, candidate->topic)) {
                *entry = *candidate;
                return 0;
            }
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
                                   __u64 *cursor)
{
    if (!rb || !cursor)
        return;

    // increase sequence id
    ++(*cursor);
}

// check whether ringbuffer has data to provide
bool mqttlog_ringbuf_has_data(const struct mqttlog_ringbuf *rb,
                              const __u64 cursor,
                              const char *topic_filter)
{
    size_t custom_read_pos;

    if (!rb || mqttlog_ringbuf_empty(rb))
        return false;

    // search from read begin until specified sequence id is found
    custom_read_pos = rb->read_pos;
    do {
        // if sequence id is found or sequence ids need to be skipped, return true if topic matches filter
        if (rb->entries[custom_read_pos].sequence >= cursor) {
            if (mqttlog_topic_matches(topic_filter, rb->entries[custom_read_pos].topic))
                return true;
        }

        // advance to next position in ringbuffer
        custom_read_pos = (custom_read_pos + 1) % MQTTLOG_RING_SIZE;
    }
    while (custom_read_pos != rb->write_pos);

    // if entry with specified sequence id is not (yet) available, return false
    return false;
}

bool mqttlog_topic_matches(const char *filter,
                           const char *topic)
{
    if (!filter || !topic)
        return false;

    // if filter is empty, any topic matches
    if (filter[0] == '\0')
        return true;

    // 1) Variant A: exact match
    // compare filter and topic strings
    // strcmp does exact match, no wildcard match
    // return (strcmp(filter, topic) == 0);

    // 2) Variant B: wildcard matches
    while (*filter && *topic) {

        // '#' matches everything up from the current level,
        // but must be the last char of the filter string
        if (*filter == '#')
            return filter[1] == '\0';

        // '+' matches exactly one topic level,
        // skip topic level and advance to the next one
        if (*filter == '+') {
            filter++;

            // '+' must occupy a complete level,
            // the next char must be '/' or the end of the string
            if ((*filter != '\0') && (*filter != '/'))
                return false;

            // skip until reaching the next topic level
            while (*topic && (*topic != '/'))
                topic++;

            // if end of filter is reached,
            // we also need to be at the end of the topic string
            if (*filter == '\0')
                return *topic == '\0';

            // next char in topic must be '/'
            if (*topic != '/')
                return false;

            // we are at the end of the topic level
            // skip both '/' and advance to the next level
            filter++;
            topic++;
            continue;
        }

        // compare the next non-wildcard character
        if (*filter != *topic)
            return false;

        // advance to the next character
        filter++;
        topic++;
    }

    // if topic ends but filter still has '/#', this is valid
    // (e.g. filter 'test/#' and topic 'test')
    if ((*topic == '\0') && (*filter == '/') && (filter[1] == '#'))
        return true;

    // if filter ends with #, everything is valid
    if (*filter == '#')
        return filter[1] == '\0';

    // ensure that the end of both strings is reached (no leftovers)
    return (*filter == '\0') && (*topic == '\0');
}
