
# Embedded MQTT Event Logger

## Project Overview
Please see the [Project Overview page](../../wiki/Project-Overview).

## Build and install buildroot image for Raspberry Pi Zero W

1. Install dependencies
    * Buildroot dependencies listed [here](https://buildroot.org/downloads/manual/manual.html#requirement-mandatory).
    * On Ubuntu 26.04 you might need to install the following (see [here](https://www.reddit.com/r/Ubuntu/comments/1t5el5i/warning_on_ubuntu_2604_be_cautious/)):
        ```
        sudo apt install coreutils-from-gnu     \
                         coreutils-from-uutils- \
                         rust-coreutils-        \
             --allow-remove-essential --mark-auto --purge
        ```
    * Install cargo (required for Rust program `mqttlogctl`):
        ```
        sudo apt install cargo
        ```

2. Configure and build the project:
    * Configure buildroot with your custom WiFi credentials:
        ```
        make config WIFI_SSID=<wifi-ssid> WIFI_PWD=<wifi-pwd>
        ```
        The WiFi credential parameters are configured by command line because they should not be versionized in git.
    * Configure your MQTT broker host with:
        ```
        make menuconfig
        ```
        Modify the entry in `External options -> MQTT Event Logger external project tree -> mqtt-subscriber -> MQTT host` with your custom mqtt broker address (usually `mqtt://<mqtt-broker-ip-address>:1883`).
    * Build the configured project with:
        ```
        make
        ```

3. Flash image to SD card and set target device (defaults to `/dev/sde`):
    ```
    sudo make install MQTT_TARGET_DEVICE=<your-device>
    ```

## Setup test environment on host

1. Install and configure MQTT broker:
    * Install with:
        ```
        sudo apt install mosquitto
        ```
    * Edit `/etc/mosquitto/mosquitto.conf`, to allow connections from remote; add:
        ```
        listener 1883 0.0.0.0
        allow_anonymous true
        ```
    * Restart to apply changes:
        ```
        sudo systemctl restart mosquitto
        ```


2. Install MQTT cli (see [here](https://hivemq.github.io/mqtt-cli/docs/installation/)):
    ```
    wget https://github.com/hivemq/mqtt-cli/releases/download/v4.52.0/mqtt-cli-4.52.0.deb
    sudo apt install ./mqtt-cli-4.52.0.deb
    ```

3. Install MQTT explorer (optional):
    ```
    sudo snap install mqtt-explorer
    ```

## Build and test qemu buildroot image

1. Configure and build project:
    ```
    make config QEMU_BUILD=true
    make QEMU_BUILD=true
    ```

2. Boot image:
    ```
    ./tests/runqemu.sh
    ```

3. Run tests:
    * ssh into qemu (password `root`):
        ```
        ssh root@localhost -p 2222
        ```
    * observe logfile:
        ```
        tail -f /var/log/messages
        ```
    * on host system, trigger pre-defined tests, e.g.:
        ```
        ./tests/validate_qemu.sh mqttlog-cat
        ./tests/validate_qemu.sh mqttlog-buffer-size
        ./tests/validate_qemu.sh mqttlog-pub-sub
        ```
    * or run custom tests, e.g. publish via mqtt cli (JSON-formatted):
        ```
        mqtt pub -t test -m '{"text": "Hello World!"}'
        ```
    * use `mqttlogctl` cli tool to control the device; available commands:
        ```
        mqttlogctl stats
        mqttlogctl reset
        mqttlogctl dump [--follow] [--json] [--limit N] [--filter TOPIC]
        ```

## Inspect Raspberry Pi Zero W

1. Install SD card with image on Raspberry Pi Zero W.

    * `mqtt-subscriber` boots automatically and subscribes to all messages published by your host.
    * `mqttlog` kernel module is loaded automatically and provides the device `/dev/mqttlog`.
    * `mqttlogctl` binary is available at `/usr/bin/mqttlogctl`.