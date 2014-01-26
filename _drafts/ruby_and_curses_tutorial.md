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
first attemps where not that successful (`require 'curses'` failed). Googling
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

This done, we are ready to start the curse tutorial.

# Vocabulary and Initialization

A **window** is a regular area on your terminal screen. It can be either the
whole screen or a smaller part of the screen. You can create as many windows as
you want but there is one, named **stdscr**  (standard screen) which is created
on initialization. It takes the maximum lines and columns available on the
current terminal.

Hence, before using *curses* you have to initialize the library: this step will
gather information on your terminal and save the current modes (see
`Curses.def_prog_mode`). You will be able to access these data as
it is shown in the following example:

{% highlight ruby %}
require 'curses'

Curses.init_screen
begin
  nb_lines = Curses.lines
  nb_cols = Curses.cols
ensure
  Curses.close_screen
end

puts "Number of rows: #{nb_lines}"
puts "Number of columns: #{nb_cols}"
{% endhighlight %}

To use the *curses* library in a program you need to load it thanks to the
**require** statement which gives you access to the Curses module. The
`Curses.init_screen` initializes *curses*, we retrieved the number of lines and
colomns available on the *stdscr*. To be sure *curses* is stopped at the end of
the program execution, the call to `Curses.close_screen` is inclosed in an ensure
block (so the terminal modes that where saved during initialization are
restored with `Curses.reset_prog_mode`).

Notice that we could have included the Curses module to avoid repeating the
Curses word in front of each function call.

{% highlight ruby %}
require 'curses'
include Curses
init_screen
begin
  nb_lines = lines
  nb_cols = cols
ensure
  close_screen
end
{% endhighlight %}

After initialization, you can set several options. Generally, you don't want to
display the keys that are pressed by the user when they are catched by the
`Curses.getch` function or the `Curses::Window.getch` method. To disable this,
you can use `Curses.noecho`. To reactivate it, `Curses.echo` is available.

When working in a terminal, commands are buffered until the user press Enter.
You generally will not expect this behaviour when writting a graphical user
interface and you will want the key to answer as soon as they are pressed. This
is what the **cbreak mode** has been created for. To toggle between these two
modes, you can use `Curses.cbreak` and `Curses.nocbreak` functions or their
aliases `Curses.crmode` and `Curses.nocrmode`. If you want disable the
interpretation of the interrupt, quit or suspend characters, you can enter the
**raw** mode thanks to `Curses.raw` and exit this mode with `Curses.noraw`.

Pressing <Return> key results normally in a new line. This behaviour can be
deactivated with `Curses.nonl` function and `Curses.nl` will restore the
default behaviour.

Another interesting thing is to control the visibility of the cursor with the
`Curses.curs_set(visibility)` function where *visibility*  can take 0
(invisible), 1 (visible) or 2 (very visible).

# Colors initialization

Today, many terminals applications can display colors. If you want to use this
facility, you must call the `Curses.start_color` just after the call to
`Curses.init_screen`. To test if your terminal supports colors, Curses provides
the following method `Curses.has_colors?`.

Text attribute is a set of flags linked to the way you want the text to be
displayed. For instance, you may want to display a blinking text in red on a
blue background. So, there are special attributes relative to special effect
and, regarding colors, attributes are defined as pairs composed of the
foreground color and the background color.

Hereafter is a list of special effets with there builtin values:

| Effect                              | Constant name                |
| ----------------------------------- | ---------------------------- |
| Text blinking                       | Curses::A_BLINK              |
| Text in bold                        | Curses::A_BOLD               |
| Text half bright                    | Curses::A_DIM                |
| Invisible text                      | Curses::A_INVISIBLE          |
| No highlight                        | Curses::A_NORMAL             |
| Reverse foreground & background     | Curses::A_REVERSE            |
| Underlined text                     | Curses::A_UNDERLINE          |
| Text with good highlight            | Curses::A_TOP                |
| Best highlighting                   | Curses::A_STANDOUT           |

# Using windows

Using the functions exposed by the *Curses* module will implicitly work on the
*stdscr*. You can move the cursor on this screen and display a message wherever
you want thanks to the `Curses.setpos` function. Be careful: the position is
defined by a couple (line, columns) with origin at the top-left corner.

{% highlight ruby %}
require 'curses'

Curses.init_screen
begin
  x = Curses.cols / 2  # We will center our text
  y = Curses.lines / 2
  Curses.setpos(y, x)  # Move the cursor to the center of the screen
  Curses.addstr("Hello World")  # Display the text
  Curses.refresh  # Refresh the screen
  Curses.getch  # Waiting for a pressed key to exit
ensure
  Curses.close_screen
end
{% endhighlight %}

[1]: http://rvm.io
[2]: http://rubygems.org
[3]: https://bugs.ruby-lang.org/issues/8584
[4]: https://bugs.ruby-lang.org/issues/9364
[5]: http://docs.python.org/3/howto/curses.html#curses-howto
[6]: http://tmux.sourceforge.net/
