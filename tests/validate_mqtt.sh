#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..
MQTT_SUBSCRIBER_DIR=${REPO_DIR}/mqtt-event-logger/package/mqtt-subscriber
SRC_DIR=${MQTT_SUBSCRIBER_DIR}/src
BIN_DIR=${MQTT_SUBSCRIBER_DIR}/install/bin
MQTT_LOGFILE=/tmp/mqttlog

source ${TEST_DIR}/validate_helpers.sh


#######################
## available test steps

# build mqtt subscriber binary
build_mqtt_subscriber(){
  print $YELLOW "Build mqtt subscriber"
  pushd $SRC_DIR

  # cleanup old build
  rm -rf build

  # configure build
  cmake -B build -S . -DCMAKE_INSTALL_PREFIX=../install
  validate $?

  # build mqtt subscriber
  cmake --build build
  validate $?

  # install mqtt subscriber and deps
  cmake --install build --strip
  validate $?

  popd
  print $GREEN "Built mqtt subscriber"
}

# clean mqtt subscriber build
clean_mqtt_subscriber(){
  print $YELLOW "Clean mqtt subscriber"
  pushd $SRC_DIR

  # cleanup old build
  rm -rf build

  popd
  print $GREEN "Cleaned mqtt subscriber"
}

# start mqtt subscriber
start_mqtt_subscriber(){
  print $YELLOW "Start mqtt subscriber"
  pushd $BIN_DIR

  ./mqtt_subscriber -d -f $MQTT_LOGFILE
  validate $?

  popd
  print $GREEN "Started mqtt subscriber"
}

# stop mqtt subscriber
stop_mqtt_subscriber(){
  print $YELLOW "Stop mqtt subscriber"

  PID=$(pgrep -fa "./mqtt_subscriber -d -f $MQTT_LOGFILE" | awk {'print $1'})
  kill -SIGINT $PID
  validate $?

  print $GREEN "Stopped mqtt subscriber"
}

# run publish-subscribe test on mqtt subscriber
run_publish_subscribe_test(){
  print $YELLOW "Run publish-subscribe test"

  JSON1='{"text": "HI!"}'
  JSON2='{"text": "BYE!"}'

  # publish first test message
  print $NC "Publishing first message..."
  rm -f $MQTT_LOGFILE
  mqtt_publish test1 "$JSON1"
  validate $?
  print $NC "Validating first message..."
  validate_json $MQTT_LOGFILE

  # publish second test message
  print $NC "Publishing second message..."
  rm -f $MQTT_LOGFILE
  mqtt_publish test2 "$JSON2"
  validate $?
  print $NC "Validating second message..."
  validate_json $MQTT_LOGFILE

  # publish both messages (result is not json anymore!)
  print $NC "Publishing both messages..."
  rm -f $MQTT_LOGFILE
  mqtt_publish test1 "$JSON1"
  validate $?
  mqtt_publish test2 "$JSON2"
  validate $?

  # validate resulting content
  print $NC "Validating both messages..."
  JSON12='{
    "topic": "test1",
    "payload": {"text": "HI!"}
}
{
    "topic": "test2",
    "payload": {"text": "BYE!"}
}'
  validate_content $MQTT_LOGFILE "$JSON12"

  # remove logfile
  rm -f $MQTT_LOGFILE

  print $GREEN "Finished publish-subscribe test"
}


############################
## accepted script arguments

case "$1" in
  build)
    build_mqtt_subscriber
    ;;
  clean)
    clean_mqtt_subscriber
    ;;
  start)
    start_mqtt_subscriber
    ;;
  stop)
    stop_mqtt_subscriber
    ;;
  pub-sub)
    run_publish_subscribe_test
    ;;
  *)
    echo "Usage: $0 {build|clean|start|stop|pub-sub}"
    exit 1
    ;;
esac

exit 0