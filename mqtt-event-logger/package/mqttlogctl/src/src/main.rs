mod mqttlogctl_cli;
mod mqttlog_ioctl;
mod mqttlog;
mod mqtt_event;
mod mqtt_event_parser;
mod mqtt_event_framer;

use clap::Parser;

use mqttlogctl_cli::{Cli, Command};
use mqttlog::MqttLog;

fn main() {
    // parse commands
    let cli = Cli::parse();

    // evaluate 'follow' argument
    let nonblocking = match &cli.command {
        Command::Dump { follow, .. } => !follow,
        _ => true,
    };

    // open device, print errors
    let dev = MqttLog::open(nonblocking).unwrap_or_else(|e| {
        eprintln!("mqttlogctl: Failed to open /dev/mqttlog: {}", e);
        std::process::exit(1);
    });

    // execute commands
    let result = match cli.command {
        // print stats
        Command::Stats => dev.stats().map(|stats| {
            println!("Events written : {}", stats.events_written);
            println!("Events dropped : {}", stats.events_dropped);
            println!("Buffer size    : {}", stats.buffer_size);
            println!("Buffer used    : {}", stats.buffer_used);
        }),

        // reset kernel ringbuffer
        Command::Reset => dev.reset(),

        // dump messages
        Command::Dump {
            follow: _,
            json,
            limit,
            topic,
        } => dev.dump(topic.as_deref(), json, limit),
    };

    // print errors
    if let Err(e) = result {
        eprintln!("mqttlogctl: {}", e);
        std::process::exit(1);
    }
}