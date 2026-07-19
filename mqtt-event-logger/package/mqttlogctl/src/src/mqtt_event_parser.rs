// MQTTEvent parser definition
//
// parse_event()


use crate::mqtt_event::MqttEvent;

use chrono::{DateTime, Utc};
use serde::{Deserialize};
use std::fmt;

// struct representing event metadata, temporarily used for parsing
#[derive(Deserialize)]
struct EventHeader {
    sequence:  u64,
    timestamp: u64,
    topic:     String,
}

// struct representing potential parse errors
#[derive(Debug)]
pub enum ParseError {
    MissingPayload,
    InvalidJsonFrame,
    InvalidTimestamp,
    InvalidHeader(serde_json::Error),
}

// debug output definitions for parse errors
impl fmt::Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ParseError::MissingPayload =>
                write!(f, "missing payload field"),

            ParseError::InvalidJsonFrame =>
                write!(f, "invalid event framing"),

            ParseError::InvalidTimestamp =>
                write!(f, "invalid timestamp"),

            ParseError::InvalidHeader(e) =>
                write!(f, "invalid event header: {}", e),
        }
    }
}

// conversion from std error to ParseError (not defined)
impl std::error::Error for ParseError {}

// conversion from serde_json error to ParseError (special case)
impl From<serde_json::Error> for ParseError {
    fn from(err: serde_json::Error) -> Self {
        ParseError::InvalidHeader(err)
    }
}

// parse one JSON event from mqttlog device, example:
//
// {
//   "sequence":0,
//   "timestamp":1752774257123456789,
//   "topic":"test-topic",
//   "payload":{"text":"HI!"}
// }
//
pub fn parse_event(input: &str) -> Result<MqttEvent, ParseError> {
    // find beginning of payload
    let payload_pos = input
        .find("\"payload\"")
        .ok_or(ParseError::MissingPayload)?;

    // everything before payload is header
    let header_json = format!(
        "{}\n}}",
        &input[..payload_pos]
            .trim_end()
            .trim_end_matches(',')
    );

    // parse only the header / metadata
    let header: EventHeader = serde_json::from_str(&header_json)?;

    // find ':' after "payload"
    let payload_start = input[payload_pos..]
        .find(':')
        .map(|i| payload_pos + i + 1)
        .ok_or(ParseError::MissingPayload)?;

    // skip whitespace after ':'
    let payload_start = input[payload_start..]
        .find(|c: char| !c.is_whitespace())
        .map(|i| payload_start + i)
        .ok_or(ParseError::MissingPayload)?;

    // find end of payload (char before last })
    let payload_end = input
        .rfind('}')
        .ok_or(ParseError::InvalidJsonFrame)?;

    // extract actual payload
    let payload = input[payload_start..payload_end]
        .trim()
        .to_string();

    // convert timestamp to date time format
    let secs  = (header.timestamp / 1_000_000_000) as i64;
    let nanos = (header.timestamp % 1_000_000_000) as u32;

    let timestamp = DateTime::<Utc>::from_timestamp(secs, nanos)
        .ok_or(ParseError::InvalidTimestamp)?;

    // convert fields to MqttEvent type
    Ok(MqttEvent {
        sequence: header.sequence,
        timestamp,
        topic: header.topic,
        payload,
    })
}