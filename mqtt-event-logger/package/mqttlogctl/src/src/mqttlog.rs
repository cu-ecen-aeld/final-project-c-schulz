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
use std::os::unix::fs::OpenOptionsExt;
use std::os::fd::{AsRawFd, RawFd};
use std::io::{BufRead, BufReader};

// wrapper representing /dev/mqttlog device
pub struct MqttLog {
    file: File,
}

impl MqttLog {
    // open the /dev/mqttlog character device
    pub fn open(nonblocking: bool) -> io::Result<Self> {
        let mut options = OpenOptions::new();

        // set read and write options
        options.read(true)
               .write(true);

        // set nonblocking option if 'follow' = false
        if nonblocking {
            options.custom_flags(nix::libc::O_NONBLOCK);
        }

        // actually open the device
        let file = options.open("/dev/mqttlog")?;

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
                topic:  Option<&str>,
                follow: bool,
                json:   bool,
                limit:  Option<usize>) -> io::Result<()> {
        // if parameter 'topic' is set, apply topic filter
        if let Some(topic) = topic {
            self.set_filter(topic)?;
        }

        // start reading from device
        let mut reader = BufReader::new(&self.file);
        let mut line = String::new();
        let mut count = 0usize;

        loop {
            // read next line
            line.clear();
            match reader.read_line(&mut line) {

                // if '0' is returned, exit regularly (device empty?)
                Ok(0) => break,

                // regular case, print raw line or parse json (later)
                Ok(_) => {
                    print!("{}", line);
                    count += 1;

                    // exit if message dump limit is reached
                    if let Some(limit) = limit {
                        if count >= limit {
                            break;
                        }
                    }
                }

                // exit regularly if ringbuffer is empty
                // - follow = false / O_NONBLOCK: EAGAIN, exit here
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                    break;
                }

                // for all other errors, return error
                Err(e) => return Err(e),
            }
        }

        Ok(())
    }
}