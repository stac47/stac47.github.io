---
layout: post
title:  "C++11 & Performances"
date:   2017-11-21 15:28:07
categories: C++ Performances
---

A few notes I took from a lecture I attended a few days ago. I found some parts
very interesting, whereas basic. I share this in case some would be interested.

# Memory Proximity

Modern architecture generally have several levels of cache between the CPU and RAM.
On the current computer I am working on, there are 3 levels of cache as we can
see with the `lscpu` command:

```
stac@debian:~>lscpu
Architecture:        x86_64
CPU op-mode(s):      32-bit, 64-bit
Byte Order:          Little Endian
CPU(s):              4
...
L1d cache:           32K
L1i cache:           32K
L2 cache:            256K
L3 cache:            3072K
NUMA node0 CPU(s):   0-3
```

The nearest and smallest cache L1 (64K) is divided into two parts:
- Instructions cache
- Data cache

How a CPU cache works is quite easy to understand, but behind the scene it is
top notch algorithms to optimize what as to be put in so that the cores do not
waste time grabbing the memory from L2, L3 or, worse, the RAM. If the CPU needs
to access a part of the memory that is available in the L1 cache, fine : it is
called a cache hit. If not, it is a cache miss and the CPU will try to find the
memory in L2 cache. The process continues until the data is found which can end
up in the RAM (the slowest location).

The number of CPU cycles to access a piece of data in memory give a clear
overview of the costs:

| Memory location                  | Number of CPU Cache      |
|----------------------------------|--------------------------|
| CPU Registry                     | ~ 1                      |
| L1 Cache                         | 3-4                      |
| L2 Cache                         | 10-12                    |
| L3 Cache                         | 30-70                    |
| L3 Cache - Other CPU socket      | 100-300                  |
| RAM                              | 100-150                  |
| RAM - Other CPU socket           | 300-500                  |

Hence, it is very important to strive to avoid the cache misses. Let's have a
look at an exemple of an array of the following structures:

```cpp
struct Person {
    char first_name[30];
    char last_name[30];
    int age;
};
```

The goal is to calculate the average of the ages:

```cpp
constexpr int kPersonNumber = 100'000;

double average(const std::array<Person, kPersonNumber>& persons)
{
    int sum = 0;
    for (const Person& person : persons)
    {
        sum += person.age;
    }
    return sum / kPersonNumber;
}

int main(int argc, const char *argv[])
{
    std::array<Person, kPersonNumber> persons;
    for (int i=0; i < kPersonNumber; ++i)
    {
        // Fill the array of Persons
    }

    std::cout << "Average: " << average(persons) << std::endl;
    return 0;
}
```

The `average` function loops on all the structures contained in the array. This
leads to a cache miss on each iteration of the loop. We can use the Cachegrind
tool to visualize the number of cache misses:

```
valgrind --tool=cachegrind --branch-sim=yes --cache-sim=yes --cachegrind-out-file=chg.out ./myprog
cg_annotate chg.out `pwd`/myprog.cpp
```

Here is the interesting part of the output:

```
==XXXX== D   refs:      2,146,050  (1,397,466 rd   + 748,584 wr)
==XXXX== D1  misses:      222,386  (  119,985 rd   + 102,401 wr)
==XXXX== LLd misses:      209,999  (  108,396 rd   + 101,603 wr)
==XXXX== D1  miss rate:      10.4% (      8.6%     +    13.7%  )
==XXXX== LLd miss rate:       9.8% (      7.8%     +    13.6%  )
...
       Ir I1mr ILmr      Dr    D1mr    DLmr      Dw   D1mw   DLmw      Bc   Bcm Bi Bim  file:function
...
1,000,027    3    3 300,006 100,002 100,001 200,006 99,999 99,999 200,000    10 0   0  :main
...
```

D1mr stands for Data L1 miss read. And we can see the order of magnitude of the
the array size.

What would be the result if we changed the structure into a struct of arrays and
change the `average` function 

```cpp
struct Person {
    char first_name[kPersonNumber][30];
    char last_name[kPersonNumber][30];
    int age[kPersonNumber];
};

double average(const Person& persons)
{
    int sum = 0;
    for (int i=0; i < kPersonNumber; ++i)
    {
        sum += persons.age[i];
    }
    return sum / kPersonNumber;
}
```

In this new version, the ages are stored in contiguous block of memories. So,
when we access `persons.age` array which is 400'000 bytes a big part of it can
be access through the L1 cache in each iteration of the loop, reducing the
number of cache misses as we can see in the Cachegrind output:

```
==XXXX== D   refs:      2,271,052  (1,322,467 rd   + 948,585 wr)
==XXXX== D1  misses:      129,213  (   26,807 rd   + 102,406 wr)
==XXXX== LLd misses:      112,949  (   11,368 rd   + 101,581 wr)
==XXXX== D1  miss rate:       5.7% (      2.0%     +    10.8%  )
==XXXX== LLd miss rate:       5.0% (      0.9%     +    10.7%  )
...
       Ir I1mr ILmr      Dr  D1mr  DLmr      Dw   D1mw   DLmw      Bc   Bcm Bi Bim  file:function
...
  900,026    3    3 225,006 6,252 3,098 400,006 93,749 93,749 125,000    10 0   0 :main
...
```

Here we can see a drastic decrease of cache misses (from 100'000 downto 6'252
for L1 cache).

Moreover, the fact the data (in our case the person's ages is stored in 400'000
contiguous bytes can allow some compiler optimization.

If we compile the second version of the program in gcc with the following
options `-O2 -march=native`, the `average` function will look like this:

```asm
average(Person const&):
  leaq 6000000(%rdi), %rax
  leaq 6400000(%rdi), %rdx
  xorl %ecx, %ecx
.L2:
  addl (%rax), %ecx
  addq $4, %rax
  cmpq %rdx, %rax
  jne .L2
  ... (make the final division here)
  ret
```

Here, we can see (between the label L2 and the jump to L2), that 4 bytes by 4
bytes, we add the ages in the %ecx register.

Now, if we compile the program with the flags `-O3 -march=native`, let us have
a look at the loop:

```asm
average(Person const&):
  ...
  shrl $3, %ecx
.L4:
  addl $1, %eax
  vpaddd (%rdx), %ymm0, %ymm0
  addq $32, %rdx
  cmpl %eax, %ecx
  ja .L4
  ... (make the final division here)
  ret
```

We can see that we are able to pack 8 integers and to add them 8 by 8 thanks to
the MMX registers. As a matter of fact the number of operations to sum all the
ages is devided by 8.

# Inlining and C++

Inlining is the decision taken by the compiler not to do a real call to a
function, but directly write the assembler code of the function at the point it
should be called.

Here is a simple example that calculate the square of the number of arguments
passed to the program. We could have chosen to calculate the square of a
constant but the very agressive compiler's optimization would have calculated
the result without any needs of inlining.

```cpp
#include <iostream>

int square(int num)
{
    return num * num;
}

int main(int argc, const char* argv[])
{
    auto a = square(argc);
    std::cout << a << std::endl;
    return 0;
}
```

Compiling with gcc with no optimization (`-O0 -march=native`), would lead to a
call to the square function (with the argument copied in `%rdi` register and
the creation of a stack frame).

```asm
main:
  ...
  movl %eax, %edi
  call square(int)
  movl %eax, -4(%rbp)
  movl -4(%rbp), %eax
  movl %eax, %esi
  movl std::cout, %edi
  call std::basic_ostream<char, std::char_traits<char> >::operator<<(int)
  ...
```

The obvious optimization would be to directly multiply the value that is passed
to main by itself without calling the function. This is what is done with the
following gcc options `-O1 -march=native`:

```asm
main:
  subq $8, %rsp
  imull %edi, %edi
  movl %edi, %esi
  movl std::cout, %edi
  call std::basic_ostream<char, std::char_traits<char> >::operator<<(int)
  ...
```

There is no call to the `square(int)` function anymore: this is called
inlining.

The C++ compilers strive to inline the maximum of functions to improve the
program performances. But there are some C++ language features that does not
fit well to this philisophy, like inheritance and polymorphism.

Let's have a look at the following program:

```cpp
#include <iostream>
#include <array>

class ValueProviderBase
{
public:
    virtual int value() =0;
};

class ConstValueProvider : public ValueProviderBase
{
public:
    virtual int value() override {return 42;}
};

constexpr int kMax = 100'000;

int main(int argc, const char* argv[])
{
    std::array<ValueProviderBase*, kMax> v;

    ConstValueProvider p;

    for (int i = 0; i < kMax; ++i) v[i] = &p;

    int sum = 0;
    const std::size_t size = v.size();
    for (int i = 0; i < size; ++i)
        sum += v[i]->value();

    std::cout << sum << std::endl;
    return 0;
}
```

We have an array of the child class `ConstValueProvider`. The goal is to
compute the sum of the values. In this state, to call the method `value()`, the
compiler has no other choice than finding the method address in the good
virtual table which is done like this with no optimization.

```asm
  call std::array<ValueProviderBase*, 100000ul>::operator[](unsigned long)
  movq (%rax), %rax
  movq (%rax), %rdx
  movq (%rdx), %rdx
  movq %rax, %rdi
  call *%rdx
```

The `std::array<>::operator[](unsigned long)` returns a pointer to a pointer to the real
object in memory in `%rax`. We dereference it and then get the address of the
appropriate vtable stored in `%rdx`. Finally we store the address of the method
in the `%rdx` register that is used to make the call.

The reason of this is that generally the compiler has no chance to know what
really is in the array.

In our case, the array is filled with a unique subtype of `ValueProviderBase`.
Even, static cast  would not help because there could be some subclasses of
`ConstValueProvider` in the array. This means that in C++ 98/03, the developer
had no chance to help the compiler.

With C++11, we have a way to tell the compiler that the class won't subclassed
(or a particular method): it is the keyword `final`.  This makes a big
difference because if we tell the compiler to trust us on the real types
contained in the array, he will be smart enought to avoid using the vtable
indirection.

```cpp
class ConstValueProvider : public ValueProviderBase
{
public:
    virtual int value() override final {return 42;}
};

// ...

int main(int argc, const char* argv[])
{
    // ...
    for (int i = 0; i < kMax; ++i)
        sum += static_cast<ConstValueProvider*>(v[i])->value();
    // ...
}
```

Without optimization requested, gcc would do a direct call to
`ConstValueProvider::value()`:

```asm
  call std::array<ValueProviderBase*, 100000ul>::operator[](unsigned long)
  movq (%rax), %rax
  movq %rax, %rdi
  call ConstValueProvider::value()
```

Better ! And if we set an optimization level greater than 1, the call can be inlined.
And still better, the result of the whole loop can be computed at compile time:

```asm
main:
  subq $8, %rsp
  movl $4200000, %esi
  movl std::cout, %edi
  call std::basic_ostream<char, std::char_traits<char> >::operator<<(int)
```

The value `4200000` is directly passed in `%esi` to be displayed ! We got rid
of any function call.

As a side note, gcc is smart enought to suggest where you should add the final
keyword when the warning options `-Wsuggest-final-types` and
`-Wsuggest-final-methods` are provided.

# R-value References & Move Semantic

From the start, C++ used to copy objects by default. But a copies take
resources and time. So a smart way to cope such copies was to use reference for
instance when passing arguments to a function:

```cpp
void f1(X x) {} // Pass by copy
void f2(X& x) {} // Pass by reference
```

But sometimes, the copy mechanism is not appropriate for your needs. For
instance, imagine a vector whose size grows so much that it has to be
reallocated, then all the objects were copied into the new vector before
deletion of the old one. This is not a bad thing: the vector would not take the
risk starting to move objects around if at some point in the mechanism, an
error could occur.

Another use case is that you defined an object that handles a resource and this
management must not be done by several objects: what you want here is to avoid
sharing the resource ownership. What would be the meaning of sharing a
`std::mutex` or a `std::thread` ?

That's why an optimized mechanism to move the object in memory was added to the
C++ standard. This mechanism relies upon 'move constructor' and 'move equal
operator'.

I won't deal too long with this topic but in terms of performance I was striked
by two things:

- the fact the STL is 'move-ready'. The basic structures like `std::string`
will be automatically moved when needed. Often, compiling a program with the
last C++ standard version leads to higher performances... for free ! Morever,
the containers provides some API to avoid useless copy like
`std::vector<>::emplace_back`.
- the importance of the new C++ keyword `noexcept`. As a result, this keyword
has to be placed after each function that does not throw exception. This give
hints to the compiler to enable the move of objects like it is the case when a
`std::vector` has to reallocate all the contained objects when growing.

```cpp
template <int N>
class X {
public:
    X() : buffer_(std::make_unique<char[]>(N)) {}
    X(const X& other) : buffer_(std::make_unique<char[]>(N))
    {
        std::memcpy(buffer_.get(), other.buffer_.get(), N);
    }
    X& operator=(const X& rhs)
    {
        buffer_.reset(new char[N]);
        std::memcpy(buffer_.get(), rhs.buffer_.get(), N);
        return *this;
    }

    X(X&& other) noexcept : buffer_(std::move(other.buffer_)) {}
    X& operator=(X&& rhs) noexcept
    {
        buffer_ = std::move(rhs.buffer_);
        return *this;
    }
private:
    std::unique_ptr<char[]> buffer_;
};

constexpr int kMax = 300'000;

int main(int argc, const char *argv[])
{
    std::vector<X<1000>> v;
    v.reserve(kMax);
    for (int i = 0; i < kMax; ++i)
    {
        v.emplace_back();
    }
    // One more to for vector realloacation
    v.emplace_back();
    std::cout << v.size() << std::endl;
    return 0;
}
```

Using `noexcept` or not on the move constructor have an impact during
reallocation:
- if `noexcept` is not used, `std::vector` will use the copy constructor
- if `noexcept` is used, `std::vector` will use the move constructor

In the second case, this avoids the call to `std::memcpy`. Hence, the better
performances.

Without `noexcept`:

```bash
stac@debian:~/development/cpp-sandbox/vector>time ./a.out
300001
./a.out  0.15s user 0.20s system 99% cpu 0.353 total
```

With `noexcept`:

```bash
stac@debian:~/development/cpp-sandbox/vector>time ./a.out
300001
./a.out  0.05s user 0.10s system 97% cpu 0.149 total
```

# STL Containers

Choosing a container depends upon how you will use it, so it is worth knowing
about their internal structure and the complexity of the methods/functions you
will call most often.

For example, the best container for appending data is `std::deque` because as
its internal structure is an contiguous array of pointers toward arrays of
contiguous memory containing the objects, there is no need for reallocation the
contained objects as it is the case with `std::vector`. Nevertheless, if you
know the number of elements that will be stored, you can use the
`std::vector<>::reserve` method and in this case the `std::vector` becomes the
best.  Conversely, due to the tree structure of the `std::set` container and
the fact the objects are always ordered, this is the worse container.

A new type container appeared also in C++11: `std::unordered_set` and its
counterpart key-value `std::unordered_map`. Because of its structure, based on
hashes, insertion is faster than in a `std::set` and lookup become blazing fast
compared to `std::vector` and `std::deque`.

Regarding lookup of values in containers, if `std::find` algorithm is correct
for `std::vector` and `std::deque`, it is far better to use the `find` method
of `std::set` and `std::unordered_set`.

Note that to have similar performance with `std::vector`, if the elements are
sorted, `std::lower_bound` is the best alternative to `std::find` algorithm.

Last but not least, it really seems that `std::list` due to its poor
performances, must not be the first container choice.

# Strings

## New ABI

Strings is one of the most common objects used in programs. Its definition has
changed between C++98 and C++11.

In C++98, the standard specification fostered the use of references counting to
allow the copy-on-write optimization. Now that C++11, provides threading
support, the standard forbids hidden states in `std::string` (reference
counters need atomics or locks in multithreaded environment).

The `std::string` is no more binary compatible between gcc 4 and gcc 5. Before,
a `std::string` only had a pointer to a structure containing the size, the
capacity, the reference counter and the buffer. The later is now 32 bits
structure (64-bits machine architecture).

A noteworthy fact is the Small String Optimization (SSO): if the string
contains less than 16 bytes, there is no heap memory allocation (the small
buffer is store in place of the pointer to the location of the `char[]` on the
heap.

## C++17 std::string_view

There is a new interesting structure coming with C++17: `std::string_view`.
Often, you have a `char[]` allocated on heap and filled with some data.
Generally, to avoid the overhead of the copy, you don't dare using
`std::string` and its facilities. So, you end up using the C primitives to read
things in this `char[]`. Moreover, as the length of the buffer is lost (you
only have a pointer to the first element of the buffer), you have to convey the
size of the buffer in all the function signatures).

To cope with this limitation, `std::string_view` was introduced to provide a
read only access to a buffer with the size and a standard API to get iterators
on the buffer elements.

```cpp
#include <iostream>
#include <algorithm>
#include <string_view>

int main(int argc, const char *argv[])
{
    std::string_view sv(argv[1]);
    std::cout << "Size: " << sv.size() << std::endl;
    std::cout << "Number of A: "
              << std::count(sv.begin(), sv.end(), 'A')
              << std::endl;
    return 0;
}
```

The result:

```
stac@saturne:~>./a.out jhsfhsdAAAsdfjhsdkjAAsldkfjsdlkA
Size: 32
Number of A: 6
```

In this example, I used the constructor based on null-terminated `char[]`, but
you can use `std::string_view` to work with raw contiguous memory.

The advantage of this `std::string_view` is it allows you to write C++ style
code that looks like less old C style without the overhead of costly copies.
