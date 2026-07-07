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
    if (!json || !entry)
        return -EINVAL;

    // zero-initialize entry
    memset(entry, 0, sizeof(*entry));

    // assign metadata
    entry->sequence  = mqttlog_sequence++;          // post-increment because first index is 0
    entry->timestamp = ktime_get_real_seconds();    // TODO: readable format

    // parse and assign topic, discard parsed part of json
    ret = mqttlog_parse_field(json, "topic", MQTTLOG_FIELD_STRING_RAW, entry->topic, MQTTLOG_MAX_TOPIC_LEN, &json);
    if (ret)
        return ret;

    // parse and assign payload, discard parsed part of json
    ret = mqttlog_parse_field(json, "payload", MQTTLOG_FIELD_UNKNOWN, entry->payload, MQTTLOG_MAX_PAYLOAD_LEN, &json);
    if (ret)
        return ret;

    return 0;
}

void mqttlog_print_entry(const struct mqttlog_entry *entry)
{
    // validate input pointer
    if (!entry)
        return;

    pr_info("mqttlog:\n");
    pr_info("  sequence : %llu\n", entry->sequence);
    pr_info("  timestamp: %llu\n", entry->timestamp);
    pr_info("  topic    : %s\n",   entry->topic);
    pr_info("  payload  : %s\n",   entry->payload);
}

int mqttlog_format_entry(const struct mqttlog_entry *entry,
                         char* out, size_t out_size)
{
    // validate input pointer
    if (!entry)
        return 0;

    return scnprintf(out,
                    out_size,
                    "{\n"
                    "  sequence : %llu,\n"
                    "  timestamp: %llu,\n"
                    "  topic    : %s,\n"
                    "  payload  : %s\n"
                    "}\n",
                    entry->sequence,
                    entry->timestamp,
                    entry->topic,
                    entry->payload);
}

int mqttlog_parse_field(const char *json,
                        const char *field,
                        enum mqttlog_field_type type,
                        char *dst,
                        const size_t dst_size,
                        const char** rest)
{
    const char *pos;
    const char *start;
    const char *end;
    size_t copy_len;
    int brace_level;

    // validate input pointers
    if (!json || !field || !dst || (dst_size == 0) || !rest)
        return -EINVAL;

    // find start of matching string
    pos = strstr(json, field);
    if (!pos)
        return -EINVAL;

    // find next ':'
    pos = strchr(pos, ':');
    if (!pos)
        return -EINVAL;

    // skip ':', then skip all whitespace
    do ++pos;
    while (*pos == ' ' || *pos == '\n' || *pos == '\t' || *pos == '\r');

    // implement search for start and end of field
    switch (type) {

        // implementation for field type 'string'
        case MQTTLOG_FIELD_STRING_RAW:
        case MQTTLOG_FIELD_STRING: {

            // because of whitespace skipping, next pos needs to be a '"'
            if (*pos != '"')
                return -EINVAL;

            // skip '"', initialize end
            start = pos; // +1: skip leading '"'
            end   = start + 1;

            // find end of string
            skip_to_end_of_string(&end);

            if (*end != '"')
                return -EINVAL;


            // estimate length to copy
            copy_len = end - start + 1; // +1: include trailing '"'

            break;
        }
        // implementation for field type 'object' ({...})
        case MQTTLOG_FIELD_OBJECT: {

            // because of whitespace skipping, next pos needs to be a '{'
            if (*pos != '{')
                return -EINVAL;

            // don't skip anything, start directly at '{'
            start = pos;
            end   = start + 1;

            // find end of scope
            brace_level = 1;
            while (*end && (brace_level > 0)) {
                if (*end == '"') {
                    ++end;
                    skip_to_end_of_string(&end);
                }
                else if (*end == '{')
                    ++brace_level;
                else if (*end == '}')
                    --brace_level;
                ++end;
            }

            // validate state
            if (brace_level != 0)
                return -EINVAL;

            // estimate length to copy
            copy_len = end - start;
            break;
        }
        // implementation for field type 'array' ([...])
        case MQTTLOG_FIELD_ARRAY: {

            // because of whitespace skipping, next pos needs to be a '['
            if (*pos != '[')
                return -EINVAL;

            // don't skip anything, start directly at '['
            start = pos;
            end   = start + 1;

            // find end of scope
            brace_level = 1;
            while (*end && (brace_level > 0)) {
                if (*end == '"') {
                    ++end;
                    skip_to_end_of_string(&end);
                }
                else if (*end == '[')
                    ++brace_level;
                else if (*end == ']')
                    --brace_level;
                ++end;
            }

            // validate state
            if (brace_level != 0)
                return -EINVAL;

            // estimate length to copy
            copy_len = end - start;
            break;
        }
        // implementation for field type 'value' (number, bool, null, ...)
        case MQTTLOG_FIELD_VALUE: {

            // skip nothing
            start = pos;
            end   = start;

            // continue until finding any delimiter
            while (*end         &&
                   *end != ','  &&
                   *end != '}'  &&
                   *end != ']'  &&
                   *end != ' '  &&
                   *end != '\n' &&
                   *end != '\t' &&
                   *end != '\r')
                ++end;

            // estimate length to copy
            copy_len = end - start;
            break;
        }
        // implementation for field type 'unknown' (can be anything)
        case MQTTLOG_FIELD_UNKNOWN: {
            if (*pos == '"')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_STRING, dst, dst_size, rest);
            if (*pos == '{')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_OBJECT, dst, dst_size, rest);
            if (*pos == '[')
                return mqttlog_parse_field(json, field, MQTTLOG_FIELD_ARRAY, dst, dst_size, rest);
            return mqttlog_parse_field(json, field, MQTTLOG_FIELD_VALUE, dst, dst_size, rest);
        }
        default:
            return -EINVAL;
    }

    // special case: copy string value, but without leading and trailing '"'
    if (type == MQTTLOG_FIELD_STRING_RAW) {
        ++start;
        copy_len -= 2;
    }

    // copy only the first letters up until the allowed maximum field size
    if (copy_len >= dst_size)
        copy_len = dst_size - 1;

    // copy substring into dst and null-terminate
    memcpy(dst, start, copy_len);
    dst[copy_len] = '\0';

    // set rest to remaining input value
    *rest = start + copy_len + 1;    // TODO: +1?

    return 0;
}

void skip_to_end_of_string(const char** end)
{
    if (!end)
        return;

    int escaped = 0;
    while (**end) {
        if ((**end == '"') && (escaped % 2 == 0))
            break;          // unescaped '"' detected
        if (**end == '\\')
            ++escaped;      // increase counter for '\'
        else
            escaped = 0;    // reset counter for '\'

        ++(*end);
    }
}
