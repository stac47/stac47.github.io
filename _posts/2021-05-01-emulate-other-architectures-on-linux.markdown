---
layout: post
title:  "Emulate other Architectures on a Linux System"
date:   Mon 01 Mar 2021 09:13:13 AM UTC
categories: vim docker oci
---

Sometimes we have to port some programs to other architectures they were
designed for. If the project was written in Java or in a script language
(python, ruby...), the job is theoretically small: we generally trust the Java
Virtual Machine or the interpreter.

When is comes to compiled languages which compile software for a target
platform, it is a bit more complicated. The simplest way is to perform the
build and various checks on the targeted platform. For instance, if you have to
build your program for ARM 64, you will go on such a machine of this type and
perform the same operations you are used to on another platform.

The drawback of this approach is that you will have to invest (buy or rent) in
machines.

Another approach consists in cross-compiling your program: this means you will
use a special toolchain that will run, for instance, on `amd64` architecture
and produce code for another platform like `arm64`.

In that case, you will take advantage of the speed of a native compiler, so
that no performance strikes will be noticeable. The drawback of this approach
is that you will produce some binary files that are unusable on the host
machine. This means you will not be able to test the produced binaries on the
machine except if you emulate the target machine on the host.

The last approach I want to deal with in this article is to build and test the
compiled program on a single machine for another architecture by using
container technology.

## Emulation Basics

### Emulation and Virtualisation

There are some emulators that will emulate the target hardware and the target
OS. At that point, it is worth understanding the difference between
virtualisation and emulation.

VirtualBox creates virtual machines on top of the current hardware: if you run
Windows on an Intel x86_64 machine, you will be able to run GNU/Linux for
x86_64 architecture and not for `arm64`.

An emulator will make a program believing it is running on a machine
architecture is was build for: it will take the target architecture assembly
code ans translate it on the fly into the underlying machine architecture
instructions. The emulated OS will handle the memory allocated for the emulator
by the host. It will also be an interface to the devices that need to be used
by the emulated environment.

There are many examples of emulators. There are some emulators that will
emulate the Nintendo or Sega consoles on your MS Windows personal computer.
Another famous emulator is [QEMU][qemu_site] which we will use in this article.

Using an emulator comes with a performance penalty due to the additional
computation to translate instructions into something understandable by the host
machine and those instructions to translate comes from the emulated Operating
System and the program your are running.

### Qemu and user-mode emulation

Fortunately, there are rooms for improvement for particular cases we are
interested in in this article: we want to build binaries for different hardware
but still for GNU/Linux. In that case, [QEMU][emu_site] provides another
emulation mode called [user-mode emulation][qemu_user_mode_emulation]: it will
not emulate a full system, but only perform CPU instructions translation and
__capture the system calls__. That way, those __syscalls__ can be executed by
the underlying kernel. No need anymore a full hardware emulation and no need to
embed a full OS to run a program.

As an example, we will run `busybox` compiled for `arm64` on an
`amd64` machine.

```
> docker pull arm64v8/alpine
> container=$(docker create arm64v8/alpine)
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64) and no specific platform was requested
> docker cp ${container}:/bin/busybox .
> docker rm ${container}
> file ./busybox
busybox: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-aarch64.so.1, stripped
```

Trying to run it will fail:

```
> uname -m -o
x86_64 GNU/Linux
> ./busybox ls
zsh: exec format error: ./busybox
```

Let's install the `qemu-user-static` package on ubuntu and test if this works:

```
> sudo apt install qemu-user-static
...
> qemu-aarch64-static busybox ls
qemu-aarch64-static: Could not open '/lib/ld-musl-aarch64.so.1': No such file or directory
```

The error message is not the same. As seen above `busybox` is not statically
linked: the kernel will need to invoke the dynamic linker which is hard-coded in
the `.interp` ELF sections:

```
> readelf --segments ./busybox
...
  INTERP         0x000200 0x0000000000000200 0x0000000000000200 0x00001a0x00001a R   0x1
        [Requesting program interpreter: /lib/ld-musl-aarch64.so.1]
...
```

We can retrieve the interpreter from the same OCI image and create a symlink in
our `/lib` to the interpreter.

```
> sudo ln -s ./ld-musl-aarch64.so.1 /lib
> qemu-aarch64-static busybox ls
busybox
ls-musl-aarch64.so.1
```

Now it works. But there are two reasons why this is not convenient:
- we have to pollute our system with many files here and there that do not
  belong to the machine architecture. To cope with this, we can use any
  technology based on `chroot` like OCI container. It is what we will do.
- we have to explicitly call the emulator for each program we want to emulate:
  it will be a problem if we try to run a building script for instance.

Fortunately, this second point can be elegantly solved with the `binfmt_misc`
Linux Kernel [feature](binfmt_misc_doc)

## `binfmt_misc` Linux Kernel Feature

### Summary on Binary Execution

To run a program, the shell will `fork` itself and call an `exec` function
family which ends up into the system call `execve` which role is to really
execute the program.

The Kernel will validate the executable file, determine which handler to use,
replace the current in memory program (the forked one) with the one to execute,
prepare virtual memory, a new stack for execution...

By default, there are a few handlers that we use everyday:
- statically or dynamically linked ELF executables
- script files like python, bash scripts

The kernel will generally look at the first bytes of an executable and try to
find an handler for this magic sequence of bytes. For example, an ELF file
starts with the information on the file type (magic sequence `0x7fELF`),
architecture registries size (32/64 bits), the endianess, the target
architecture, the version of the ELF format...

If it is a statically linked program, the kernel can start the program directly
because there are no shared libraries to load beforehand. Otherwise, it will
transfer the execution responsibility to the dynamic linker in the `.interp`
section.

If the first characters are the famous __shebang__ `#!` character, the kernel
will read the line until the end and invoke the interpreter.

### Using `binfmt_misc`

The beauty of `binfmt_misc` is that you can register some new handlers in the
kernel. An example given by the [official documentation](binfmt_misc) is that
you can register [Wine](wine_site) which acts as a thin layer to adapt Windows
syscalls into Linux syscalls.

```
echo ':DOSWin:M::MZ::/usr/local/bin/wine:' > register
```

We could run the following command:

```
echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:' | sudo tee 
```

But this is automatically done when installing the package `qemu-user-static`
package though System V.

```
> cat /proc/sys/fs/binfmt_misc/qemu-aarch64
enabled
interpreter /usr/libexec/qemu-binfmt/aarch64-binfmt-P
flags: POCF
offset 0
magic 7f454c460201010000000000000000000200b700
mask ffffffffffffff00fffffffffffffffffeffffff
```

In essence, what this tells is that any files starting with the `magic` sequence
(with some flexibility provided by the `mask` bits set), will be run by `qemu`
user-mode emulation. We can spot int the `magic` field, the value `0xb7` which
is the code for ARM 64 architecture.

With this handler installed, we can transparently run the binary coming from
the ARM64 version of Alpine Operating System.

```
> ./busybox ls
busybox
ls-musl-aarch64.so.1
```

## Running a Container That Is Not Adapted For Your Machine.

### Why Using a Container ?

As explained when we run `busybox` for `arm64`, we also had to take the
standard C libraries implementation it was linked with and store it on your
system. Generally, a program can have many dependencies and you don't want to
pollute your system with binaries that are not adapted to your system.

We could store all the needed file into a dedicated directory and `chroot` into
that to run your program. It is basically what containers technologies do
(amongst other things).

### Running the Container

Running a container is no more than:

- `untar` the image somewhere and `chroot` in that new root
- executing a program with special flags to handle __namespaces__, __cgroups__
  to make the program it is alone on a fresh machine. Behind the scene,  the
  current process is `fork`ed with a Linux enhanced version called `clone` so
  that special flags are passed to the forked process and `execve` to execute
  the target process (the code is loaded, the stack is replaced by a new
  one...).

Hence, with `qemu-user-static` installed and the `binfmt_misc` handlers correctly
configured, running the `arm64v8/alpine` we tool `busybox`
from previously, should work transparently.

```
> docker run -it --rm arm64v8/alpine ls
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform (linux/amd64) and no specific platform was requested
bin    etc    lib    mnt    proc   run    srv    tmp    var
dev    home   media  opt    root   sbin   sys    usr
```

### Cross-Building Software

#### Building an OCI Image For The Target Platform

Building an OCI image consists in:

- adding some configuration layers (`ENV`, `CMD`, `ENTRYPOINT`, `LABEL`...)
- adding some files into the future container file system (`COPY`, `ADD`)
- running some commands (`RUN`): for this, a temporary container is run and on
  the command end, the changes to the file system are committed.

So building an image is also transparent except `COPY`ing files into the image
must be done with care especially for architecture dependent binaries.

```
ARG ARCH=amd64
FROM $ARCH/ubuntu:21.04
RUN apt update && \
    apt install -y \
        build-essential \
        wget && \
    apt clean
```

The `ARCH` argument gives the possibility to select the target architecture.
Building the image for `arm64` architecture is almost as usual:

```
> docker build --build-arg ARCH=arm64v8 -t crosstest .
```

Note that [Docker buildx](docker_buildx) provides great facilities to build
different images for different architectures and to publish __multi-arch
images__.

#### Building Emulation Penalty

Of course, emulation comes with a performance hit. If we build
[ZLib][zlib_site], we can compare the performances of the emulated toolchain
and the native one:

Emulated container:

```
root@a865374fcdfd:/workdir/zlib-1.2.11# uname -m
aarch64

root@a865374fcdfd:/workdir/zlib-1.2.11# time make
...
real    1m17.283s
user    1m14.287s
sys     0m3.240s

root@a865374fcdfd:/workdir/zlib-1.2.11# time make check
...
real    0m0.548s
user    0m0.582s
sys     0m0.090s
```

Native container:

```
root@383ca400c560:/workdir/zlib-1.2.11# uname -m
x86_64

root@383ca400c560:/workdir/zlib-1.2.11# time make
...
real    0m5.673s
user    0m4.937s
sys     0m0.726s

root@383ca400c560:/workdir/zlib-1.2.11# time make check
...
real    0m0.044s
user    0m0.026s
sys     0m0.024s

```

So in this very case, it is 15 to 20 times slower for building / running the
tests.

### What If Qemu Is Not Installed On The Host ?

So far, we needed to install `qemu` on the host and register the `binfmt_misc`
handler to automatically run the emulator. This is generally not a problem when
hacking on your own machine. But what if the build must be done on a build
machine which could be just a build node in Jenkins for example.

So either, all the nodes are installed with the `qemu-user-static` package. If
it is not the case, you have some chances to be able to bypass this limitation
by setting up everything is needed by a privileged container which would:

- open `qemu-$arch-static` executable at binary format registration time with
  the flag 'F'. This feature was added [here][binfmt_misc_flag_f]
- register the `binfmt_misc` handlers on the host

There are several initiatives to do this:

- [multiarch/qemu-user-static][multiarch_qemu]
- [tonistiigi/binfmt][tonistiigi_binfmt]

Once one of these container is run, any subsequent program execution that
requires the emulator will be run although it cannot be found on the file
system. The opened emulator will remain open until the binary format is
removed. In the meanwhile, the emulator will remain available if `chroot` is
used or if a program in run in a new mount namespace.

[qemu_site]: https://www.qemu.org/
[qemu_user_mode_emulation]: https://qemu-project.gitlab.io/qemu/user/main.html
[binfmt_misc_doc]: https://www.kernel.org/doc/html/latest/admin-guide/binfmt-misc.html
[wine_site]: https://www.winehq.org/
[docker_buildx]: https://docs.docker.com/buildx/working-with-buildx/
[zlib_site]: https://zlib.net/
[multiarch_qemu]: https://github.com/multiarch/qemu-user-static
[tonistiigi_binfmt]: https://github.com/tonistiigi/binfmt
[binfmt_misc_flag_f]: https://github.com/torvalds/linux/commit/948b701a607f123df92ed29084413e5dd8cda2ed
