// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_RINGBUF_H
#define MQTTLOG_RINGBUF_H

#include "mqttlog_types.h"

void mqttlog_ringbuf_init (struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_empty(const struct mqttlog_ringbuf *rb);
bool mqttlog_ringbuf_full (const struct mqttlog_ringbuf *rb);
int  mqttlog_ringbuf_push (struct mqttlog_ringbuf *rb, const struct mqttlog_entry *entry);
int  mqttlog_ringbuf_pop  (struct mqttlog_ringbuf *rb, struct mqttlog_entry *entry);

#endif // MQTTLOG_RINGBUF_H