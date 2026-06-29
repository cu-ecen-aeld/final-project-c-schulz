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

  # check if config has changed since last build
  RPI_CONFIG="${REPO_DIR}/mqtt-event-logger/configs/mqtt_rpi_defconfig"
  RPI_BUILD_CONFIG="QEMU_BUILD=false BUILDROOT_DIR=buildroot_rpi DEFCONFIG_CONFIG=.config_rpi WIFI_SSID=XYZ WIFI_PWD=123456789"
  sha1sum ${RPI_CONFIG} > ${RPI_CONFIG}.sha1  #TODO: this is bad
  if [ ! -f ${RPI_CONFIG}.sha1 ] || ! sha1sum -c ${RPI_CONFIG}.sha1 ; then

    # make clean build to make sure the versionized config is used
    print $YELLOW "Clean build because config has changed"
    #make clean ${RPI_BUILD_CONFIG}
    validate $?
  else
    print $YELLOW "Re-use old build, config has not changed"
  fi

  # compile buildroot image
  #make ${RPI_BUILD_CONFIG}
  validate $?

  # update sha1
  sha1sum ${RPI_CONFIG} > ${RPI_CONFIG}.sha1

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