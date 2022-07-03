---
layout: post
title:  "Debian SID in Virtualbox"
tags: linux debian virtualbox
---

# {{ page.title }}

I daily use a __Debian SID__ (Still In Development) in a __Virtualbox__ hosted
on a __MS-Windows__ system. As this version of GNU/Linux is updated almost every
day, it is not so uncommon that your embedded system does not work properly
after you updated it. For example, __Xorg__ is not able to fully use your screen
or the clipboard cannot be shared between the host and the guest.

The reason is that for the guest additions to work properly, it has to be
compiled with the current kernel of your system.

Here is an excerpt of the logs you can find in `/var/log/syslog` when you have
problems:

```
systemd[1]: Starting vboxadd.service...
vboxadd[430]: VirtualBox Guest Additions: Starting.
vboxadd[430]: VirtualBox Guest Additions: Building the VirtualBox Guest Additions kernel modules.
vboxadd[430]: This system is currently not set up to build kernel modules.
vboxadd[430]: Please install the Linux kernel "header" files matching the current kernel
vboxadd[430]: for adding new hardware support to the system.
vboxadd[430]: The distribution packages containing the headers are probably:
vboxadd[430]:     linux-headers-amd64 linux-headers-4.14.0-3-amd64
vboxadd[430]: modprobe vboxguest failed
vboxadd[430]: The log file /var/log/vboxadd-setup.log may contain further information.
systemd[1]: vboxadd.service: Main process exited, code=exited, status=1/FAILURE
systemd[1]: vboxadd.service: Failed with result 'exit-code'.
systemd[1]: Failed to start vboxadd.service.
systemd[1]: Starting vboxadd-service.service...
vboxadd-service[628]: vboxadd-service.sh: Starting VirtualBox Guest Addition service.
vboxadd-service.sh: Starting VirtualBox Guest Addition service.
vboxadd-service[628]: VirtualBox Additions module not loaded!
systemd[1]: vboxadd-service.service: Control process exited, code=exited status=1
systemd[1]: vboxadd-service.service: Failed with result 'exit-code'.
systemd[1]: Failed to start vboxadd-service.service.
```

While these lines are crystal clear, I write here the solution to help my failing memory:

1. Install your distribution kernel headers

        sudo ap-get install linux-headers-$(uname -r)

2. Mount the VBoxGuestAdditions volume and run the install script

        sudo sh /media/cdrom/VBoxLinuxAdditions.run

In case the second operation fails, you can find the compilation step logs in
`/var/log/vboxadd-setup.log`.

If the generated kernel module fails to load, you can find the reason of such a
failure with the following command:

    systemctl status vboxadd.service
