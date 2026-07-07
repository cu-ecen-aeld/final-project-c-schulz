// SPDX-License-Identifier: GPL-2.0

#ifndef MQTTLOG_PARSER_H
#define MQTTLOG_PARSER_H

#include "mqttlog_types.h"

int  mqttlog_parse_message(const char *json, size_t len, struct mqttlog_entry *entry);
void mqttlog_print_entry(const struct mqttlog_entry *entry);
int  mqttlog_format_entry(const struct mqttlog_entry *entry, char* out, size_t out_size);

int  mqttlog_parse_field(const char *json, const char *field, enum mqttlog_field_type type, char *dst, const size_t dst_size, const char** rest);
void skip_to_end_of_string(const char** end);

#endif // MQTTLOG_PARSER_H