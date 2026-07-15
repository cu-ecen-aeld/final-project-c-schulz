mod cli;
mod ioctl;
mod mqttlog;
mod types;

use clap::Parser;

use cli::{Cli, Command};
use mqttlog::MqttLog;

fn main() {
    // parse commands
    let cli = Cli::parse();

    // open device, print errors
    let dev = MqttLog::open().unwrap_or_else(|e| {
        eprintln!("Failed to open /dev/mqttlog: {}", e);
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
            follow,
            json,
            limit,
            filter,
        } => dev.dump(filter.as_deref(), follow, json, limit),
    };

    // print errors
    if let Err(e) = result {
        eprintln!("mqttlogctl: {}", e);
        std::process::exit(1);
    }
}