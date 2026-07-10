// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_RINGBUF_H
#define MQTTLOG_RINGBUF_H

#include "mqttlog_types.h"
#include "mqttlog_ioctl.h"

// standard ringbuffer operations
void mqttlog_ringbuf_init(struct mqttlog_ringbuf *rb);
void mqttlog_ringbuf_reset(struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_empty(const struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_full(const struct mqttlog_ringbuf *rb);
void mqttlog_ringbuf_stats(const struct mqttlog_ringbuf *rb, struct mqttlog_stats *stats);

// main modification operations
int  mqttlog_ringbuf_push(struct mqttlog_ringbuf *rb, const struct mqttlog_entry *entry);
int  mqttlog_ringbuf_top(const struct mqttlog_ringbuf *rb, struct mqttlog_entry *entry);
void mqttlog_ringbuf_pop(struct mqttlog_ringbuf *rb);

// operations with custom read pointer (points to next sequence id) or custom topic filter
int  mqttlog_ringbuf_top_sequence(const struct mqttlog_ringbuf *rb, __u64 *cursor);
int  mqttlog_ringbuf_read_sequence(const struct mqttlog_ringbuf *rb, __u64 *cursor, const char *topic_filter, struct mqttlog_entry *entry);
void mqttlog_ringbuf_next_sequence(const struct mqttlog_ringbuf *rb, __u64 *cursor);
bool mqttlog_ringbuf_has_data(const struct mqttlog_ringbuf *rb, const __u64 cursor, const char *topic_filter);
bool mqttlog_topic_matches(const char *topic_filter, const char *topic);

#endif // MQTTLOG_RINGBUF_H