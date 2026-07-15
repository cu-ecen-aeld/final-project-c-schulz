mod ioctl;
mod mqttlog;

fn main() {
    println!("mqttlogctl");

    // print stats
    let dev = mqttlog::MqttLog::open().unwrap();
    let stats = dev.stats().unwrap();
    println!("{:#?}", stats);
}