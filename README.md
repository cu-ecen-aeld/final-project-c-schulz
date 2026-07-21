
# Embedded MQTT Event Logger

## Project Overview
Please see the [Project Overview page](../../wiki/Project-Overview) for the project description, and the [Project Schedule page](https://github.com/users/c-schulz/projects/2/views/1?visibleFields=%5B%22Title%22%2C%22Assignees%22%2C%22Status%22%2C357876735%5D&groupedBy%5BcolumnId%5D=357876735) for the project timeline and user stories.
The [Project Video](../../wiki/Project-Video) page links to a small demo video.

## Build and install buildroot image for *Raspberry Pi Zero W*

The project is intended to run on a *Raspberry Pi Zero W*. The config in `mqtt-event-logger/configs/mqtt_rpi_defconfig` is prepared to build the project for this hardware type. Only the parameters for WiFi credentials and MQTT broker host need to be modified to fit your runtime environment.

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
        (make clean)
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

To interact with the embedded device, an MQTT broker is required. The following instructions can be used to set up an MQTT broker and publish/subscribe tools on an arbitrary host device.

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

## Run image on *Raspberry Pi Zero W*

Now you should be able to install and test your image on target hardware.

1. Install SD card with the compiled Buildroot image on your *Raspberry Pi Zero W*.   
    Custom modifications for this project are:

    * `mqtt-subscriber` boots automatically and subscribes to all messages published by your host.
    * `mqttlog` kernel module is loaded automatically and provides the device `/dev/mqttlog`.
    * `mqttlogctl` binary is available at `/usr/bin/mqttlogctl`.

2. Publish messages via MQTT, e.g.
    * publish (preferably JSON-formatted) file or message via MQTT cli:
        ```
        mqtt pub -t test -m:file ./tests/example.json
        mqtt pub -t test -m '{"text": "Hello World!"}'
        ```
    * or publish messages via MQTT explorer

3. Evaluate `/dev/mqttlog` device on your embedded device:
    * ssh to your *Raspberry Pi Zero W* (password `root`):
        ```
        ssh root@<ip-address>
        ```
    * inspect log file `/var/log/messages`
    * inspect device, e.g. `cat /dev/mqttlog`
    * utilize `mqttlogctl` cli tool:
        * read messages from `/dev/mqttlog`:
            ```
            mqttlogctl dump [--follow]
                            [--json]
                            [--limit <n>]
                            [--topic <filter>]
            ```
        * reset internal ringbuffer, i.e. clear `/dev/mqttlog`:
            ```
            mqttlogctl reset
            ```
        * print statistics of `/dev/mqttlog`:
            ```
            mqttlogctl stats
            ```

A small demo is provided in the [Project Video](../../wiki/Project-Video).

## Build and test with *QEMU* buildroot image

For prototyping and debugging, it is faster to develop and test with a *QEMU* instance. The config in `mqtt-event-logger/configs/mqtt_qemu_defconfig` can be used to build the project for a *QEMU* target.

1. Configure and build project:
    ```
    (make clean)
    make config QEMU_BUILD=true
    make QEMU_BUILD=true
    ```

2. Boot image:
    ```
    ./tests/validate_qemu.sh start
    ```
    (invokes `./tests/runqemu.sh`)

3. Run tests:
    * ssh into *QEMU* instance (password `root`) and observe logfile:
        ```
        ssh root@localhost -p 2222
        tail -f /var/log/messages
        ```
    * on host system, trigger pre-defined tests, e.g.:
        ```
        ./tests/validate_qemu.sh mqttlog-cat
        ./tests/validate_qemu.sh mqttlog-buffer-size
        ./tests/validate_qemu.sh mqttlog-pub-sub
        ```
    * or run custom tests, e.g. publish via MQTT cli (JSON-formatted):
        ```
        mqtt pub -t test -m '{"text": "Hello World!"}'
        ```
    * use `mqttlogctl` cli tool to control the device:
        ```
        mqttlogctl stats
        mqttlogctl reset
        mqttlogctl dump [--follow] [--json] [--limit N] [--filter TOPIC]
        ```

4. Stop image:
    ```
    ./tests/validate_qemu.sh stop
    ```