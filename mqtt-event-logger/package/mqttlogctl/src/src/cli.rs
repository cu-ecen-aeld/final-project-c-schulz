// CLI definition:
//
// mqttlogctl stats
// mqttlogctl reset
// mqttlogctl dump [--follow] [--json] [--limit N] [--filter TOPIC]


use clap::{Parser, Subcommand};

// define command line interface for 'mqttlogctl'
#[derive(Parser)]
#[command(
    name = "mqttlogctl",
    version,
    about = "Userspace utility for the mqttlog kernel module"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,
}

// define available subcommands
#[derive(Subcommand)]
pub enum Command {
    // show runtime statistics
    Stats,

    // reset the kernel ringbuffer
    Reset,

    // dump events
    Dump {
        // follow newly arriving events
        #[arg(short, long)]
        follow: bool,

        // print events as JSON
        #[arg(short, long)]
        json: bool,

        // stop after n events
        #[arg(short, long)]
        limit: Option<usize>,

        // set topic filter
        #[arg(short, long)]
        topic: Option<String>,
    },
}