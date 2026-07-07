#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..
MQTT_LOGFILE=/tmp/mqttlog

source ${TEST_DIR}/validate_helpers.sh


#######################
## available test steps

# build buildroot image with qemu settings
build_image(){
  print $YELLOW "Build buildroot image with qemu config"
  pushd $REPO_DIR

  # check if config has changed since last build
  QEMU_CONFIG="${REPO_DIR}/mqtt-event-logger/configs/mqtt_qemu_defconfig"
  QEMU_BUILD_CONFIG="QEMU_BUILD=true"
  if [ ! -f ${QEMU_CONFIG}.sha1 ] || ! sha1sum -c ${QEMU_CONFIG}.sha1 ; then

    # make clean build to make sure the versionized config is used
    print $YELLOW "Clean build because config has changed"
    make clean ${QEMU_BUILD_CONFIG}
    validate $?
  else
    # remove old mqttlog and mqtt-subscriber sources to force rebuild
    print $YELLOW "Re-use old build, config has not changed"
    rm -r rm buildroot/output/build/mqtt-subscriber*
    rm -r rm buildroot/output/build/mqttlog-device-*
  fi

  # compile buildroot image
  make ${QEMU_BUILD_CONFIG}
  validate $?

  # update sha1
  sha1sum ${QEMU_CONFIG} > ${QEMU_CONFIG}.sha1

  popd
  print $GREEN "Built buildroot image with qemu config"
}

# boot image with qemu
start_qemu(){
  print $YELLOW "Start qemu instance in background"
  ${TEST_DIR}/runqemu.sh &

  validate $?
  print $YELLOW "Wait 30s for qemu instance to be up"
  sleep 30
  print $GREEN "Started qemu instance in background"
}

# kill qemu instance
stop_qemu(){
  print $YELLOW "Stop qemu instance"
  killall -9 qemu-system-arm

  validate $?
  sleep 1
  print $GREEN "Stopped qemu instance"
}

# log in via ssh
login_ssh(){
  print $YELLOW "Log in via ssh"

  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "[localhost]:2222"
  try_cmd_for 180s 5 "ssh_cmd 'exit'"

  validate $?
  print $GREEN "Logged in via ssh"
}

# check if mqtt subscriber is running
test_mqtt_subscriber(){
  print $YELLOW "Verify mqtt subscriber is running"
  ssh_cmd 'command -v /usr/bin/mqtt_subscriber'

  validate $?
  print $GREEN "Verified mqtt subscriber is running"
}

# run publish-subscribe test on mqtt subscriber
run_publish_subscribe_test(){
  print $YELLOW "Run publish-subscribe test"

  JSON1='{"text": "HI!"}'
  JSON2='{"text": "BYE!"}'
  LOCAL_LOGFILE=$(basename $MQTT_LOGFILE)

  # publish first test message
  print $NC "Publishing first message..."
  ssh_cmd "rm -f $MQTT_LOGFILE"
  mqtt_publish test1 "$JSON1"
  validate $?

  print $NC "Validating first message..."
  ssh_cmd "cat $MQTT_LOGFILE" > $LOCAL_LOGFILE
  validate_json $LOCAL_LOGFILE

  # publish second test message
  print $NC "Publishing second message..."
  ssh_cmd "rm -f $MQTT_LOGFILE"
  mqtt_publish test2 "$JSON2"
  validate $?

  print $NC "Validating second message..."
  ssh_cmd "cat $MQTT_LOGFILE" > $LOCAL_LOGFILE
  validate_json $LOCAL_LOGFILE

  # publish both messages (result is not json anymore!)
  print $NC "Publishing both messages..."
  ssh_cmd "rm -f $MQTT_LOGFILE"
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
  ssh_cmd "cat $MQTT_LOGFILE" > $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$JSON12"

  # remove logfile
  ssh_cmd "rm -f $MQTT_LOGFILE"
  rm -f $LOCAL_LOGFILE

  print $GREEN "Finished publish-subscribe test"
}

# check if kernel module is loaded
test_mqttlog_module(){
  print $YELLOW "Verify mqttlog kernel module is running"
  ssh_cmd 'lsmod | grep -wq mqttlog'

  validate $?
  print $GREEN "Verified mqttlog kernel module is running"
}

run_parse_test(){
  print $YELLOW "Run parse test"

  print $NC "Validating int payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": 123 }' > /dev/mqttlog"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : 123"
  validate $?

  print $NC "Validating null payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": null }' > /dev/mqttlog"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : null"
  validate $?

  print $NC "Validating string payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": \"ASDF\" }' > /dev/mqttlog"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : \"ASDF\""
  validate $?

  print $NC "Validating array payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": [1,2,3] }' > /dev/mqttlog"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : \[1,2,3\]"
  validate $?

  print $NC "Validating object payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": {\"A\": 2, \"B\": 3, \"C\": 0} }' > /dev/mqttlog"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : {\"A\": 2, \"B\": 3, \"C\": 0}"
  validate $?

  print $GREEN "Finished parse test"
}


############################
## accepted script arguments

case "$1" in
  build)
    build_image
    ;;
  start)
    start_qemu
    ;;
  stop)
    stop_qemu
    ;;
  ssh)
    login_ssh
    ;;
  mqtt-subscriber)
    test_mqtt_subscriber
    ;;
  mqtt-pub-sub)
    run_publish_subscribe_test
    ;;
  mqttlog-module)
    test_mqttlog_module
    ;;
  mqttlog-parse)
    run_parse_test
    ;;
  *)
    echo "Usage: $0 {build|start|stop|ssh|mqtt-subscriber|mqtt-pub-sub|mqttlog-module|mqttlog-parse}"
    exit 1
    ;;
esac

exit 0