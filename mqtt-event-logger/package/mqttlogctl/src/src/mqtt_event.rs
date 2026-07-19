// MQTTEvent definition and print functions:
//
// print_raw()
// print_json()


use chrono::{DateTime, Utc};

// struct representing one MQTT log event
pub struct MqttEvent {
    pub sequence:  u64,
    pub timestamp: DateTime<Utc>,
    pub topic:     String,
    pub payload:   String,
}

// implement print functions for MqttEvents
impl MqttEvent {
    fn timestamp_string(&self) -> String {
        self.timestamp
            .format("%Y-%m-%d %H:%M:%S%.3f UTC")
            .to_string()
    }

    pub fn print_raw(&self) {
        // print metadata
        println!(
            "[{}] #{} {}",
            // convert timestamp to readable format
            self.timestamp_string(),
            self.sequence,
            self.topic
        );

        // print payload
        println!("{}", self.payload);
        println!();
    }

    pub fn print_json(&self) -> serde_json::Result<()> {
        // try converting payload to JSON, or use raw payload string instead
        let payload = match serde_json::from_str::<serde_json::Value>(&self.payload) {
            Ok(value) => value,
            Err(_) => serde_json::Value::String(self.payload.clone()),
        };

        // print metadata and payload
        println!(
            "{}",
            serde_json::to_string_pretty(
                &serde_json::json!({
                    "sequence" : self.sequence,
                    "timestamp": self.timestamp_string(),
                    "topic"    : self.topic,
                    "payload"  : payload,
                })
            )?
        );

        Ok(())
    }

}