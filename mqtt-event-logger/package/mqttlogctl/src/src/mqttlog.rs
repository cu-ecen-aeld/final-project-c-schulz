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
use crate::event::parse_event;
use crate::framer::JsonFramer;

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
                json:   bool,
                limit:  Option<usize>) -> io::Result<()> {
        // if parameter 'topic' is set, apply topic filter
        if let Some(topic) = topic {
            self.set_filter(topic)?;
        }

        // start reading from device
        let mut reader = BufReader::new(&self.file);
        let mut framer = JsonFramer::new();
        let mut buffer  = String::new();
        let mut line   = String::new();
        let mut count  = 0usize;

        loop {
            // read next line
            line.clear();
            match reader.read_line(&mut line) {

                // if '0' is returned, exit regularly (device empty / EOF)
                Ok(0) => break,

                // regular case, data is received
                Ok(_) => {

                    // append line to event and analyze JSON frame
                    buffer.push_str(&line);
                    framer.feed(&line);

                    // if JSON object is not complete yet, continue reading
                    if !framer.complete() {
                        continue;
                    }

                    // otherwise, parse event into JSON object
                    let event = match parse_event(&buffer) {

                        Ok(event) => event,

                        // in case of error, print error and reset JSON frame
                        Err(e) => {
                            eprintln!(
                                "mqttlogctl: invalid json event: {}",
                                e
                            );

                            buffer.clear();
                            framer.reset();

                            // JSON object was probably not complete yet
                            continue;
                        }
                    };

                    // pretty-print whole event as JSON
                    if json {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(&event)
                                .map_err(io::Error::other)?
                        );

                    // or print raw event
                    } else {
                        println!(
                            "[{}] #{} {}",
                            // convert timestamp to readable format
                            event.timestamp.format("%Y-%m-%d %H:%M:%S%.3f UTC"),
                            event.sequence,
                            event.topic
                        );

                        // pretty-print payload as JSON
                        println!(
                            "{}",
                            serde_json::to_string_pretty(&event.payload)
                                .map_err(io::Error::other)?
                        );

                        // print newline
                        println!();
                    }

                    // count received events
                    count += 1;

                    // exit if message dump limit is reached
                    if let Some(limit) = limit {
                        if count >= limit {
                            break;
                        }
                    }

                    // prepare for next event
                    buffer.clear();
                    framer.reset();
                }

                // exit regularly if ringbuffer is empty
                // - follow = false / O_NONBLOCK: EAGAIN, exit here
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {
                    break;
                }

                // for all other errors, return error
                Err(e) => {
                    return Err(e);
                }
            }
        }

        Ok(())
    }
}