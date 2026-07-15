// MqttLog device interface definition:
//
// open()
// stats()
// reset()
// dump()


use crate::ioctl::{
    mqttlog_get_stats,
    mqttlog_reset_ringbuffer,
    mqttlog_set_topic_filter,
    MqttlogStats,
    MqttlogTopicFilter,
    MQTTLOG_MAX_TOPIC_LEN,
};

use std::fs::{File, OpenOptions};
use std::io;
use std::os::fd::{AsRawFd, RawFd};

// wrapper representing /dev/mqttlog device
pub struct MqttLog {
    file: File,                         // treat mqttlog as file
}

impl MqttLog {
    // open the /dev/mqttlog character device
    pub fn open() -> io::Result<Self> {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .open("/dev/mqttlog")?;

        Ok(Self { file })
    }

    // return underlying raw file descriptor (required for ioctl)
    fn fd(&self) -> RawFd {
        self.file.as_raw_fd()
    }

    // retrieve runtime statistics
    pub fn stats(&self) -> io::Result<MqttlogStats> {
        // initialize stats with zero
        let mut stats = MqttlogStats {
            events_written: 0,
            events_dropped: 0,
            buffer_size: 0,
            buffer_used: 0,
        };

        // execute ioctl command 'get_stats'
        let ret = unsafe {
            mqttlog_get_stats(self.fd(), &mut stats)
        };

        // check for errors
        if ret.is_err() {
            return Err(io::Error::last_os_error());
        }

        Ok(stats)
    }

    // reset the kernel ringbuffer
    pub fn reset(&self) -> io::Result<()> {
        // execute ioctl command 'reset_ringbuffer'
        let ret = unsafe {
            mqttlog_reset_ringbuffer(self.fd())
        };

        // check for errors
        if ret.is_err() {
            return Err(io::Error::last_os_error());
        }

        Ok(())
    }

    // configure the reader-specific topic filter
    fn set_filter(&self, topic: &str) -> io::Result<()> {
        // validate length of input string
        if topic.len() >= MQTTLOG_MAX_TOPIC_LEN {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "topic filter too long",
            ));
        }

        // initialize topic filter with zeros
        let mut filter = MqttlogTopicFilter {
            topic_filter: [0; MQTTLOG_MAX_TOPIC_LEN],
        };

        // convert input string to topic filter
        filter.topic_filter[..topic.len()]
            .copy_from_slice(topic.as_bytes());

        // execute ioctl command 'set_topic_filter'
        let ret = unsafe {
            mqttlog_set_topic_filter(self.fd(), &filter)
        };

        // check for errors
        if ret.is_err() {
            return Err(io::Error::last_os_error());
        }

        Ok(())
    }

    pub fn dump(&self,
                filter: Option<&str>,
                follow: bool,
                json: bool,
                limit: Option<usize>) -> io::Result<()> {
        // if parameter 'filter' is set, apply topic filter
        if let Some(topic) = filter {
            self.set_filter(topic)?;
        }

        // start reading from device
        let mut reader = BufReader::new(&self.file);
        let mut line = String::new();
        let mut count = 0usize;

        loop {

            // read next line
            line.clear();
            let n = reader.read_line(&mut line)?;
            if n == 0 {

                // if '0' is returned, device is empty
                // either exit here or wait for new events
                if follow {
                    continue;
                } else {
                    break;
                }
            }

            // either print raw line or parse json
            if json {
                let entry = parse(line);
                println!("{}", serde_json::to_string(&entry)?);
            } else {
                print!("{}", line);
            }

            // exit if message dump limit is reached
            count += 1;
            if let Some(limit) = limit {
                if count >= limit {
                    break;
                }
            }
        }

        Ok(())
    }
}