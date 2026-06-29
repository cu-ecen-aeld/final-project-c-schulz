#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..

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
    #make clean ${QEMU_BUILD_CONFIG}
    validate $?
  else
    print $YELLOW "Re-use old build, config has not changed"
  fi

  # compile buildroot image
  #make ${QEMU_BUILD_CONFIG}
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
  mqtt)
    test_mqtt_subscriber
    ;;
  *)
    echo "Usage: $0 {build|start|stop|ssh|mqtt}"
    exit 1
    ;;
esac

exit 0