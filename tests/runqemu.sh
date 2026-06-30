#!/bin/bash

###
# Script to run qemu:
#   Device needs access to 192.168.0.xx, so we can't use an emulated Pi Zero (has no networking interface)
#   Instead, we switch to '-M versatilepb' board and use a virtual network bridge on the host

###
# Mosquitto config on host (/etc/mosquitto/mosquitto.conf):
#   listener 1883 0.0.0.0
#   allow_anonymous true

###
# qemu instance is available via: 'ssh root@localhost -p 2222'
# host is available via ip address '10.0.2.2'


CURRENT_DIR=$(dirname ${BASH_SOURCE[0]})
BUILDROOT_DIR=${CURRENT_DIR}/../buildroot/output/images

qemu-system-arm \
  -M versatilepb \
  -kernel ${BUILDROOT_DIR}/zImage \
  -dtb ${BUILDROOT_DIR}/versatile-pb.dtb \
  -drive file=${BUILDROOT_DIR}/rootfs.ext2,if=scsi,format=raw \
  -append "rootwait root=/dev/sda console=ttyAMA0,115200" \
  -net nic,model=rtl8139 \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic