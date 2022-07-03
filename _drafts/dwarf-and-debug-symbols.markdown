---
layout: post
title:  "DWARF Debug Symbols"
tags: c elf tutorial
---

# {{ page.title }}

I never had to dig into DWARF (which [backronym][wikipedia_backronym] stands
for "Debugging With Attributed Record Formats"): as long as `gdb` is working
fine, who cares ? In fact, what lead me to go further with debug symbols was a
nasty bug I faced when using [libabigail][libabigail_site]'s `abidiff` tool
with binaries compiled with a very old version of GCC (4.3.2).

As I spent much time to understand the issue, I had to read a lot of
documentation on the DWARF format which is quite difficult to find on internet.
Either we can find this must-read [introduction][dwarf_introduction], or the
[standard][dwarfstd] which cannot be read without an in-depth introduction.
Moreover, as I wanted to experiment, I also faced the lack of documentation on
the DWARF libraries (like elfutils/libdw) although I must admit reading the
code of libdw gives much information on the DWARF format and reading the source
code of eu-readelf gives instructions on how to use libwd.

I will try to put in words what I learnt, for me to help my poor memory and for
anyone who needs a quick introduction.

## A Few Words On ELF Before Talking About DWARF

The Executable and Linkable Format (ELF) is a file format designed to store
information to build executable binaries and to run such binaries.

An ELF file is organized in sections which have specific roles. For instance,
the `.text` section will store the assembly code to be executed. But before
executing a program, the dynamic libraries it relies upon must be loaded and
the used symbols relocated: this is one of the role of the dynamic linker whose
path is stored in the `.interp` section.

If you compiled your program with the GCC `-g` option, debug symbols will be
emitted in the file in a set of sections like `.debug_info`, `.debug_type`,
`.debug_abbrev`. These section will be useful for debuggers.

All these sections are described in a section headers table.

When the program has to be executed, the ELF file must contain information on
how to do this. For instance, the `.text` will have to be mapped somewhere in
memory, but you would like to map this code in executable and read only memory
space. As a matter of fact, executable ELF files will contain a program header
table which will specify how the sections will be used. An entry in this table
describes a **segment** which associates a type and an offset in the file to
memory. For instance, the `.text` section will probably be part of a segment of
type PT_LOAD, offset and size of the part of the file containing this
section, with flags *PF_X* (executable) and *PF_R* (read) to a virtual address
offset.

You can use the `binutils` or `elfutils` to get some readable view of an ELF
file.

```console
> eu-readelf --sections hello
There are 35 section headers, starting at offset 0x2290:

Section Headers:
[Nr] Name                 Type         Addr             Off      Size     ES Flags Lk Inf Al
[ 0]                      NULL         0000000000000000 00000000 00000000  0       0   0  0
[ 1] .interp              PROGBITS     0000000000000238 00000238 0000001c  0 A     0   0  1
...
[14] .text                PROGBITS     0000000000000530 00000530 000001a2  0 AX    0   0 16
...
```

Now, if we look at the program headers:

```console
> eu-readelf --program-headers hello
Program Headers:
  Type           Offset   VirtAddr           PhysAddr           FileSiz  MemSiz   Flg Align
  PHDR           0x000040 0x0000000000000040 0x0000000000000040 0x0001f8 0x0001f8 R   0x8
  INTERP         0x000238 0x0000000000000238 0x0000000000000238 0x00001c 0x00001c R   0x1
        [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x000000 0x0000000000000000 0x0000000000000000 0x000830 0x000830 R E 0x200000
...
```

We can see the bytes from the beginning of the file to `0x000830 - 0x1` will be mapped
to virtual address 0x0 in a read and executable memory space. And we can spot
that the two sections `.interp` and `.text` are in the file range so they are
part of this segment. We can also remark that a section can be referenced by
several segment. For example, the second segment (type PT_INTERP) just give the
location of the path to the interpreter while the third segment is in charge to
load it.

Conversely, some sections may not belong to any segment.

One can wonder how an ELF parser can determine where the section headers or
program headers are located in the file. In fact, there is an additional header
at the beginning of the file, aka ELF Header or File Header, which gives general
information on the current ELF binary like the ELF format version, the targeted
architecture and also the offset, size and number of entries of the section and
program headers.

This can be viewed as follows:

```console
$ eu-readelf --file-header hello
ELF Header:
  Magic:   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF64
  Data:                              2's complement, little endian
  Ident Version:                     1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              DYN (Shared object file)
  Machine:                           AMD x86-64
  Version:                           1 (current)
  Entry point address:               0x530
  Start of program headers:          64 (bytes into file)
  Start of section headers:          8848 (bytes into file)
  Flags:
  Size of this header:               64 (bytes)
  Size of program header entries:    56 (bytes)
  Number of program headers entries: 9
  Size of section header entries:    64 (bytes)
  Number of section headers entries: 35
  Section header string table index: 34
```

A last noteworthy point on the ELF format is that the presence of
program/section headers is optional depending on the use case.

An object file (or relocatable object) raison d'être is to be linked into an
executable and not to be executed. Hence, this type of file will not need a
program headers table. On the other hand, a shared library will have to be
loaded by the operating system and interpreted, hence the file will contain a
program headers table and as it will be used during program link step, the
section headers table is mandatory.  Finally, a program binary will need a
program headers table and the section headers table is optional.

## The DWARF Format

### Introduction

The DWARF format ("Debugging With Attributed Record Formats") was designed to
describe the source code of a program to be used by debuggers. But it can also
be used in other contexts like code coverage analysis or ABI analysis (e.g.
libabigail).

How would the magic occur in GDB when you issue something like `break
hello.cpp:7` if the binary only contained the assembler instructions to be
executed ? At some point, GDB needs a way to associate the source file and the
line to the instruction address to stop the execution flow at. If you compiled
your program with one of the `-g` options, GCC will take care of emitting some
debugging information. GCC supports several types of debugging formats:
* *gdb*: will use the most expressive debug format with addition of specific
  data for GDB
* *dwarf*: DWARF format whose version can be chosen with `-gdwarf-N` with N in
  {2, 3, 4, 5}. At the time of writing the default version is 4 and the
  version 5 is experimental.
* *stabs*, *stabs+*, *xcoff*, *xcoff+*: other formats for other specific platforms.

### How to describe the Source Code

As would any compiler do, the source code is first parsed to build a
representation of it as a tree. This tree is stored in a dedicated ELF section
`.debug_info`.

Each node of the tree is a "Debugging Information Entry" (DIE). A DIE is a
dictionary which keys are attributes (DW_AT_*) associated to a value of a
defined form or type (DW_FORM_*). As node of tree, a DIE can have children and
siblings.

DWARF also aims at having the most compact data representation: it would be a
loss of space to repeat each time the same keys. That's the reason why the
structure of a field is described in another section `.debug_abbrev`. For
instance, the DIE describing a compilation unit will contain the same set of
information (like the name, the compilation command, the language...). The
compiler will then emit an abbreviation for these entities. An abbreviation can
be seen as a guide to how to read the DIE structure.

An entry in `.debug_abbrev` is composed of an index, the type (tag) of the
abbreviation itself, a flag informing about the presence of children and
finally the list of a couples (attribute, form).

Example:

```console
> eu-readelf --sections test_0.so
There are 19 section headers, starting at offset 0x5d8:

Section Headers:
[Nr] Name                 Type         Addr             Off      Size     ES Flags Lk Inf Al
...
[22] .debug_info          PROGBITS     0000000000000000 0000107a 00000075  0        0   0  1
[23] .debug_abbrev        PROGBITS     0000000000000000 000010ef 0000004a  0        0   0  1
...
[25] .debug_str           PROGBITS     0000000000000000 00001176 000000a6  1 MS     0   0  1
...
```

Let's have a look at the file at offset `0x10ef`:

```console
> hexdump -C -s 0x10ef test_0.so

000010ef  01 11 01 25 0e 13 0b 03  0e 1b 0e 11 01 12 07 10  |...%............|
000010ff  17 00 00 02 2e 01 3f 19  03 08 3a 0b 3b 0b 6e 0e  |......?...:.;.n.|
0000110f  49 13 11 01 12 07 40 18  97 42 19 01 13 00 00 03  |I.....@..B......|
...
```

This is the abbreviation number 1 (first byte), DW_TAG_compile_unit `0x11`
(byte 2), has children DW_CHILDREN_yes (byte 3) and the structure description:

* DW_AT_producer `0x25`: DW_FORM_strp `0x0e`
* DW_AT_language `0x13`: DW_FORM_data1 `0x0b`
* DW_AT_name `0x03`: DW_FORM_strp `0x0e`
* DW_AT_comp_dir `0x1b`: DW_FORM_strp `0x0e`
* DW_AT_low_pc `0x11`: DW_FORM_addr `0x01`
* DW_AT_high_pc `0x12`: DW_FORM_data8 `0x07`
* DW_AT_stmt_list `0x10`: DW_FORM_sec_offset `0x17`
* the couple (`0x0`,`0x0`) terminates the abbreviation definition

We can have a look at the first DIE of a simple object file which will be the
Compilation Unit (CU) one:

```console
> hexdump -C -s 0x107a test_0.so

0000107a  71 00 00 00 04 00 00 00  00 00 08 01 07 00 00 00  |q...............|
0000108a  04 54 00 00 00 6f 00 00  00 7a 05 00 00 00 00 00  |.T...o...z......|
0000109a  00 04 00 00 00 00 00 00  00 00 00 00 00 02 61 64  |..............ad|
```

At that point, I must say there are 2 DWARF formats: 32 bits and 64 bits which
impacts mainly the sizes of offset values. If the first byte of the CU DIE is
`0xffffffff`, it is a 64 bits format. In the presented case, it is 32 bits
format. In this case the format of the CU DIE header is 11 bytes and it gives
* the size of the CU DIE (71 bytes)
* the version of DWARF (here 4)
* the offset of the abbreviation (here 0) to use in the `.debug_abbrev`
* the size of addresses (8 bytes)

Then we have the values whose size depends upon the form given in the
abbreviation. The first value is of type `strp` which is 4 bytes in 32-bits
DWARF and gives the offset (0x7) of the NULL-terminated string in the
`.debug_str` which starts at offset `Ox1176`:

```console
> hexdump -C -s 0x1176 test_0.so

00001176  70 61 72 61 6d 32 00 47  4e 55 20 43 2b 2b 31 34  |param2.GNU C++14|
00001186  20 37 2e 33 2e 30 20 2d  6d 74 75 6e 65 3d 67 65  | 7.3.0 -mtune=ge|
00001196  6e 65 72 69 63 20 2d 6d  61 72 63 68 3d 78 38 36  |neric -march=x86|
000011a6  2d 36 34 20 2d 67 20 2d  4f 67 20 2d 66 73 74 61  |-64 -g -Og -fsta|
000011b6  63 6b 2d 70 72 6f 74 65  63 74 6f 72 2d 73 74 72  |ck-protector-str|
000011c6  6f 6e 67 00 74 65 73 74  5f 30 2e 63 70 70 00 5f  |ong.test_0.cpp._|
000011d6  5a 33 61 64 64 69 69 00  70 61 72 61 6d 31 00 2f  |Z3addii.param1./|
...
```

Hence the value associated to the *DW_AT_producer* attribute: "GNU C++14 7.3.0
-mtune=generic -march=x86-64 -g -Og -fstack-protector-strong".

The next expected value is the language which is stored on 1 byte
(DW_FORM_data1): the value `4` maps to C++.

Then the next string is at the offset `0x54` in `.debug_str` which corresponds
to "test_0.cpp".

### Siblings and Children

As said at the beginning, the debug information are stored in DWARF as a tree.
This tree is flatten in the file: this means the tree structure can be read
sequentially and each DIE give and information on the fact the DIE is a child
or a sibling.

As mentioned earlier, the third piece of data in an abbreviation structure
tells if the next DIE must be seen as the first child of the current DIE:

* DW_CHILDREN_yes: the next DIE is a child of the current DIE
* DW_CHILDREN_no: the next DIE is a sibling of the current DIE

To mark the last sibling owned by a parent, the standard specifies that a null
DIE has to placed just after the last sibling.

We will have a look at this tree structure in an example.

```c
unsigned int add(unsigned int a, unsigned int b)
{
    return a+b;
}
```

The tree structure is trivial but it gives a good idea of how DWARF describes
this code.

At the root of the tree, we have the compilation unit which defines the
function `add`. This function has two children: its two parameters `a` and `b`.
This two parameters reference their type which is a children DIE of the
compilation unit.

TODO: read the old tutorial to see if this type description can be shared
between several CUs in case it is linked into a shared library.
TODO: draw the tree

```console
> eu-readelf --debug-dump=info test_0.so

RF section [24] '.debug_info' at offset 0x306c:
 [Offset]
 Compilation unit at offset 0:
 Version: 4, Abbreviation section offset: 0, Address size: 8, Offset size: 4
 [     b]  compile_unit         abbrev: 1
           producer             (strp) "GNU C++14 8.3.0 -mtune=generic -march=x86-64 -g -Og"
           language             (data1) C_plus_plus (4)
           name                 (strp) "test_0.cpp"
		   [...]
 [    2d]    subprogram           abbrev: 2
             name                 (string) "add"
			 [...]
             sibling              (ref4) [    6c]
 [    53]      formal_parameter     abbrev: 3
               name                 (string) "a"
			   [...]
 [    5f]      formal_parameter     abbrev: 3
               name                 (string) "b"
			   [...]
 [    6c]    base_type            abbrev: 4
             byte_size            (data1) 4
             encoding             (data1) unsigned (7)
             name                 (strp) "unsigned int"
```

### Other Debug Sections

So far, we mainly talked about the `.debug_info` section and its links with
`.debug_str` and `.debug_abbrev`.

In fact, there is another central section named `.debug_types` which describes
the types used in a program.

`.debug_info` and `.debug_types` are central in the sense they reference values
in sections like `.debug_str`, `debug_abbrev` and are referenced by some
sections like `.debug_aranges` (fast access by address - see Section
[6.1.2][dwarfstd]), `.debug_pubnames` and `.debug_pubtypes` (fast access by
name/type - see [Section 6.1.1][dwarfstd])...

## Using elfutils/libdw

### Available Libraries

There are several ways to parse DWARF data from a file.  Generally, DWARF
information is embedded in a section of an ELF formatted file.  To manipulate
DWARF section, you have the choice between two libraries:

- [libdwarf](https://www.prevanders.net/dwarf.html)
- [libdw](https://sourceware.org/elfutils/) which is part of the elfutils
  project

Both provide the same functionalities though the APIs are slightly different.
Both also rely upon the elfutils's libelf library to parse the sections from an
ELF file.

We will only speak about the **libdw** library.

### An Example of libdw Usage

The best to learn how to use the library is probably reading the code from the
programs provided by the elfutils. For example:

- Elfutils' nm (as well as the binutils version) aims at displaying the symbols
  in a binary file. You can check at `src/nm.c` in function `show_symbols`
- Elfutils' readelf will show how to iterate over Compile Unit and extract data
  from it, in particular in `src/readelf.c` in the function
  `print_debug_units`.

We will produce here a simple program that will output the list of the
compilation units displaying its name and the compilation directory of each. We
will not loop over the tree of DIE contained in a CU.

```c
int main(int argc, const char *argv[])
{
    size_t hdr_size = 0;
    Dwarf_Off offset = 0;
    Dwarf_Off last_offset = 0;
    FILE* fp;
    Dwarf* dwarf;

    printf("Opening file: %s\n", argv[1]);
    fp = fopen(argv[1], "r");
    if (fp == NULL)
    {
        printf ("Opening file, errno = %d\n", errno);
        return 1;
    }

    dwarf = dwarf_begin(fileno(fp), DWARF_C_READ);
    if (dwarf == NULL)
    {
        printf ("No symbols found");
    }
    ...
```

This is the entry point of the program: no noteworthy things to tell about it.
We open a file and pass the file descriptor to the `dwarf_begin` function. You
can also perform this operation in a single call to `dwarf_begin_elf`.

```c
    ...
    while (dwarf_nextcu(dwarf, offset, &offset, &hdr_size, NULL, NULL, NULL) == 0)
    {
    ...
```

We loop on the Compile Unit described in the DWARF info section. We start at
the offset 0. The call to `dwarf_nextcu` will give the offset of the next CU
and the header size. Hence to get the first DIE, we need to add header size to
the current CU offset. This is done by the `dwarf_offdie` function as shown
hereafter:

```c
        ...
        Dwarf_Die die;
        if (dwarf_offdie(dwarf, last_offset + hdr_size, &die) == NULL)
        {
            // Error ?
            return 1;
        }
        ...
```

`libdw` provides some facilities to access the type of a DIE and also to get
the attributes value without having to deal with the `.debug_abbrev` section.
We are using the functions `dwarf_tag`, `dwarf_diename`, `dwarf_attr` and
`dwarf_formstring` to display the pieces of data we want:

```c
        ...
        printf("Tag: %x\n", dwarf_tag(&die));
        printf("  name: %s\n", dwarf_diename(&die));
        Dwarf_Attribute attr;
        Dwarf_Attribute* attr_ret = dwarf_attr(&die, DW_AT_comp_dir, &attr);
        printf("  dir: %s\n", dwarf_formstring(&attr));
        last_offset = offset;
    }
    ...
```

As we saw earlier, the tag of a DIE explains what the DIE represents. Hence,
the function `dwarf_tag` gets the abbreviation associated to the DIE and get
the second byte of it.

`dwarf_attr` gives the possibility to the user to get an attribute by name. For
instance, we use it in this code snippet to get the compilation directory
(DW_AT_comp_dir). `dwarf_diename` is simply a shortcut to get the attribute
`DW_AT_name`.

We also saw that characters string can be inlined in a DIE (DW_FORM_string) or
an offset in the `.debug_str` section (DW_FORM_strp). The function
`dwarf_formstring` will remove the burden of knowing how a string is stored.

```c
    ...
    dwarf_end(dwarf);
    fclose(fp);
    return 0;
}
```

The end of this code is not really interesting and deals with releasing
allocated resources.

## Going Further

Debuggers generally provide a way to navigate across the frames of the call
stack. When a routine calls another routine, the compiler generates some code
to allocate memory on the stack for the computation done by the called code
without impacting the state of the caller context and some code to go back to
caller context when the called routine returns.

When debugging a program, the debugger will not modify the execution of the
program to navigate in the different frames but will have to "virtually unwind"
the stack. This is achieved by adding some information in a dedicated
sections about the way to recreate the caller frames and more particularly,
how to find the base address for a previous frame. This address is called the
**Cannonical Frame Address (CFA)**.

DWARF specifies a set of instructions to compute the CFA and also the value of
the registers in a caller frame. Actually, this section truly contains small
programs that are loaded in memory (although not in an executable section):
this code has to be interpreted at runtime (if your program is compiled with
GCC, this is done by the `libgcc` library your program has to be linked with).
Those instructions are stored in a dedicated debug section `.debug_frame`. Note
that if your program is compiled with GCC, the section name will be
`.eh_frame` to emphase that this section is not only used for debugging purpose
but also during the "exception handling".

### Other Sections Using DWARF

TODO: talk about operators

### Embedding Malicious Code

## References

* The [ELF specification](http://www.sco.com/developers/gabi/latest/contents.html)
* The [DWARF specification][dwarfstd]

[dwarfstd]: http://dwarfstd.org/doc/DWARF4.pdf
[wikipedia_backronym]: https://fr.wiktionary.org/wiki/backronym#en
[libabigail_site]: https://fr.wiktionary.org/wiki/backronym#en
[dwarf_introduction]: http://www.dwarfstd.org/doc/Debugging%20using%20DWARF.pdf
[gcc_eh_intro]: https://gcc.gnu.org/wiki/Dwarf2EHNewbiesHowto
