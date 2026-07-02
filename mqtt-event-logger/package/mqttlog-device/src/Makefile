# SPDX-License-Identifier: GPL-2.0

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD       := $(shell pwd)

default:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) clean
#	rm -rf *.o *~ core .depend .*.cmd *.ko *.mod.c .tmp_versions