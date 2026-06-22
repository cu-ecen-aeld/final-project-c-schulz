#!/bin/bash

# Script to run qemu:
#   Device needs access to 192.168.0.xx, so we can't use an emulated Pi Zero (has no networking interface)
#   Instead, we switch to '-M versatilepb' board and use a virtual network bridge on the host

# Setup tap0 interface (host):
#   sudo ip tuntap add dev tap0 mode tap user $(whoami)     # create interface
#   sudo ip link set tap0 up                                # activate interface
#   sudo ip addr add 192.168.0.99/24 dev tap0               # manually assign IP

# Configure eth0 interface (qemu):
#   ip addr add 192.168.0.100/24 dev eth0
#   ip link set eth0 up

CURRENT_DIR=$(dirname ${BASH_SOURCE[0]})
BUILDROOT_DIR=${CURRENT_DIR}/../buildroot/output/images

qemu-system-arm \
  -M versatilepb \
  -cpu arm1176 \
  -m 256 \
  -kernel ${BUILDROOT_DIR}/zImage \
  -dtb ${BUILDROOT_DIR}/versatile-pb.dtb \
  -drive file=${BUILDROOT_DIR}/rootfs.ext2,if=scsi,format=raw \
  -append "rootwait root=/dev/sda console=ttyAMA0,115200" \
  -net nic \
  -net user,hostfwd=tcp::2222-:22 \
  -nographic

  # -netdev user,id=eth0,hostfwd=tcp::2222-:22 \
  # -device virtio-net-pci,netdev=eth0 \
  # -net nic,model=rtl8139 \
  # -net user \
  # -nographic


  # qemu-system-arm \
  #   -M versatilepb \
  #   -cpu arm1176 \
  #   -m 256 \
  #   -kernel zImage \
  #   -dtb versatile-pb.dtb \
  #   -drive file=rootfs.ext2,format=raw \
  #   -append "root=/dev/sda console=ttyAMA0,115200" \
  #   -net nic \
  #   -net user,hostfwd=tcp::2222-:22 \
  #   -serial stdio