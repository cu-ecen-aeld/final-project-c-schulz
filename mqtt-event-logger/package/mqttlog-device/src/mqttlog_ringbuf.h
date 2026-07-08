// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_RINGBUF_H
#define MQTTLOG_RINGBUF_H

#include "mqttlog_types.h"

// standard ringbuffer operations
void mqttlog_ringbuf_init(struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_empty(const struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_full(const struct mqttlog_ringbuf *rb);
int  mqttlog_ringbuf_push(struct mqttlog_ringbuf *rb, const struct mqttlog_entry *entry);
int  mqttlog_ringbuf_top(const struct mqttlog_ringbuf *rb, struct mqttlog_entry *entry);
void mqttlog_ringbuf_pop(struct mqttlog_ringbuf *rb);

// operations with custom read pointer (points to next sequence id)
int  mqttlog_ringbuf_top_sequence(const struct mqttlog_ringbuf *rb, uint64_t* next_sequence);
int  mqttlog_ringbuf_read_sequence(const struct mqttlog_ringbuf *rb, uint64_t* next_sequence, struct mqttlog_entry *entry);
void mqttlog_ringbuf_next_sequence(const struct mqttlog_ringbuf *rb, uint64_t* next_sequence);
bool mqttlog_ringbuf_has_data(const struct mqttlog_ringbuf *rb, const uint64_t next_sequence);

#endif // MQTTLOG_RINGBUF_H