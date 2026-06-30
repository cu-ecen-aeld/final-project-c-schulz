#!/bin/bash

# define different colors
# See https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m' # No Color

##################
# helper functions

# print $color $text: print text in a specific color
print(){
  color=$1
  text=$2
  printf "${color}>>> ${text} <<<${NC}\n"
}
export -f print

# validate $rc: if error occurs, print it and exit
validate(){
  if [ $1 -ne 0 ]; then
    print $RED "Test failed with error: $1"
    exit 1
  fi
}
export -f validate

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
export -f try_cmd_for

# mqtt_publish $topic $message: publish string message on provided topic
mqtt_publish(){
  topic=$1
  message=$2
  mqtt pub -t $topic -m "$message" 2> /dev/null
}
export -f mqtt_publish

# validate_json $file: check whether file contains valid json
validate_json(){
  file=$1
  python3 -m json.tool $file > /dev/null
  validate $?
}
export -f validate_json

# validate_content $file $text: check whether file content and text are identical
validate_content(){
  file=$1
  text=$2
  [[ "$(cat $file)" = "$text" ]]
  validate $?
}
export -f validate_content

# scp_file $cmd: copy file from remote
scp_file(){
	file=$1
  scp -P 2222 root@localhost:$file .
}
export -f scp_file
