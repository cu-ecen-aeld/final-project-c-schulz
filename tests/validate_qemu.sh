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
    make ${QEMU_BUILD_CONFIG} clean-packages
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

  # restart ringbuffer
  ssh_cmd "/etc/init.d/S98mqttlog restart"

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
  "sequence" : 0,
  "timestamp": ***,
  "topic"    : "test-topic1",
  "payload"  : 123
}
{
  "sequence" : 1,
  "timestamp": ***,
  "topic"    : "test-topic2",
  "payload"  : [1,2,3]
}
{
  "sequence" : 2,
  "timestamp": ***,
  "topic"    : "test-topic3",
  "payload"  : {"A": 2, "B": 3, "C": 0}
}'
  ssh_cmd "head -n18 $MQTT_DEVICE" > $LOCAL_LOGFILE
  remove_timestamp_json $LOCAL_LOGFILE

  validate_content $LOCAL_LOGFILE "$OUT"
  rm -f $LOCAL_LOGFILE

  print $GREEN "Finished cat test"
}

run_mqttlog_buffer_size_test(){
  print $YELLOW "Run buffer size test"

  LOCAL_LOGFILE=$(basename $MQTT_DEVICE)
  rm -f $LOCAL_LOGFILE

  # restart ringbuffer
  ssh_cmd "/etc/init.d/S98mqttlog restart"

  # ringbuffer size is 128, so we push >128 elements
  for i in {0..150}; do
    ssh_cmd "echo '{ \"topic\": \"test-topic\", \"payload\": 123 }' > $MQTT_DEVICE"
    validate $?
  done
  sync

  # obtain first sequence id remaining in ringbuffer
  ssh_cmd "head -n2 $MQTT_DEVICE" > $LOCAL_LOGFILE
  SEQ_FIRST=$(egrep sequence $LOCAL_LOGFILE | head -n 1 | awk '{print $3}' | cut -d , -f 1)
  SEQ_FIRST=$(echo "$SEQ_FIRST - 1" | bc)   # -1 because this is already one of our 150 messages

  # last sequence id equals iteration number because mqttlog was restarted
  SEQ_LAST=150
  print $NC "Sequence ids: $SEQ_FIRST - $SEQ_LAST"

  print $NC "Validating sequence ids..."
  [ $(echo "$SEQ_LAST - $SEQ_FIRST" | bc) -eq 128 ]
  validate $?

  # remove logfile copy
  rm -f $LOCAL_LOGFILE
  print $GREEN "Finished buffer size test"
}

run_mqttlog_publish_subscribe_test(){

  print $YELLOW "Run publish-subscribe test via $MQTT_DEVICE"

  JSON1='{"text": "HI!"}'
  JSON2='{"text": "BYE!"}'
  LOCAL_LOGFILE=$(basename $MQTT_DEVICE)

  # restart ringbuffer
  ssh_cmd "/etc/init.d/S98mqttlog restart"

  CONTENT1='{
  "sequence" : 0,
  "timestamp": ***,
  "topic"    : "test1",
  "payload"  : {"text": "HI!"}
}'
  CONTENT12='{
  "sequence" : 0,
  "timestamp": ***,
  "topic"    : "test1",
  "payload"  : {"text": "HI!"}
}
{
  "sequence" : 1,
  "timestamp": ***,
  "topic"    : "test2",
  "payload"  : {"text": "BYE!"}
}'
  CONTENT1212='{
  "sequence" : 0,
  "timestamp": ***,
  "topic"    : "test1",
  "payload"  : {"text": "HI!"}
}
{
  "sequence" : 1,
  "timestamp": ***,
  "topic"    : "test2",
  "payload"  : {"text": "BYE!"}
}
{
  "sequence" : 2,
  "timestamp": ***,
  "topic"    : "test1",
  "payload"  : {"text": "HI!"}
}
{
  "sequence" : 3,
  "timestamp": ***,
  "topic"    : "test2",
  "payload"  : {"text": "BYE!"}
}'

  # # clear ringbuffer
  # ssh_cmd "cat $MQTT_DEVICE" 1> /dev/null 2> /dev/null

  # publish first test message
  print $NC "Publishing first message..."
  mqtt_publish test1 "$JSON1"
  validate $?

  print $NC "Validating first message..."
  ssh_cmd "head -n6 $MQTT_DEVICE" > $LOCAL_LOGFILE
  remove_timestamp_json $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT1"

  # publish second test message
  print $NC "Publishing second message..."
  mqtt_publish test2 "$JSON2"
  validate $?

  print $NC "Validating second message..."
  ssh_cmd "head -n12 $MQTT_DEVICE" > $LOCAL_LOGFILE
  remove_timestamp_json $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT12"

  # publish both messages
  print $NC "Publishing both messages..."
  mqtt_publish test1 "$JSON1"
  validate $?
  mqtt_publish test2 "$JSON2"
  validate $?

  # validate resulting content
  print $NC "Validating both messages..."
  ssh_cmd "head -n24 $MQTT_DEVICE" > $LOCAL_LOGFILE
  remove_timestamp_json $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT1212"

  # remove logfile copy
  rm -f $LOCAL_LOGFILE
  print $GREEN "Finished publish-subscribe test via $MQTT_DEVICE"
}

run_mqttlogctl_test(){
  print $YELLOW "Run tests with mqttlogctl"
  LOCAL_LOGFILE=$(basename $MQTT_LOGFILE)

  #####
  # restart ringbuffer
  ssh_cmd "/etc/init.d/S98mqttlog restart"
  rm -f $LOCAL_LOGFILE

  # publish small json message
  print $NC "Publishing small JSON message.."
  mqtt_publish test/topic1 '{"text": "HI!"}'
  validate $?

  # publish non-json message
  print $NC "Publishing non-JSON message.."
  mqtt_publish test/topics/topic2 'asdfBullshit123'
  validate $?

  # publish large json file
  print $NC "Publishing large JSON message.."
  mqtt_publish_file test ${TEST_DIR}/example.json
  validate $?

  #####
  # test dump format, follow and limit
  # 1) mqttlogctl dump
  print $NC "Validating 'mqttlogctl dump'..."
  ssh_cmd "mqttlogctl dump" > $LOCAL_LOGFILE
  validate $?
  CONTENT_DUMP='[1970-01-01 *** UTC] #0 test/topic1
{"text": "HI!"}

[1970-01-01 *** UTC] #1 test/topics/topic2
asdfBullshit123

[1970-01-01 *** UTC] #2 test
{
  "id": 1042,
  "username": "coder123",
  "isActive": true,
  "score": 95.5,
  "contact": {
    "email": "coder123@example.com",
    "phone": "+49-7125-12345"
  },
  "roles": ["User", "Moderator"],
  "subscription": null
}'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_DUMP"

  # 2) mqttlogctl dump -j
  print $NC "Validating 'mqttlogctl dump -j'..."
  ssh_cmd "mqttlogctl dump -j" > $LOCAL_LOGFILE
  validate $?
  CONTENT_DUMP_JSON='{
  "payload": {
    "text": "HI!"
  },
  "sequence": 0,
  "timestamp": "1970-01-01 *** UTC",
  "topic": "test/topic1"
}
{
  "payload": "asdfBullshit123",
  "sequence": 1,
  "timestamp": "1970-01-01 *** UTC",
  "topic": "test/topics/topic2"
}
{
  "payload": {
    "contact": {
      "email": "coder123@example.com",
      "phone": "+49-7125-12345"
    },
    "id": 1042,
    "isActive": true,
    "roles": [
      "User",
      "Moderator"
    ],
    "score": 95.5,
    "subscription": null,
    "username": "coder123"
  },
  "sequence": 2,
  "timestamp": "1970-01-01 *** UTC",
  "topic": "test"
}'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_DUMP_JSON"

  # 3) mqttlogctl dump -l 2
  print $NC "Validating 'mqttlogctl dump -l 2'..."
  ssh_cmd "mqttlogctl dump -l 2" > $LOCAL_LOGFILE
  validate $?
  CONTENT_DUMP_L2='[1970-01-01 *** UTC] #0 test/topic1
{"text": "HI!"}

[1970-01-01 *** UTC] #1 test/topics/topic2
asdfBullshit123'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_DUMP_L2"

  # 4) mqttlogctl dump -l 2 -f
  print $NC "Validating 'mqttlogctl dump -l 2 -f'..."
  try_cmd_for 2s 1 "ssh_cmd 'mqttlogctl dump -l 2 -f'" > $LOCAL_LOGFILE
  remove_timestamp_utc $LOCAL_LOGFILE
  sed -i -e "1d" $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_DUMP_L2"

  #####
  # test topic filter
  # 5) mqttlogctl dump -t test -j
  print $NC "Validating 'mqttlogctl dump -t test -j'..."
  ssh_cmd "mqttlogctl dump -t test -j" > $LOCAL_LOGFILE
  validate $?
  CONTENT_FILTER_STRING_JSON='{
  "payload": {
    "contact": {
      "email": "coder123@example.com",
      "phone": "+49-7125-12345"
    },
    "id": 1042,
    "isActive": true,
    "roles": [
      "User",
      "Moderator"
    ],
    "score": 95.5,
    "subscription": null,
    "username": "coder123"
  },
  "sequence": 2,
  "timestamp": "1970-01-01 *** UTC",
  "topic": "test"
}'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_json $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_STRING_JSON"

  # 6) mqttlogctl dump -t #
  print $NC "Validating 'mqttlogctl dump -t \"#\""
  ssh_cmd "mqttlogctl dump -t \"#\"" > $LOCAL_LOGFILE
  validate $?
  CONTENT_FILTER_HASH=$CONTENT_DUMP
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_HASH"

  # 7) mqttlogctl dump -t test/#
  print $NC "Validating 'mqttlogctl dump -t \"test/#\""
  ssh_cmd "mqttlogctl dump -t \"test/#\"" > $LOCAL_LOGFILE
  validate $?
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_HASH"

  # 8) mqttlogctl dump -t test/+
  print $NC "Validating 'mqttlogctl dump -t test/+"
  ssh_cmd "mqttlogctl dump -t test/+" > $LOCAL_LOGFILE
  validate $?
  CONTENT_FILTER_PLUS='[1970-01-01 *** UTC] #0 test/topic1
{"text": "HI!"}'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_PLUS"

  # 9) mqttlogctl dump -t test/+/topic2
  print $NC "Validating 'mqttlogctl dump -t test/+/topic2"
  ssh_cmd "mqttlogctl dump -t test/+/topic2" > $LOCAL_LOGFILE
  validate $?
  CONTENT_FILTER_SUB_PLUS='[1970-01-01 *** UTC] #1 test/topics/topic2
asdfBullshit123'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_SUB_PLUS"

  # 10) mqttlogctl dump -t +/topic1
  print $NC "Validating 'mqttlogctl dump -t +/topic1"
  ssh_cmd "mqttlogctl dump -t +/topic1" > $LOCAL_LOGFILE
  validate $?
  CONTENT_FILTER_PLUS_SUB='[1970-01-01 *** UTC] #0 test/topic1
{"text": "HI!"}'
  remove_timestamp_utc $LOCAL_LOGFILE
  validate_content $LOCAL_LOGFILE "$CONTENT_FILTER_PLUS_SUB"

  #####
  # test reset and stats
  # 11) mqttlogctl stats
  print $NC "Validating 'mqttlogctl stats'..."
  ssh_cmd "mqttlogctl stats" > $LOCAL_LOGFILE
  validate $?
  CONTENT_STATS='Events written : 3
Events dropped : 0
Buffer size    : 128
Buffer used    : 3'
  validate_content $LOCAL_LOGFILE "$CONTENT_STATS"

  # 12) mqttlogctl reset
  print $NC "Validating 'mqttlogctl reset'..."
  ssh_cmd "mqttlogctl reset"
  validate $?

  # 13) mqttlogctl dump
  print $NC "Validating 'mqttlogctl dump'..."
  ssh_cmd "mqttlogctl dump" > $LOCAL_LOGFILE
  validate $?
  validate_content $LOCAL_LOGFILE ""

  # 14) mqttlogctl stats
  print $NC "Validating 'mqttlogctl stats'..."
  ssh_cmd "mqttlogctl stats" > $LOCAL_LOGFILE
  validate $?
  CONTENT_STATS2='Events written : 3
Events dropped : 0
Buffer size    : 128
Buffer used    : 0'
  validate_content $LOCAL_LOGFILE "$CONTENT_STATS2"

  #####
  rm -f $LOCAL_LOGFILE
  print $GREEN "Finished tests with mqttlogctl"
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
  mqttlogctl)
    run_mqttlogctl_test
    ;;
  *)
    echo "Usage: $0 {build|start|stop|ssh|mqtt-subscriber|mqtt-pub-sub|mqttlog-module|mqttlog-parse|mqttlog-cat|mqttlog-buffer-size|mqttlog-pub-sub|mqttlogctl}"
    exit 1
    ;;
esac

exit 0