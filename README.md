
# Embedded MQTT Event Logger

## Project Overview
Please see the [Project Overview page](../../wiki/Project-Overview).

## Build and install steps

1. Clone repository:
    ```
    git@github.com:cu-ecen-aeld/final-project-c-schulz.git
    ```

2. Install buildroot dependencies listed [here](https://buildroot.org/downloads/manual/manual.html#requirement-mandatory).

3. On Ubuntu 26.04 you might need to install gnu install (see [here](https://www.reddit.com/r/Ubuntu/comments/1t5el5i/warning_on_ubuntu_2604_be_cautious/)):
    ```
    sudo apt install coreutils-from-gnu coreutils-from-uutils- rust-coreutils- --allow-remove-essential --mark-auto --purge
    ```

3. Configure your WiFi credentials and build the project:
    ```
    make config WIFI_SSID=<wifi-ssid> WIFI_PWD=<wifi-pwd>
    make
    ```

4. Flash image to SD card and set target device (defaults to `/dev/sde`):
    ```
    sudo make install MQTT_TARGET_DEVICE=<your-device>
    ```

## Test setup

1. Install MQTT broker:
    ```
    sudo apt install mosquitto
    ```

2. Install MQTT cli (see [here](https://hivemq.github.io/mqtt-cli/docs/installation/)):
    ```
    wget https://github.com/hivemq/mqtt-cli/releases/download/v4.52.0/mqtt-cli-4.52.0.deb
    sudo apt install ./mqtt-cli-4.52.0.deb
    ```

3. Test MQTT cli:

    * In terminal 1, subscribe to test topic (JSON-formatted):
        ```
        mqtt sub -t test -J
        ```
    * In terminal 2, publish to test topic (JSON-formatted):
        ```
        mqtt pub -t test -m '{"text": "HI!"}'
        ```
    * Terminal 1 should print the message:
        ```
        {
            "topic": "test",
            "payload": {
                "text": "HI!"
            },
            "qos": "AT_MOST_ONCE",
            "receivedAt": "<date> <time>",
            "retain": false
        }
        ```

4. Optionally install MQTT explorer:
    ```
    sudo snap install mqtt-explorer
    ```