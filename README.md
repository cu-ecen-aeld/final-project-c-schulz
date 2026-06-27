
# Embedded MQTT Event Logger

## Project Overview
Please see the [Project Overview page](../../wiki/Project-Overview).

## Build and install buildroot image

1. Clone repository:
    ```
    git clone git@github.com:cu-ecen-aeld/final-project-c-schulz.git
    ```
    or
    ```
    git clone https://github.com/cu-ecen-aeld/final-project-c-schulz.git
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

## Setup test environment on host

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

4. Install MQTT explorer (optional):
    ```
    sudo snap install mqtt-explorer
    ```

## Build and test mqtt subscriber

1. Install dependencies:
    ```
    sudo apt install libssl-dev
    ```

2. Build mqtt subscriber:
    ```
    ./tests/validate_mqtt.sh build
    ```

3. Start mqtt subscriber:
    ```
    ./tests/validate_mqtt.sh start
    ```

4. Run pre-defined mqtt subscriber test:
    ```
    ./tests/validate_mqtt.sh pub-sub
    ```

5. Run own tests:

    * Publish message on any topic:
        ```
        mqtt pub -t test -m '{"text": "HI!"}'
        ```

    * Observe message being logged to `/tmp/mqttlog`:
        ```
        cat /tmp/mqttlog
        ```
        yields e.g.:
        ```
        {
            "topic": "test",
            "payload": {"text": "HI!"}
        }
        ```

    * Observe syslog output in `/var/log/syslog`:
        ```
        tail /var/log/syslog | grep mqtt_subscriber
        ```
        yields e.g.
        ```
        2026-06-27T15:54:53.150915+02:00 Buckbeak mqtt_subscriber: Message arrived. Topic: 'test'. Payload: '{"text": "HI!"}'
        ```

6. Stop mqtt subscriber:
    ```
    ./tests/validate_mqtt.sh stop
    ```