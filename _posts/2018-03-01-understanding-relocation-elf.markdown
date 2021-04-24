---
layout: post
title:  "Understanding Symbols Relocation"
date:   2018-03-01 15:28:07
categories: c relocation elf tutorial
---

Relocation of symbols is conceptually a simple operation: when compiling/running a
program, the references to symbols has to be replaced by their real location in
memory. But under the hood, when relocation process takes place ? When are the
relocation sections used ?

To answer my questions, I experimented on a x86_64 architecture (Intel Core
i7).

In the following text, when I talk about [linker or
link-editor](https://en.wikipedia.org/wiki/Linker_(computing)), I mean the
program that takes several object files and link them altogether to produce
either an executable or a shared library.

The [dynamic linker](https://en.wikipedia.org/wiki/Dynamic_linker) is a piece
of code that is executed alongside an executable to resolve the dynamic symbols
at runtime.

# Simple Case: Static Linkage

Let's start with the simplest case: we will statically link an executable.

```c
#include "nothing.h"

int main(int argc, const char *argv[])
{
    doAlmostNothing();
    return 0;
}
```

And the called code:

```c
#include "nothing.h"

static void doNothingStatic() {}

void doNothing() {}

void doAlmostNothing()
{
    doNothingStatic();
    doNothing();
}
```

The function `doAlmostNothing` calls the exported function `doNothing` and
statically linked function `doNothingStatic`. `doNothingStatic` is local to the
generated object file, hence the compiler is able to compute the good address.

On the contrary, `doNothing` can be reference by another object file and used
when linking an executable. To produce an executable, the link-editor will have
to place a `doNothing` somewhere and replace all the reference to it by its
effective address.

We disassemble the `nothing.o`:

```console
> objdump -d nothing.o

nothing.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <doNothingStatic>:
   0:   55                      push   %rbp
   1:   48 89 e5                mov    %rsp,%rbp
   4:   90                      nop
   5:   5d                      pop    %rbp
   6:   c3                      retq

0000000000000007 <doNothing>:
   7:   55                      push   %rbp
   8:   48 89 e5                mov    %rsp,%rbp
   b:   90                      nop
   c:   5d                      pop    %rbp
   d:   c3                      retq

000000000000000e <doAlmostNothing>:
   e:   55                      push   %rbp
   f:   48 89 e5                mov    %rsp,%rbp
  12:   b8 00 00 00 00          mov    $0x0,%eax
  17:   e8 e4 ff ff ff          callq  0 <doNothingStatic>
  1c:   b8 00 00 00 00          mov    $0x0,%eax
  21:   e8 00 00 00 00          callq  26 <doAlmostNothing+0x18>
  26:   90                      nop
  27:   5d                      pop    %rbp
  28:   c3                      retq
```

Looking at offset 17, we can see the call to `doNothingStatic`. This function
is local to the file, so its offset can be directly written. Due to
little-endianess of x86 architecture, __0xffffffe4__ is __-1c__ bytes from the next
instruction pointer value which is __0x1c__. Hence, this is a call to the function
written at address __0x0__ which is `doNothingStatic`.

On the contrary, the compiler did not put the address of the `doNothing`
function, although he could give an address if he assumes the code is  linearly
mapped in memory. I don't know, maybe it is a convention. I keep this question
for latter. Anyway this gives us the opportunity to explain a basic relocation.

If we only look at the bytes in the assembler code (the translation in readable
assembler code makes use of the sections we will describe now to show which
function is called), we can see the 4 bytes (32 bits) are zeros. It will be the
role of the linker to fill such portion of the assembler code with correct
values when the object file has to be used.

But the linker cannot magically guess which values to put in the final binary
file. The compiler will put some information in ELF sections that are dedicated
to the relocations: depending on the targeted architecture, the involved
section are `.rel.text` (x86_32) or `.rela.text` (x86_64).

```console
> readelf -r nothing.o

Relocation section '.rela.text' at offset 0x250 contains 1 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000022  000900000002 R_X86_64_PC32     0000000000000007 doNothing - 4
```

(On recent versions of GCC, the relocation type has changed to R_X86_64_PLT32
on `x86_64`. This is due to the  [commit][binutils_reloc_commit]. This does not
change anything for static linkage explanation and mentioning the PLT now would
be confusing: go to the dynamic link paragraph to know more about the PLT)

What this says to the link editor is: "Be careful, what is at offset 22 has to
be replaced by an address that can be calculated in the way described by the
relocation type X86_64_PC32. For such a calculation, you can use the
value (here __0x7__) and the addend (here -4)". The type of relocation tells
the linker how to calculate the effective address. In this case S + A - P
where:

*   S: The value of the symbol whose index resides in the relocation entry.
*   A: The addend used to compute the value of the relocatable field.
*   P: The section offset or address of the storage unit being relocated

Can we validate this in the produced executable ?

Here is a final binary produced by the linker:

```
0000000000000660 <main>:
 660:   55                      push   %rbp
 661:   48 89 e5                mov    %rsp,%rbp
 664:   48 83 ec 10             sub    $0x10,%rsp
 668:   89 7d fc                mov    %edi,-0x4(%rbp)
 66b:   48 89 75 f0             mov    %rsi,-0x10(%rbp)
 66f:   b8 00 00 00 00          mov    $0x0,%eax
 674:   e8 15 00 00 00          callq  68e <doAlmostNothing>
 679:   b8 00 00 00 00          mov    $0x0,%eax
 67e:   c9                      leaveq
 67f:   c3                      retq

0000000000000680 <doNothingStatic>:
 680:   55                      push   %rbp
 681:   48 89 e5                mov    %rsp,%rbp
 684:   90                      nop
 685:   5d                      pop    %rbp
 686:   c3                      retq

0000000000000687 <doNothing>:
 687:   55                      push   %rbp
 688:   48 89 e5                mov    %rsp,%rbp
 68b:   90                      nop
 68c:   5d                      pop    %rbp
 68d:   c3                      retq

000000000000068e <doAlmostNothing>:
 68e:   55                      push   %rbp
 68f:   48 89 e5                mov    %rsp,%rbp
 692:   b8 00 00 00 00          mov    $0x0,%eax
 697:   e8 e4 ff ff ff          callq  680 <doNothingStatic>
 69c:   b8 00 00 00 00          mov    $0x0,%eax
 6a1:   e8 e1 ff ff ff          callq  687 <doNothing>
 6a6:   90                      nop
 6a7:   5d                      pop    %rbp
 6a8:   c3                      retq
 6a9:   0f 1f 80 00 00 00 00    nopl   0x0(%rax)
```

Here we spot 2 things:
*   The call to `doNothingStatic` has not changed. In fact, the linker only
    treats the `.text` section has raw byte stream and simply concatenates all
    those sections from all object files. The call to `doNothingStatic` was
    already a relative jump from the next instruction to execute.
*   The linker calculated that call to `doNothing` was a jump to
    `0x6a6 + 0xffffffe1 = 0x687`. Here the `.text` section of `nothing.o` starts at
    0x680. The linker knows from the relocation section that it will have to
    change the value at `0x6a2 (=0x680 + 0x22)` so that it jumps towards `0x687
    (=0x680 + 0x7)`. The relocation being of type `R_X86_64_PC32`, the value
    will be relative to the PC (Program Counter), the IP register will be `0x6a6
    (=0x6a2 + 4 bytes = 0x680 + 0x22 + 0x4)`. The relative jump will then be:
    `0x687 - 0x6a6 = 0x680 + 0x7 - (0x680 + 0x22 + 0x4) = 0x7 - 0x4 - 0x22 = -
    0x1f` which is `0xffffffe1` in complement to two.
    We recognize here what was in the relation section with S = 0x7, A = -4 and
    P = 0x22.

There are a few interesting things to say about the `main` function. The linker
also operated a relocation to the `doAlmostNothing` function. Let us see the
relocation information from the object file containing the main function:

```console
> readelf -s --wide prog0.o | grep doAlmostNothing
    10: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND doAlmostNothing

> readelf -r prog0.o

Relocation section '.rela.text' at offset 0x208 contains 1 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000015  000a00000004 R_X86_64_PLT32    0000000000000000 doAlmostNothing - 4

```

The undefined symbol `doAlmostNothing` will have to be relocated. This time the
type of the relocation is `R_X86_64_PLT32`. We will see later that in the case of
a position-independent code, the call to a function be done through a table
called the __Procedure Linkage Table__ which is used by the dynamic linker at
runtime.

This type has been chosen in case we would link the nothing.o in a shared
library and link the executable with this dynamic library. In the case all is
statically linked, the linker will consider it will have to do the same job as
if the relocation type was `R_X86_64_PC32` relocation (as written in the gold
linker in _x86_64.cc:3637_).

# Relocation when using Dynamic Libraries

## Quick Introduction

When statically linking an executable, all the external functions the program
relies on are stored in the final file. In fact, the link editor will
concatenate all the .text parts into the final file. In the end, when the
executable is run, all this code is mapped in memory.

Although simple, this approach has several drawbacks:
*   if several programs uses the same functions, they will all have their own
    copy of the code of these functions. Clearly, on systems that allows several
    programs to run at the same time, some space on disk and in memory is wasted.
*   if you detect a bug in one of the functions that is used by several programs,
    fixing this bug will require you to rebuild all the programs.

To cope with such drawbacks, we could put the shared code somewhere in memory
so that the all the dependent programs would jump to this location to execute
this common code. In fact, the virtual memory system will hide the real
position of the dynamic library in physical memory.

This is the way the shared libraries works. But for this to work, it requires
the introduction of new actors in the runtime environment. The link editor
alone is no more able to resolve all the symbols because, by definition, it is
not aware of the addresses of the shared code at runtime.

Hence, some kind of dynamic linker is required to relocate at runtime the
undefined symbols. On GNU/Linux, this special process is generally provided by
the __glibc__. An executable that depends upon shared libraries, holds a reference
to the path toward the dynamic linker to use. This path is stored in the
`.interp` section of the executable:

```console
> readelf -S prog1_dynamic.out

There are 31 section headers, starting at offset 0x1a80:

Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .interp           PROGBITS         0000000000000238  00000238
       000000000000001c  0000000000000000   A       0     0     1
  [...]

$hexdump -C prog1_dynamic.out
[...]
00000230  01 00 00 00 00 00 00 00  2f 6c 69 62 36 34 2f 6c  |......../lib64/l|
00000240  64 2d 6c 69 6e 75 78 2d  78 38 36 2d 36 34 2e 73  |d-linux-x86-64.s|
00000250  6f 2e 32 00 04 00 00 00  10 00 00 00 01 00 00 00  |o.2.............|
..[.]
```

When running this executable, the `/lib64/ld-linux-x86-64.so.2` will somehow
have to start and handle the undefined symbols.

## Position Independent Code

When we think about it, the job of the dynamic linker could be simple. Based on
PC-Relative relocations inserted by the link-editor, it could put the real
addresses of the called function/accessed variables at the call locations.

This has two drawbacks:
*   this would mean when the program starts, the dynamic linker would have to
    perform all (and probably a lot) of relocations impacting the program startup
    time.
*   this would also mean the dynamic linker would modify the program code loaded
    in memory. Nowadays, for security reasons, the executable code is stored in
    read-only memory pages. For such systems, this is not impossible: the dynamic
    linker would have the additional work of changing the permission on memory
    pages to RW and to set it back to RO after the content has been patched.

As usual in computer sciences, the solution consists in adding an indirection
layer. This indirection will be performed by the Global Offset Table (GOT) and
the Procedure Linkage Table (PLT).

```console
> readelf --segments prog0_dynamic.out

Elf file type is DYN (Shared object file)
Entry point 0x650
There are 9 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x00000000000001f8 0x00000000000001f8  R E    0x8
  INTERP         0x0000000000000238 0x0000000000000238 0x0000000000000238
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x000000000000096c 0x000000000000096c  R E    0x200000
  LOAD           0x0000000000000dc8 0x0000000000200dc8 0x0000000000200dc8
                 0x0000000000000268 0x0000000000000270  RW     0x200000
  [...]
 Section to Segment mapping:
  Segment Sections...
   00
   01     .interp
   02     .interp .note.ABI-tag .note.gnu.build-id .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .plt.got .text .fini .rodata .eh_frame_hdr .eh_frame
   03     .init_array .fini_array .jcr .dynamic .got .got.plt .data .bss
   [...]
```

As we can see, in the previous `readelf` output, those tables `.got` and
`.got.plt` will be loaded in Read/Write memory pages (to cope with the security
limitations) and will be filled at runtime:
*   at program startup for global variables (`.got`)
*   on the first call to a function (`.got.plt`)

This implies that an object file to be included in the shared library cannot
write PC-Relative or absolute relocation information. It will have to indicate
that the call/access will have to be done via the PLT/GOT.

Hence, when compiling some code to be embedded in shared library, we must
require the compiler to generate _Position Independent Code_. This can be done
using the `-fPIC` option as shown in the following example:

```console
> gcc -Wall -g -O0 -fPIC -c nothing.c -onothing_pic.o
> gcc -shared -o libnothing.so nothing_pic.o
```

## Calling a Shared Library Function

In the previous example, there was a PC-relative relocation for the symbol
`doAlmostNothing`. This was possible because the linker knew where the function
was located.

If we put this function in a shared library and re-link the program with this
library, the link editor and the dynamic linker will cooperate to call
`doAlmostNothing`. The link editor will put some special relocation type that
will be used by the dynamic linker to locate the function to call. How does it
work under the hood ?

Comparing the dynamic and the static version shows a difference in the way the
`doAlmostNothing` is called.

```console
> objdump -d -s prog0.out
[...]
674:   e8 15 00 00 00          callq  68e <doAlmostNothing>
[...]

$objdump -d -s prog0_dynamic.out
[...]
794:   e8 97 fe ff ff          callq  630 <doAlmostNothing@plt>
[...]
```

We can see the execution does not jump directly to the code of the function but
to an intermediary code linked to the PLT (Procedure Linkage Table) we had a
few words about:

```
0000000000000630 <doAlmostNothing@plt>:
 630:   ff 25 e2 09 20 00       jmpq   *0x2009e2(%rip)        # 201018 <doAlmostNothing>
 636:   68 00 00 00 00          pushq  $0x0
 63b:   e9 e0 ff ff ff          jmpq   620 <.plt>
```

Which itself seems to jump to a common piece of code (see `0x630`):

```
0000000000000620 <.plt>:
 620:   ff 35 e2 09 20 00       pushq  0x2009e2(%rip)        # 201008 <_GLOBAL_OFFSET_TABLE_+0x8>
 626:   ff 25 e4 09 20 00       jmpq   *0x2009e4(%rip)        # 201010 <_GLOBAL_OFFSET_TABLE_+0x10>
 62c:   0f 1f 40 00             nopl   0x0(%rax)
```

As `objdump` is gentle enough to resolve the addresses involved at 620 and 626,
this `.plt` section (loaded in executable segments) references 2 hard coded
address entries in the Global Offset Table (GOT): the entries 2 and 3 of the
GOT. 

If we look at how the segments are mapped in memory, we can see the `.plt`
section is in READ and EXEC memory pages. This section is a set of functions
which aim at finding the address of the function to call. The terminology used
in the glibc is _trampoline_ (see.  sysdeps/x86_64/dl-trampoline.S in the glibc
source code).

So what happened to call the `doAlmostNothing` ? Let's try to tidy this mess to
understand who is involved in such a call.

The linker can see that a call to `doAlmostNothing` will have to be performed
(but the location of the code is not known at link-editor phase). It will:
*   create a section `.got.plt` (if does not already exist)
*   write the address of the `.dynamic` section in the first entry of the
    `.got.plt` (if not already done)
*   add a relocation of type __JUMP_SLOT__ (here `R_X86_64_JUMP_SLO`): the offset
    gives an address in the PLT where the effective address of the function
    will have to be set.

```console
> readelf -r prog0_dynamic
Relocation section '.rela.plt' at offset 0x5f0 contains 1 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000201018  000100000007 R_X86_64_JUMP_SLO 0000000000000000 doAlmostNothing + 0

>readelf --sections prog0_dynamic
Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [...]
  [23] .got              PROGBITS         0000000000200fd0  00000fd0
       0000000000000030  0000000000000008  WA       0     0     8
  [24] .got.plt          PROGBITS         0000000000201000  00001000
       0000000000000020  0000000000000008  WA       0     0     8
  [...]
```

The `.got` and `.got.plt` will be loaded on Read/Write memory pages so that it
can be updated at runtime as you can see by using `readelf --segments`.

The linker set the content at 0x201018 (in the GOT) to the address of the
second instruction of `<doAlmostNothing@plt>`.

That's all for the link editor. Now when executing the program, for the
first call to `doAlmostNothing`, the instruction at 0x630 is simply a jump to
0x636. This one, will push the index of the symbol in the GOT.

Then we jump to the magic code. To understand it, we must know that, at program
startup, the dynamic linker set some values in the entries 2 and 3 of the GOT
to call itself.

So, instruction at 626 calls the dynamic linker with the index in the GOT as a
parameter. This way, it will perform 2 steps:
*   resolve the address of the `doAlmostNothing` thanks to relocation information
*   store its address at the good index in the GOT

After this, the content at 0x201018 will be the real address of the function.
Hence, a second call to `doAlmostNothing` will not require the dynamic linker
anymore.

This process can be visible within a debugger session:

```
(gdb) disas
Dump of assembler code for function doAlmostNothing@plt:
=> 0x0000555555554630 <+0>:     jmpq   *0x2009e2(%rip)        # 0x555555755018
   0x0000555555554636 <+6>:     pushq  $0x0
   0x000055555555463b <+11>:    jmpq   0x555555554620
End of assembler dump.
(gdb) x/a 0x555555755018
0x555555755018: 0x555555554636 <doAlmostNothing@plt+6>
```

This confirms the first line is, the first time, the address of the next
instruction. Let's resume the execution, we break just after the call to
`doAlmostNothing`.

```
(gdb) c
Continuing.

Breakpoint 2, main (argc=1, argv=0x7fffffffe7f8) at prog0.c:6
6           return 0;
(gdb) x/a 0x555555755018
0x555555755018: 0x7ffff7ff270e <doAlmostNothing>
```

And this time, the value at 0x555555755018 is now the effective address of the
`doAlmostNothing` function. We can verify that this address points to the
executable memory space of shared library `libnothing`:

```console
$ cat /proc/<pid>/map
[...]
7ffff7ff2000-7ffff7ff3000 r-xp 00000000 08:01 389081    <path>/libnothing.so
[...]
```

## Variable Symbol Relocations

So far, we only saw how function symbols were being relocated. What if a shared
library exposes a global variable, that can be used at the same time locally by
the library and externally by a program that depends on the library ? This time
again, the dynamic linker will use relocations information provided by the link
editor to locate the address of this variable.

We can imagine a shared library that defines a string `kExternString` and also
a function `printExternalString` that prints that variable out. An executable
call this method and also directly print the variable.

```console
> readelf -r libprinter.so.1

Relocation section '.rela.dyn' at offset 0x520 contains 11 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
[...]
000000200ff0  000c00000006 R_X86_64_GLOB_DAT 0000000000201040 kExternString + 0
[...]

> readelf -r prog1_dynamic.out

Relocation section '.rela.dyn' at offset 0x578 contains 10 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
[...]
000000201038  000b00000005 R_X86_64_COPY     0000000000201038 kExternString + 0
[...]
```

There are two types of relocation we have not met yet:
*   from the shared library, R_X86_64_GLOB_DAT
*   from the executable, R_X86_64_COPY

R_X86_64_GLOB_DAT relocation is triggered by the internal call by
`printExternalString`: it gives the offset where to find the variable
value is stored.

R_X86_64_COPY tells the dynamic linker to copy the address of the value in the
GOT at address given by the offset member (here `0x000000201038`). This way the
code will access the variable via the GOT.

The dynamic linker knows where the `kExternString` is located: it is calculated
from the load address of the shared library + the value of the symbol (taken
from the dynamic symbols table `.dynsym`). In our case:

```console
> readelf --symbols libprinter.so

Symbol table '.dynsym' contains 17 entries:
   Num:    Value          Size Type    Bind   Vis      Ndx Name
    [...]
    12: 0000000000201040     8 OBJECT  GLOBAL DEFAULT   23 kExternString
    [...]
```

If the library is loaded at `0x7ffff7bd7000`, the location of the
`kExternString` (of the pointer toward the sequence of null-terminated
characters) will be `0x7ffff7dd8040`. This value is copied to the GOT.

```
(gdb) x/a 0x7ffff7bd7000 + 0x201040
0x7ffff7dd8040 <kExternString>: 0x7ffff7bd783d
```

Let us say now the read/write segment of my program is loaded at
`0x555555755000` and the `.got` section must be loaded at offset `0x30`
(`readelf --sections <prog>`), the first entry is 8 bytes further. Hence to
access `kExternString`, its address will have to be taken at `0x555555755038`.
With those initial conditions, we can validate that, at runtime, the good
address is used:

```
(gdb) x/a 0x555555755038
0x555555755038 <kExternString>: 0x7ffff7bd783d
```


# Conclusion

After this exercise, I have a clearer idea of the linkers job and how the
relocations are handled. There are so much thing to dig into like the
visibility of symbols, the way thread local storage is handled, the versioning
of symbols. I will stop here. If a reader find an error, he can submit a Pull
Request.

# References

*   The bright series of post by the author of the
    [gold](https://en.wikipedia.org/wiki/Gold_(linker)) about linkers
    [https://www.airs.com/blog/archives/38](https://www.airs.com/blog/archives/38)
*   Oracle [Linker and Libraries
    Guide](https://docs.oracle.com/cd/E23824_01/html/819-0690/toc.html)
*   Ulrich Drepper's [How To Write Shared
    Libraries](https://www.akkadia.org/drepper/dsohowto.pdf)

[binutils_reloc_commit]: https://sourceware.org/git/?p=binutils-gdb.git;a=commitdiff;h=bd7ab16b4537788ad53521c45469a1bdae84ad4a;hp=80c96350467f23a54546580b3e2b67a65ec65b66
