// MQTTEvent conversion definition:
//
// parse_event()


use chrono::{DateTime, Utc};
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_json::Value;

// struct representing one MQTT log event
#[derive(Debug, Deserialize, Serialize)]
pub struct MqttEvent {
    pub sequence:  u64,
    #[serde(
        deserialize_with = "deserialize_timestamp",
        serialize_with = "serialize_timestamp"
    )]
    pub timestamp: DateTime<Utc>,
    pub topic:     String,
    pub payload:   Value,
}

// convert kernel timestamp (nanoseconds since Unix epoch) to UTC
fn deserialize_timestamp<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
where D: Deserializer<'de>,
{
    let ns = u64::deserialize(deserializer)
        .map_err(serde::de::Error::custom)?;

    let secs  = (ns / 1_000_000_000) as i64;
    let nanos = (ns % 1_000_000_000) as u32;

    DateTime::<Utc>::from_timestamp(secs, nanos)
        .ok_or_else(|| serde::de::Error::custom("invalid timestamp"))
}

// convert UTC timestamp to string
fn serialize_timestamp<S>(timestamp: &DateTime<Utc>, 
                          serializer: S) -> Result<S::Ok, S::Error>
where S: Serializer,
{
    // serializer.serialize_str(&timestamp.to_rfc3339())
    serializer.serialize_str(
        &timestamp
            .format("%Y-%m-%d %H:%M:%S%.3f UTC")
            .to_string(),
    )
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
pub fn parse_event(line: &str) -> serde_json::Result<MqttEvent> {
    serde_json::from_str::<MqttEvent>(line)
}