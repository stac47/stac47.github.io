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
the Python library and so seems it to be the case in Ruby's stdlib. I dare say my
first attempts where not that successful (`require 'curses'` failed). Googling
around, I found out that it was removed from the stdlib in [2.1.0 release][3]
even if it was still in the official documentation ([bug][4]).

This small issues solved, I looked for tutorials but the amount of
documentations is not that high. Hence, the aim of this post: having the same
level of tutorial for curses as it is in [Python documentation][5]. I don't
think that a Rubyist should look at the original C documentation of *curses* to
start with curses ruby binding.

#Curses and Ruby

Basically, curses is an old library distributed on many Unix distribution whose
goal was to manipulate a terminal screen to draw windows, to display some text
and also to handle the input events (keyboard, mouse). In this sense, it was an
ancestor of graphical user interfaces.

![Terminal view](/img/posts/2014_01_24-ruby-and-curses-tutorial-1.png "Pyradio: a cool radio player in CLI")

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
gather information about your terminal and save the current modes (see
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
columns available on the *stdscr*. To be sure *curses* is stopped at the end of
the program execution, the call to `Curses.close_screen` is enclosed in an ensure
block (so the terminal modes that where saved during initialization are
restored with `Curses.reset_prog_mode`). This will avoid messing up your
terminal if an error occurs.

Notice that we could have included the Curses module to avoid repeating the
Curses namespace all along the program.

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
display the keys that are pressed by the user when they are caught by the
`Curses.getch` function or the `Curses::Window.getch` method. To disable this,
you can use `Curses.noecho`. To reactivate it, `Curses.echo` is available.

When working in a terminal, commands are buffered until the user press Enter.
You generally will not expect this behaviour when writing a graphical user
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

Hereafter is a list of special effects with there builtin values:

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

Defining color attributes is done with the `Curses.init_pair(pair, fg, bg)`. A
pair for colors are associated to an id. For instance, if you want to use red
color to write on a blue background, you can define a key pair as shown below:

{% highlight ruby %}
Curses.init_pair(1, Curses::COLOR_RED, Curses::COLOR_BLUE)
{% endhighlight %}

To turn this pair into an attribute, you have to use the
`Curses.color_pair(pair)` function.

Now, previously described attributes can be OR'ed to be used altogether and
passed to the `Curses.attrset(attr)`. In the following code snippet, "Hello
World" will blink on the screen written in red on a blue background.

{% highlight ruby %}
Curses.attrset(Curses.color_pair(1) | Curses::A_BLINK)
Curses.addstr("Hello World")
{% endhighlight %}

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

Generally, you will want to create several windows on the screen or access the
*stdscr* in a more object oriented fashion. This is the purpose of the
`Curses::Window` object. You can access the *stdscr* Window object thanks to
the function `Curses.stdscr`.

Many functions defined in `Curses` module like `addstr`, `getch` are simply a
shortcut to the `Window.addstr` or `Window.getch` called on the *stdscr* Window
object. Hence, until the end of this tutorial, we will talk only about the
methods defined on `Window` object.

The previous example could be rewritten as follows:

{% highlight ruby %}
require 'curses'

Curses.init_screen
begin
  win = Curses.stdscr
  x = win.maxx / 2
  y = win.maxy / 2
  win.setpos(y, x)
  win.addstr("Hello World")
  win.refresh
  win.getch
ensure
  Curses.close_screen
end
{% endhighlight %}

But windows become an interesting feature when you need to manage several parts
of the screen with different refresh cycles. Curses was created in the old ages
when the terminal had very slow connection to the server and refreshing the
whole screen every time would not have been optimized.

With a Window, you define a rectangular area inside the screen (for
unrestricted area, please have a look at `Curses::Pad` object). Each window has
its own dimension and upper-left corner origin that you can pass to the
constructor `Curses::Window.new(height, width, top, left)`. There are several
methods on this object that need to be understood for the next example:

- `maxx` and `maxy` returns the maximum coordinates reachable in a window.
- `box(vert, hor)` will surround the windows with the *vert* and *hor*
characters.
- `setpos(y, x)` will move the cursor at position (y, x) relatively to the
current window origin.
- `addstr(str)` or `<<(str)` alias will display the *str* text at the current
cursor position.
- `refresh` will redraw your window. It is an important method; windows are not
updated as soon as they are modified but have to be manually refreshed. This
way, you can make several modifications and wait to have the screen in an
expected state to publish the new screen. This was of course very relevant on
old terminals.
- `clear` will erase the window. Note that you will have to call the `refresh`
method to see a change.
- `close` will free the memory dedicated to the current window object. Trying
to display something in this window will lead to a `RuntimeError`. This method
do not clear the window.

{% highlight ruby %}
require 'curses'

Curses.init_screen
Curses.curs_set(0)  # Invisible cursor

begin
  # Building a static window
  win1 = Curses::Window.new(Curses.lines / 2 - 1, Curses.cols / 2 - 1, 0, 0)
  win1.box("o", "o")
  win1.setpos(2, 2)
  win1.addstr("Hello")
  win1.refresh

  # In this window, there will be an animation
  win2 = Curses::Window.new(Curses.lines / 2 - 1, Curses.cols / 2 - 1, 
                            Curses.lines / 2, Curses.cols / 2)
  win2.box("|", "-")
  win2.refresh
  2.upto(win2.maxx - 3) do |i|
    win2.setpos(win2.maxy / 2, i)
    win2 << "*"
    win2.refresh
    sleep 0.05 
  end

  # Clearing windows each in turn
  sleep 0.5 
  win1.clear
  win1.refresh
  win1.close
  sleep 0.5
  win2.clear
  win2.refresh
  win2.close
  sleep 0.5
rescue => ex
  Curses.close_screen
end
{% endhighlight %}

# Managing keyboard input

Basically, a user will interact with the terminal thanks to his keyboard and
this is what this chapter will deal with. We won't talk about the ability to
handle the mouse control in this tutorial.

You have one main way to capture the keys the user pressed: `Window.getch` will
wait by default the user to press a key and return an uninterpreted value
(pressing 'a' will return 'a', pressing 'F8' will return a code). This default
behavior can be changed in two ways.

First the blocking nature can be deactivate with `Window.nodelay=(bool)`
method. If the value is set to `true`, the method `getch` won't wait for the
user input.

Second allowed change is the fact that Curses can interpret the key pressed.
This is activated by the `Window.keypad=(bool)` method. If the value `true` is
passed to this method, when the left key is pressed, the `getch` method will
return `Curses::Key::LEFT`. All the keys are mapped inside the `Curses:Key`
module. The following example shows this in action:

{% highlight ruby %}
input = win.getch
if input == Curses::Key::LEFT then
    win.addstr("Left key")
else
    win.addstr("Other key")
end
win.refresh
{% endhighlight %}

There is another method dedicated to capturing the user input:
`Windows.getstr`. This method is probably less useful than `Window.getch` but
can be handy in some situations. This method, by default, waits for the user
input but continue acquiring the characters pressed until the user press
**Enter**. The return value is a string.

You probably wonder why the `getch` method is attached to a window object. It
could be a general function defined at Curses module level (In fact, it is the
case, but it is only a shortcut to `Curses.stdscr.getch`). Actually, the window
on which you call the method takes the focus. This means overlapping windows
will put in the background. Let's have a look at what happens when you draw
some windows and call `Curses.getch`.

{% highlight ruby %}
  win1 = Curses::Window.new(10, 20, 0, 0)
  win1.box("|", "-")
  win1.refresh
  input = Curses.getstr
{% endhighlight %}

The window 'win1' will quickly appear and fade out because the **stdscr** will
gain the focus and we can say it will come upfront hiding as a metter of fact
'win1'.

A solution to this is to create subwindows of the *stdscr* windows. *stdscr*
can then be considered as a container. Creating a subwindows is done with the
`Window.subwin(height, width, top, left)`.

{% highlight ruby %}
  win1 = Curses.stdscr.subwin(10, 20, 0, 0)
  win1.box("|", "-")
  win1.refresh
  input = Curses.getstr
{% endhighlight %}

# More information about Curses

- Of course the best documentation is inside the manual pages: `$ man ncurses`.
- <http://tldp.org/HOWTO/NCURSES-Programming-HOWTO/> is a good documentation
about the C API which goes deeper than this one.

# A last word

I hope this is a good start point Curses Ruby API and this will be useful.

If you spot some errors or have any suggestion about this text, please open an
issue on <https://github.com/stac47/stac47.github.io>.

[1]: http://rvm.io
[2]: http://rubygems.org
[3]: https://bugs.ruby-lang.org/issues/8584
[4]: https://bugs.ruby-lang.org/issues/9364
[5]: http://docs.python.org/3/howto/curses.html#curses-howto
[6]: http://tmux.sourceforge.net/
