#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=$(dirname ${TEST_DIR})


##################
# helper functions

# validate $rc: if error occurs, print it and exit
validate(){
  if [ $1 -ne 0 ]; then
    echo "Test failed with error: $1"
    exit 1
  fi
}

# ssh_cmd $cmd: execute command in qemu via ssh
ssh_cmd(){
	cmd=$1
	sshpass -p 'root' ssh -o StrictHostKeyChecking=no root@localhost -p 2222 ${cmd}
}

# try_cmd_for $time $sleep $cmd: repeatedly execute $cmd until it succeeds, with timeout and sleep
try_cmd_for(){
  timeout_duration=$1
  sleep_duration=$2
  cmd=$3
  echo $timeout_duration -- $sleep_duration -- $cmd
  timeout $timeout_duration bash -c "until $cmd; do echo $cmd; sleep $sleep_duration; done"
}


#######################
## available test steps

# build buildroot image with qemu settings
build_image(){
  echo "Build buildroot image with qemu config"
  pushd $REPO_DIR

  # make config QEMU_BUILD=true
  # validate $?

  # make clean
  # validate $?

  make QEMU_BUILD=true
  validate $?

  popd
}

# boot image with qemu
start_qemu(){
  echo "Start qemu instance in background"
  ${TEST_DIR}/runqemu.sh &

  validate $?
  sleep 40
}

# kill qemu instance
stop_qemu(){
  echo "Stop qemu instance"
  killall -9 qemu-system-arm

  validate $?
}

# log in via ssh
login_ssh(){
  echo "Log in via ssh"

  ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "[localhost]:2222"
  try_cmd_for 180s 5 "tmpfile=`mktemp` && ssh_cmd 'exit' > ${tmpfile} 2>&1; cat ${tmpfile}"

  validate $?
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