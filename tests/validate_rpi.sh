#!/bin/bash

TEST_DIR=$(dirname ${BASH_SOURCE[0]})
REPO_DIR=${TEST_DIR}/..

source ${TEST_DIR}/validate_helpers.sh


#######################
## available test steps

# build buildroot image with rpi settings
build_image(){
  print $YELLOW "Build buildroot image with rpi config"
  pushd $REPO_DIR

  # make config QEMU_BUILD=false
  # validate $?

  # make clean
  # validate $?

  make QEMU_BUILD=false
  validate $?

  popd
  print $GREEN "Built buildroot image with rpi config"
}



############################
## accepted script arguments

case "$1" in
  build)
    build_image
    ;;
  *)
    echo "Usage: $0 {build}"
    exit 1
    ;;
esac

exit 0