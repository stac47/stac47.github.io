---
layout: post
title:  "Debugging a Go Program That Read From Stdin With Delve"
tags: go delve debug
---

# {{ page.title }}

Sometimes you have some programs that read their input from the standard input.
Generally a convenient way to pass the inputs is to pipe to the program like
this:

```
> cat testcase.txt | go run myprogram.go
```

Now how to investigate a bug with delve ? Although this quite simple with the
GNU Debugger (gdb) for your C-like programs, it is not that easy in the Go
world.

With GDB, the only thing to do was:

```
> gdb myprogram
gdb> run < input.txt
...
```

At the time of writting, this issue in not handled correctly by delve (see
issues already reported in 2015 with issue 65, and reported from time to time
here and there).

The workaround we have right now is the following:

On one terminal (terminal 1), you run delve as a debugging server with the
`--headless` option.

```
> dlv debug --headless --listen :4747 myprogram.go
API server listening at: [::]:4747
```

On another terminal (terminal 2), you connect this debugging server and
continue the execution until the blocking call to read the input stream:

```
> dlv connect :4747
Type 'help' for list of commands.
(dlv) c
```

Now, if you want to pass some input into stdin, you can paste the data directly
into __terminal 1__ and you can inspect your program with the delve command on
the __terminal 2__.

This is a first step that can be useful when the data to paste is not very big.

The first solution that comes in out mind would have been to restart the
debugged program the foolwing way:

```
(dlv) r < input.txt
```

Unfortunately although we can see the executed program seems correctly
executed, it does not work.

```
ubuntu   25667  0.0  0.0   2000    68 pts/4    t+   14:53   0:00 __debug_bin < input0.txt
```

The best I could find, though not very convenient, is to use a named pipe on
the compiled version of the program which specific flags to ease the debugging
session.

So first, let's compile the program as follows to disable any optimizations and
inlining:

```
> go build -gcflags="-N -l"
```

Create a named pipe make it alive forever:

```
> mkfifo myfifo
> sleep infinity > myfifo
```

Run your program so that the read will block:

```
> ./myprogram < myfifo
```

Attach the debugger:

```
> dlv attach $(pgrep -fn myprogram)
```

At that point, you can put your breakpoints. Then you are ready to inject the
data:

```
> cat input.txt > myfifo
```

Be careful: perhaps the Linux kernel will forbid you from attaching the
debugger to the process to be debugged. You can, as root, disable this
security:

```
$ echo 0 > /proc/sys/kernel/yama/ptrace_scope
```
