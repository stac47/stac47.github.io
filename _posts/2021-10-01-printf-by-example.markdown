---
layout: post
title:  "`printf` by example"
tags: C cheatsheet
---

# {{ page.title }}

C'`stdio.h` provides a set of function to print values on the screen following
a provided format: `printf`, `sprintf`, `fprintf`, `dprintf`, `snprintf` and
their counterparts to handle variadic arguments `vprintf`, `vsprintf`,
`vfprintf`, `vdprintf`, `vsnprintf`.

This document is just a set of example to remember how to specify the format.

The format has the following format:

```
%[<flags>][<field's width>][.<precision>][<length modifier>]<conversion specifier>
```

## Generic Examples

Complete documentation: `man 3 printf`

### Strings/Characters

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|`%c%c%c%c%c`        |'H', 'e', 'l', 'l', 'o'  |`Hello`                       |                                        |
|`%s %s`             |"Hello", "World"         |`Hello World`                 |                                        |
|`%10s %s`           |"Hello", "World"         |`     Hello World`            |Right justification by default          |
|`%-10s %s`          |"Hello", "World"         |`Hello      World`            |Left justification on-demand            |
|`%10s`              |"LongLongWord"           |`LongLongWord`                |Minimal width                           |
|`%10.5s`            |"LongLongWord"           |`     LongL`                  |Limit the output                        |
|`%-10.5s`           |"LongLongWord"           |`LongL     `                  |Limit the output left justified         |

### Integers

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|`%d`                |0xDEADBEEF               |`-559038737`                  |%d and %i are aliases                   |
|`%+d`               |42                       |`+42`                         |Prefix with '+' for positive numbers    |
|`%u`                |0xDEADBEEF               |`3735928559`                  |Unsigned representation                 |
|`%o`                |0xDEADBEEF               |`33653337357`                 |Octal representation                    |
|`%x`                |0xDEADBEEF               |`deadbeef`                    |Hexadecimal representation              |
|`%X`                |0xDEADBEEF               |`DEADBEEF`                    |Hexadecimal upper case                  |

### Floats

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|`%.3f`              |double faraday           |`96485.332`                   |Precision is the number of digits after |
|`%f`                |double faraday           |`96485.332123`                |Precision is 6 by default               |
|`%.9g`              |double faraday           |`96485.3321`                  |Precision is the total number of digits |
|`%g`                |double faraday           |`96485.3`                     |Precision is still 6 by default         |
|`%.3g`              |double faraday           |`9.65e+04`                    |                                        |
|`%+.9f`             |double faraday           |`+96485.332123300`            |More decimals                           |
|`%e`                |double faraday           |`9.648533e+04`                |Exponent notation                       |
|`%E`                |double faraday           |`9.648533E+04`                |Exponent upper case                     |
|`%015.2f`           |double faraday           |`000000096485.33`             |Padding with 0                          |
|`% 15.2f`           |double faraday           |`       96485.33`             |Padding with spaces (default)           |
|`%0+15.2f`          |double faraday           |`+00000096485.33`             |Some flags combinations                 |
|`%a`                |double faraday           |`0x1.78e555060857cp+16`       |Hexadecimal notation                    |

### Pointers

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|`%p`                |&someFunction            |`0x559d6478a2f7`              |                                        |
|`%p`                |&someVariable            |`0x559d6478d010`              |                                        |

### Glibc extensions

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|`%m`                |nothing                  |`Success`                     |Display errno                           |
|`%m`                |nothing                  |`No such file or directory`   |Display errno after an error            |

## Go Extensions

Complete documentation: `go doc fmt`

### Generic

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|%v                  |{1 3.14}                 |`{1 3.14}`                    |Generic value                           |
|%+v                 |{1 3.14}                 |`{a:1 b:3.14}`                |Value with field names                  |
|%#v                 |{1 3.14}                 |`main.S{a:1, b:3.14}`         |Go-syntax                               |
|%T                  |{1 3.14}                 |`main.S`                      |Type                                    |

### Strings

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|%q                  |"Hello World!"           |`"Hello World!"`              |Quoted strings                          |
|% x                 |"\xde\xad\xbe\xbe"       |`de ad be ef`                 |Spaced hexadecimal                      |

### Booleans

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|%t/%t               |true, false              |`true/false`                  |Boolean                                 |

### Integers

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|%b                  |127                      |`1111111`                     |Base 2                                  |
|%q                  |127                      |`'\u007f'`                    |Singly quoted character literal         |

### Slices

|Format              |Values                   |Display                       |Comments                                |
|--------------------|-------------------------|------------------------------|----------------------------------------|
|%p                  |["Hello" "World"]        |`0xc0000c4020`                |Address of the first element in a slice |

