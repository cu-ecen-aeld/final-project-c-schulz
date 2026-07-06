// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_PARSER_H
#define MQTTLOG_PARSER_H

#include <linux/types.h>

#define MQTTLOG_MAX_TOPIC_LEN    128
#define MQTTLOG_MAX_PAYLOAD_LEN 1024

struct mqttlog_entry {
    u64 sequence;
    ktime_t timestamp;

    char topic[MQTTLOG_MAX_TOPIC_LEN];
    char payload[MQTTLOG_MAX_PAYLOAD_LEN];
};

int  mqttlog_parse_message(const char *json, size_t len, struct mqttlog_entry *entry);
void mqttlog_print_message(const struct mqttlog_entry *entry);


enum mqttlog_field_type {
    MQTTLOG_FIELD_STRING_RAW,
    MQTTLOG_FIELD_STRING,
    MQTTLOG_FIELD_OBJECT,
    MQTTLOG_FIELD_ARRAY,
    MQTTLOG_FIELD_VALUE,
    MQTTLOG_FIELD_UNKNOWN
};

int  mqttlog_parse_field(const char *json, const char *field, enum mqttlog_field_type type, char *dst, const size_t dst_size, const char** rest);
void skip_to_end_of_string(const char** end);

#endif // MQTTLOG_PARSER_H