#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..
MQTT_LOGFILE=/tmp/mqttlog
MQTT_DEVICE=/dev/mqttlog

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
run_mqtt_publish_subscribe_test(){
  print $YELLOW "Run publish-subscribe test via $MQTT_LOGFILE"

  print $NC "Starting second mqtt subscriber that prints to log file..."
  START_CMD="/usr/bin/mqtt_subscriber -d -h mqtt://10.0.2.2:1883 -f $MQTT_LOGFILE"
  ssh_cmd "$START_CMD"
  validate $?

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

  print $NC "Stopping second mqtt subscriber..."
  PID=$(ssh_cmd "ps -a | grep \"$START_CMD\"" | head -n 1 | awk {'print $1'})
  ssh_cmd "kill -SIGINT $PID"
  validate $?

  print $GREEN "Finished publish-subscribe test via $MQTT_LOGFILE"
}

# check if kernel module is loaded
test_mqttlog_module(){
  print $YELLOW "Verify mqttlog kernel module is running"
  ssh_cmd 'lsmod | grep -wq mqttlog'

  validate $?
  print $GREEN "Verified mqttlog kernel module is running"
}

run_mqttlog_parse_test(){
  print $YELLOW "Run parse test"

  print $NC "Validating int payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": 123 }' > $MQTT_DEVICE"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : 123"
  validate $?

  print $NC "Validating null payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": null }' > $MQTT_DEVICE"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : null"
  validate $?

  print $NC "Validating string payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": \"ASDF\" }' > $MQTT_DEVICE"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : \"ASDF\""
  validate $?

  print $NC "Validating array payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": [1,2,3] }' > $MQTT_DEVICE"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : \[1,2,3\]"
  validate $?

  print $NC "Validating object payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": {\"A\": 2, \"B\": 3, \"C\": 0} }' > $MQTT_DEVICE"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "topic    : test-topic"
  validate $?
  ssh_cmd "tail -n10 /var/log/messages" | grep "payload  : {\"A\": 2, \"B\": 3, \"C\": 0}"
  validate $?

  print $GREEN "Finished parse test"
}

run_mqttlog_cat_test(){
  print $YELLOW "Run cat test"
  LOCAL_LOGFILE=$(basename $MQTT_DEVICE)

  # clear ringbuffer
  # TODO
  ssh_cmd "/etc/init.d/S98mqttlog restart"
  # ssh_cmd "cat $MQTT_DEVICE" 1> /dev/null 2> /dev/null

  print $NC "Echoing int payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic1\", \"payload\": 123 }' > $MQTT_DEVICE"
  validate $?

  print $NC "Echoing array payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic2\", \"payload\": [1,2,3] }' > $MQTT_DEVICE"
  validate $?

  print $NC "Echoing object payload..."
  ssh_cmd "echo '{ \"topic\": \"test-topic3\", \"payload\": {\"A\": 2, \"B\": 3, \"C\": 0} }' > $MQTT_DEVICE"
  validate $?

  print $NC "Validating cat..."
  rm -f $LOCAL_LOGFILE
  OUT='{
  sequence : ***,
  timestamp: ***,
  topic    : test-topic1,
  payload  : 123
}
{
  sequence : ***,
  timestamp: ***,
  topic    : test-topic2,
  payload  : [1,2,3]
}
{
  sequence : ***,
  timestamp: ***,
  topic    : test-topic3,
  payload  : {"A": 2, "B": 3, "C": 0}
}'
  ssh_cmd "cat $MQTT_DEVICE" > $LOCAL_LOGFILE
  sed -i "s/sequence :.*,/sequence : ***,/g" $LOCAL_LOGFILE
  sed -i "s/timestamp:.*,/timestamp: ***,/g" $LOCAL_LOGFILE

  validate_content $LOCAL_LOGFILE "$OUT"
  rm -f $LOCAL_LOGFILE

  print $GREEN "Finished cat test"
}

run_mqttlog_buffer_size_test(){
  print $YELLOW "Run buffer size test"

  LOCAL_LOGFILE=$(basename $MQTT_DEVICE)
  rm -f $LOCAL_LOGFILE

  # ringbuffer size is 128, so we push >128 elements
  for i in {1..150}; do
    ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": 123 }' > $MQTT_DEVICE"
    validate $?
  done
  sync


  # OLD AND DEPRECATED:
  # # execute cat in a loop after provoking overflow
  # # required multiple times because buffer is too small for all messages
  # while ssh_cmd "cat $MQTT_DEVICE" > $LOCAL_LOGFILE; do
  #   if [ -z $SEQ_FIRST ]; then
  #     SEQ_FIRST=$(egrep sequence $LOCAL_LOGFILE | head -n 1 | awk '{print $3}' | cut -d , -f 1)
  #     SEQ_FIRST=$(echo "$SEQ_FIRST - 1" | bc)   # -1 because this is already one of our 150 messages
  #   fi
  #   SEQ_LAST=$(egrep sequence $LOCAL_LOGFILE | tail -n 1 | awk '{print $3}' | cut -d , -f 1)
  # done


  # TODO:
  # execute custom program 'mqttlog_dump' to retreive all messages currently stored in ringbuffer

  # print $NC "Sequence ids: $SEQ_FIRST - $SEQ_LAST"

  # print $NC "Validating sequence ids..."
  # [ $(echo "$SEQ_LAST - $SEQ_FIRST" | bc) -eq 128 ]
  # validate $?

  # remove logfile copy
  rm -f $LOCAL_LOGFILE
  print $GREEN "Finished buffer size test"
}

run_mqttlog_publish_subscribe_test(){

  print $YELLOW "Run publish-subscribe test via $MQTT_DEVICE"

  JSON1='{"text": "HI!"}'
  JSON2='{"text": "BYE!"}'
  LOCAL_LOGFILE=$(basename $MQTT_DEVICE)

  # clear ringbuffer
  # TODO
  ssh_cmd "/etc/init.d/S98mqttlog restart"

  CONTENT1='{
  sequence : ***,
  timestamp: ***,
  topic    : test1,
  payload  : {"text": "HI!"}
}'
  CONTENT2='{
  sequence : ***,
  timestamp: ***,
  topic    : test2,
  payload  : {"text": "BYE!"}
}'
  CONTENT12='{
  sequence : ***,
  timestamp: ***,
  topic    : test1,
  payload  : {"text": "HI!"}
}
{
  sequence : ***,
  timestamp: ***,
  topic    : test2,
  payload  : {"text": "BYE!"}
}'
  CONTENT1212="$CONTENT12
$CONTENT12"

  # clear ringbuffer
  ssh_cmd "cat $MQTT_DEVICE" 1> /dev/null 2> /dev/null

  # publish first test message
  print $NC "Publishing first message..."
  mqtt_publish test1 "$JSON1"
  validate $?

  print $NC "Validating first message..."
  ssh_cmd "cat $MQTT_DEVICE" > $LOCAL_LOGFILE
  sed -i "s/sequence :.*,/sequence : ***,/g" $LOCAL_LOGFILE
  sed -i "s/timestamp:.*,/timestamp: ***,/g" $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT1"

  # publish second test message
  print $NC "Publishing second message..."
  mqtt_publish test2 "$JSON2"
  validate $?

  print $NC "Validating second message..."
  ssh_cmd "cat $MQTT_DEVICE" > $LOCAL_LOGFILE
  sed -i "s/sequence :.*,/sequence : ***,/g" $LOCAL_LOGFILE
  sed -i "s/timestamp:.*,/timestamp: ***,/g" $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT12"

  # publish both messages
  print $NC "Publishing both messages..."
  mqtt_publish test1 "$JSON1"
  validate $?
  mqtt_publish test2 "$JSON2"
  validate $?

  # validate resulting content
  print $NC "Validating both messages..."
  ssh_cmd "cat $MQTT_DEVICE" > $LOCAL_LOGFILE
  sed -i "s/sequence :.*,/sequence : ***,/g" $LOCAL_LOGFILE
  sed -i "s/timestamp:.*,/timestamp: ***,/g" $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT1212"

  # remove logfile copy
  rm -f $LOCAL_LOGFILE
  print $GREEN "Finished publish-subscribe test via $MQTT_DEVICE"
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
    run_mqtt_publish_subscribe_test
    ;;
  mqttlog-module)
    test_mqttlog_module
    ;;
  mqttlog-parse)
    run_mqttlog_parse_test
    ;;
  mqttlog-cat)
    run_mqttlog_cat_test
    ;;
  mqttlog-buffer-size)
    run_mqttlog_buffer_size_test
    ;;
  mqttlog-pub-sub)
    run_mqttlog_publish_subscribe_test
    ;;
  *)
    echo "Usage: $0 {build|start|stop|ssh|mqtt-subscriber|mqtt-pub-sub|mqttlog-module|mqttlog-parse|mqttlog-cat|mqttlog-buffer-size|mqttlog-pub-sub}"
    exit 1
    ;;
esac

exit 0