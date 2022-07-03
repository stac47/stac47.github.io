---
layout: post
title: "Vim: Massive Substitute"
tags: vim tips
---

# {{ page.title }}

In one of my previous post about "Advanced Cheat Sheet", I wrote at the end how
to make a change in a set of files using the args list (`:h args`):

1. Fill the args with the list of file to modify: `:args **/*.cpp`.
2. Apply the substitution: `:argdo %s/old/new/g`.

This is straightforward but not really efficient since Vim has to apply the
substitution on all files even if there is no match.

A more convenient and scalable way to achieve a massive substitution is to fill
the quickfix list (`:h quickfix`) with the set of file in which there are
pattern matches and then apply the substitution on this set of file with the
command `:cdo`.

1. Look for a pattern match: `:grep! fooBar`
2. Apply and save the changes: `:cdo %s/fooBar/foo_bar/ge | update`

The problem with this is that the substitute is done once per entry in the
quickfix list. So, if there are 2 'foo' partterns in a file an you want to
replace 'foo' with 'foofoo', 'foo' will be replaced with 'foofoofoofoo'.

From __vim 8.1__, the command `:cfdo` (see `:h :cfdo`) was added to apply the
command once per file (and not once per quickfix entry): the 'f' of the command
stands for 'filter'. So from vim 8.1, the procedure is:

1. Look for a pattern match: `:grep! fooBar`
2. Apply and save the changes: `:cfdo %s/fooBar/foo_bar/ge | update`
