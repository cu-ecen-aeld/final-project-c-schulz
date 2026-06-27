#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..

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


#######################
## available test steps

# build buildroot image with qemu settings
build_image(){
  print $YELLOW "Build buildroot image with qemu config"
  pushd $REPO_DIR

  # make config QEMU_BUILD=true
  # validate $?

  # make clean
  # validate $?

  make QEMU_BUILD=true
  validate $?

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
  *)
    echo "Usage: $0 {build|start|stop|ssh}"
    exit 1
    ;;
esac

exit 0