---
layout: post
title:  "Ruby Curses Tutorial"
date:   2014-01-21 15:28:07
categories: ruby curses tutorial
---

Some times ago, I started playing with Ruby after several years coding in Java
and Python and I must admit that I really appreciated the elegance of the
syntax, the simple object model and the natural way to jump in hacking
meta-programming mode. I am not an expert but all these seduced me.

In my investigations, I usually look at the ecosystem coming with a language:
the tooling, the documentation, the way the developer community is working.
After a good surprise with the language, came another good surprise with the
available tools. For instance [RVM][1] is a really convenient way to manage the
different interpreters and the gems you install within each one from
[RubyGems][2].

I had a small project to build using *curses* library. A binding is embedded in
the Python library and so seems it to be the case in Ruby stdlib. I dare say my
first attemps where not that successful (`require 'curses'`) failed. Googling
around, I found out that it was removed from the stdlib in [2.1.0 release][3]
even if it was still in the official documentation ([bug][4]).

This light small issues solved, I looked for tutorials but the amount of
documentations is not that high. So the aim of this post: having the same level
of tutorial for curses as it is in [Python documentation][5]. I don't think
that a Rubyist should look at the original C documentation of *curses* to start
with curses ruby binding.

#Curses and Ruby

Basically, curses is an old library distributed on many Unix distribution whose
goal was to manipulate a terminal screen to draw windows, to display some text
and also to handle the input events (keyboard, mouse). In this sense, it was an
ancestor of graphical user interfaces.

Why would you want to use this today when we can manipulate a computer with a
high definition 3D graphical interface ? There could be many reasons for this:

- Some people works in terminal using [Tmux][6] or Screen and they generally
appreciate having a simple terminal interface which integrate well in their
shell panels.
- You need to provide a tool working on a minimal system (for instance, an OS
installer)

Ruby provided a binding module included in the standard library until Ruby 2.0.
To use it from Ruby 2.1 and more, you will have to install this as a gem:

    $ gem install curses

[1]: http://rvm.io
[2]: http://rubygems.org
[3]: https://bugs.ruby-lang.org/issues/8584
[4]: https://bugs.ruby-lang.org/issues/9364
[5]: http://docs.python.org/3/howto/curses.html#curses-howto
[6]: http://tmux.sourceforge.net/
