// SPDX-License-Identifier: GPL-2.0

#![no_std]

use kernel::prelude::*;

module! {
    type: MQTTCharDriver,
    name: "mqtt_char_driver",
    author: "Cornelia Schulz",
    description: "Event logging kernel module",
    license: "GPL",
}

struct MQTTCharDriver;

impl kernel::Module for MQTTCharDriver {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        pr_info!("mqtt_char_driver: module loaded\n");

        Ok(MQTTCharDriver)
    }
}

impl Drop for MQTTCharDriver {
    fn drop(&mut self) {
        pr_info!("mqtt_char_driver: module unloaded\n");
    }
}