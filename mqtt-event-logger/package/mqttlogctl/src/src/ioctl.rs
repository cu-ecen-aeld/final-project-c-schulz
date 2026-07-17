// IOCTL definition:
//
// set_topic_filter
// reset_ringbuffer
// get_stats


// magic IOCTL command seed (copied from 'mqttlog_ioctl.h')
pub const MQTTLOG_IOCTL_MAGIC: u8 = b'M';

// maximum mqttlog topic length (copied from 'mqttlog_types.h')
pub const MQTTLOG_MAX_TOPIC_LEN: usize = 128;


// IOCTL structs

// define struct equivalent to mqttlog_stats
#[repr(C)]          // ensure exact C struct match!
pub struct MqttlogStats {
    pub events_written: u64,
    pub events_dropped: u64,
    pub buffer_size: u32,
    pub buffer_used: u32,
}

// define struct equivalent to mqttlog_topic_filter
#[repr(C)]          // ensure exact C struct match!
pub struct MqttlogTopicFilter {
    pub topic_filter: [u8; MQTTLOG_MAX_TOPIC_LEN],
}


// IOCTL commands (copied from 'mqttlog_ioctl.h' and converted via nix)

// write command to specify a reader-specific topic filter
nix::ioctl_write_ptr!(
    mqttlog_set_topic_filter,
    MQTTLOG_IOCTL_MAGIC,
    0x01,
    MqttlogTopicFilter
);

// command to reset the ringbuffer
nix::ioctl_none!(
    mqttlog_reset_ringbuffer,
    MQTTLOG_IOCTL_MAGIC,
    0x02
);

// read command to retreive statistics
nix::ioctl_read!(
    mqttlog_get_stats,
    MQTTLOG_IOCTL_MAGIC,
    0x03,
    MqttlogStats
);