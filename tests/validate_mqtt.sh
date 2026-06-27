#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..
MQTT_SUBSCRIBER_DIR=${REPO_DIR}/mqtt-event-logger/package/mqtt-subscriber
SRC_DIR=${MQTT_SUBSCRIBER_DIR}/src
BIN_DIR=${MQTT_SUBSCRIBER_DIR}/build/bin
MQTT_LOGFILE=/tmp/mqttlog

# define different colors
# See https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

##################
# helper functions

# print $color $text: print text in a specific color
print(){
  color=$1
  text=$2
  printf "${color}>>> ${text} <<<${NC}\n"
}

# validate $rc: if error occurs, print it and exit
validate(){
  if [ $1 -ne 0 ]; then
    print $RED "Test failed with error: $1"
    exit 1
  fi
}

# ssh_cmd $cmd: execute command in qemu via ssh
ssh_cmd(){
	cmd=$1
	sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@localhost -p 2222 ${cmd}
}
export -f ssh_cmd

# try_cmd_for $time $sleep $cmd: repeatedly execute $cmd until it succeeds, with timeout and sleep
try_cmd_for(){
  timeout_duration=$1
  sleep_duration=$2
  cmd=$3
  print $YELLOW "Try for $timeout_duration: $cmd"
  timeout $timeout_duration bash -c "until $cmd; do sleep $sleep_duration; done"
}

# publish string message on provided topic
mqtt_publish(){
  topic=$1
  message=$2
  mqtt pub -t $topic -m "$message" 2> /dev/null
}

validate_json(){
  file=$1
  python3 -m json.tool $file > /dev/null
  validate $?
}

validate_content(){
  file=$1
  text=$2
  [[ "$(cat $file)" = "$text" ]]
  validate $?
}


#######################
## available test steps

# build mqtt subscriber binary
build_mqtt_subscriber(){
  print $YELLOW "Build mqtt subscriber"
  pushd $SRC_DIR

  # build mqtt subscriber
  make
  validate $?

  popd
  print $GREEN "Built mqtt subscriber"
}

# run publish-subscribe test on mqtt subscriber
run_publish_subscribe_test(){
  print $YELLOW "Run publish-subscribe test"
  pushd $BIN_DIR

  JSON1='{"text": "HI!"}'
  JSON2='{"text": "BYE!"}'

  # start mqtt subscriber
  print $NC "Starting mqtt subscriber..."
  ./mqtt_subscriber -d -f $MQTT_LOGFILE
  validate $?

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

  # terminate mqtt subscriber
  print $NC "Stopping mqtt subscriber..."
  PID=$(pgrep -fa "./mqtt_subscriber -d -f $MQTT_LOGFILE" | awk {'print $1'})
  kill -SIGINT $PID
  validate $?

  # remove logfile
  rm -f $MQTT_LOGFILE

  popd
  print $GREEN "Finished publish-subscribe test"
}


############################
## accepted script arguments

case "$1" in
  build)
    build_mqtt_subscriber
    ;;
  pub-sub)
    run_publish_subscribe_test
    ;;
  *)
    echo "Usage: $0 {build|pub-sub}"
    exit 1
    ;;
esac

exit 0