// SPDX-License-Identifier: GPL-2.0

#include <linux/kernel.h>       // pr_info()
#include <linux/string.h>       // strstr(), strchr(), strncpy()
#include <linux/timekeeping.h>  // ktime_get_real_seconds()

#include "mqttlog_parser.h"
static u64 mqttlog_sequence = 0;

int mqttlog_parse_message(const char *json,
                          size_t len,
                          struct mqttlog_entry *entry)
{
    int ret;

    // validate input pointers
    if (json == NULL)
        return -EINVAL;

    if (entry == NULL)
        return -EINVAL;

    // zero-initialize entry
    memset(entry, 0, sizeof(entry));

    // assign metadata
    entry->sequence  = mqttlog_sequence++;
    entry->timestamp = ktime_get_real_seconds();

    // parse and assign topic, discard parsed part of json
    ret = mqttlog_parse_field(json, "topic", MQTTLOG_FIELD_STRING, entry->topic, MQTTLOG_MAX_TOPIC_LEN, json);
    if (ret)
        return ret;

    // parse and assign payload, discard parsed part of json
    ret = mqttlog_parse_field(json, "payload", MQTTLOG_FIELD_UNKNOWN, entry->payload, MQTTLOG_MAX_PAYLOAD_LEN, json);
    if (ret)
        return ret;

    return 0;
}

void mqttlog_print_message(const struct mqttlog_entry *entry)
{
    pr_info("mqttlog:\n");
    pr_info("  sequence : %llu\n", entry->sequence);
    pr_info("  timestamp: %llu\n", entry->timestamp);
    pr_info("  topic    : %s\n",   entry->topic);
    pr_info("  payload  : %s\n",   entry->payload);
}


static inline const char *skip_whitespace(const char *p)
{
    while (*p == ' ' || *p == '\n' || *p == '\t' || *p == '\r')
        ++p;
    return p;
}

int mqttlog_parse_field(const char *json,
                        const char *field,
                        enum mqttlog_json_type type,
                        char *dst,
                        const size_t dst_size,
                        char *rest)
{
    const char *pos;
    const char *start;
    const char *end;
    size_t copy_len;
    int brace_level;

    // validate input pointers
    if (!json || !field || !dst || (dst_size == 0))
        return -EINVAL;

    // find start of matching string
    pos = strstr(json, field);
    if (!pos)
        return -EINVAL;

    // find next ':'
    pos = strstr(json, ':');
    if (!pos)
        return -EINVAL;

    // skip all whitespace
    pos = skip_whitespace(pos + 1);

    // implement search for start and end of field
    switch (type) {

        // implementation for field type 'string'
        case MQTTLOG_FIELD_STRING: {

            // because of whitespace skipping, next pos needs to be a '"'
            if (*pos != '"')
                return -EINVAL;

            // skip '"', initialize end
            start = pos + 1;
            end   = start;

            do {
                // set end to next occurence of '"'
                end = strchr(start, '"');
                if (!end)
                    return -EINVAL;

                // find out if current '"' is escaped
                escaped = 0;
                while (--end == "\\")
                    escaped++;

                // reset end
                end = strchr(start, '"');
            } while (escaped % 2 == 1); // odd number of '\'

            // estimate length to copy
            copy_len = end - start;
            break;
        }
        // implementation for field type 'object' ({...})
        case MQTTLOG_FIELD_OBJECT: {

            // because of whitespace skipping, next pos needs to be a '{'
            if (*pos != '{')
                return -EINVAL;

            break;
        }
        // implementation for field type 'array' ([...])
        case MQTTLOG_FIELD_ARRAY: {

            // because of whitespace skipping, next pos needs to be a '['
            if (*pos != '[')
                return -EINVAL;

            break;
        }
        // implementation for field type 'value' (number, bool, null, ...)
        case MQTTLOG_FIELD_VALUE: {
            break;
        }
        // implementation for field type 'unknown' (can be anything)
        case MQTTLOG_FIELD_UNKNOWN {
            if (*pos == '"')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_STRING, dst, dst_size, rest);
            if (*pos == '{')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_OBJECT, dst, dst_size, rest);
            if (*pos == ']')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_ARRAY, dst, dst_size, rest);
            return mqttlog_parse_field(json, field, MQTTLOG_FIELD_VALUE, dst, dst_size, rest);
        }
        default:
            return -EINVAL;
    }

    // copy only the first letters up until the allowed maximum field size
    if (copy_len >= dst_size)
        copy_len = dst_size - 1;

    // copy substring into dst and null-terminate
    memcpy(dst, start, copy_len);
    dst[copy_len] = '\0';

    return 0;
}
