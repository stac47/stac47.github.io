---
layout: post
title:  "Fedora Notes"
tags: linux fedora
---

# {{ page.title }}

As my MacBook Pro edition 2013 fell out of support from Apple and I did not
want to use a computer without security updates, I decided to replace the
proprietary OS by a GNU/Linux one. And as I wanted to give a try to the Fedora
distribution, I did not install my beloved Debian.

This page gathers some notes I took about the configuration and the tools
provided by that distribution.

I must say that I had no problem installing the version 38 of Fedora: I
prepared a USB stick with the recommended tool I installed on my MacOS
MacBook Pro and followed the steps.

## Post Installation Setup

### Display Grub2 Menu

By default, the Grub menu is skipped and automatically boots with the default
kernel. To display it:

```
sudo grub2-editenv - unset menu_auto_hide
```

### Keyboard Layout

Apple keyboard is handled by the kernel module called `hid_apple`. This ones
accepts a bunch of parameters amongst which two are interesting to me:

* `fnmode` which controls how the `fn` key should behave (0=disabled, 1=press
  `fn` to access the F1, F2... keys, 2=the converse of 1, press `fn` to
  access the alternative functions of the F1, F2... keys). My preference is the
  option 2.
* `iso_layout` to have the key `~` next to the upcase key (instead of below the
  `Esc` key).

So I created the file `/etc/modprobe.d/hid_apple.conf` and added the following:

```
options hid_apple fnmode=2
options hid_apple iso_layout=0
```

Next, to make this persistent, I regenerated the `initramfs` using `dracut`:

```
% sudo dracut --force
```

### Fix NVidia Blurry Display on Wake Up

Sometimes, some parts of the gnome desktop display blurry. This is linked to a
but to the proprietary NVidia drivers. To work around this, we can restart the
display manager by pressing Alt+f2 and entering the `r` command.

Otherwise, something to test if the issue is too boring is to disable some
power management options in the NVidia drivers configuration
`/usr/lib/modprobe.d/nvidia-power-management.conf`:

```
options nvidia NVreg_PreserveVideoMemoryAllocations=0
```

### Fix Wrong Battery Percentage

Sometimes, when I wake my computer up, the battery level is wrong showing me a
few percents when my battery is actually fully charged.

This is a tiny glitch in `upower` service. Rebooting it fixes the bug:

```
% sudo systemctl restart upower
```

### Fix Trackpad

I still do not found out why some times, the trackpad does not respond anymore.
Looking at the system logs, I can only see the following error repeating each
time I touch the trackpad:

```
```

If this happen, simply reloading the kernel module fix the problem:

```
% sudo rmmod bcm5974
% sudo modprobe bcm5974
```

### Remap CapsLock key

Remapping key is not something we can do by default via the Settings panel:
those hackers twaks are accessible with a package called `gnome-tweaks`. When
installed, run the command `gnome-tweaks` from a terminal or simply run the
`Tweaks` application via the icon.

Then follow `Keyboard > Additional Layout Options` and in the section `Ctrl
position` select `Caps Lock as Ctrl`.

## Tools

### DNF

#### Listing Package Files

Sometimes, we may be interested in the files that a package will install on your
system. This can be achieved with the following command:

```
% dnf repoquery -l postgresql
Last metadata expiration check: 0:15:20 ago on Sat 21 Oct 2023 06:14:05 AM CEST.
/usr/bin/clusterdb
/usr/bin/createdb
/usr/bin/createuser
/usr/bin/dropdb
[...]
```
