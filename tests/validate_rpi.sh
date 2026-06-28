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

  # create second buildroot folder for rpi build
  if [ ! -d buildroot_rpi ]; then
    print $YELLOW "Checkout buildroot into buildroot_rpi folder"
    git clone https://gitlab.com/buildroot.org/buildroot -b 2026.05 buildroot_rpi
  fi

  # compile buildroot image
  make QEMU_BUILD=false BUILDROOT_DIR=buildroot_rpi DEFCONFIG_CONFIG=.config_rpi WIFI_SSID=XYZ WIFI_PWD=123456789
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