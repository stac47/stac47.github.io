---
layout: post
title:  "Vim: Advanced Cheat Sheet"
date:   2014-02-22 15:28:07
categories: vim cheat sheet
---

# Vim: Advanced Cheat Sheet

## Moving in a Document from Normal Mode

Full documentation at: `:h motion.txt`.

### Word Movements

A *word* is a sequence of characters or digits plus the underscore character.
A *WORD* is a sequence of characters separated with any kind of spaces.

Keystrokes   | Movement
------------ | ---------------------------------------------------------------
`w`/`W`      | Forward to start of next word / WORD
`b`/`B`      | Backward to start of previous word / WORD
`e`/`E`      | Forward to end of next word / WORD
`ge`/`gE`    | Backward to end of next word / WORD

### Character-Search Movements

Documentation at: `:h f`.

Keystrokes   | Movement 
------------ | ---------------------------------------------------------------
`f{char}`    | Forward to the next occurence of *char*
`F{char}`    | Backward to the previous occurence of *char*
`t{char}`    | Forward to the character before the next occurence of *char*
`T{char}`    | Backward to the character after the previous occurence of *char*
`;`          | Repeat the last Character-search movement
`,`          | Reverse the last Character-search movement

### Text Objects

Not used to move the cursor, but useful as a motion within a command.
Documentation at: `:h text-objects`

Keystrokes   | Movement 
------------ | ---------------------------------------------------------------
`iw`/`iW`    | Current word/WORD
`aw`/`aW`    | Current word/WORD plus one space
`is`         | Current sentence
`as`         | Current sentence plus one space
`is`         | Current paragraph
`as`         | Current paragraph plus one space

The following Text Objects interact with pair delimiters like '"', ')' or '}'.

Keystrokes   | Movement 
------------ | ---------------------------------------------------------------
`a)` or `ab` | A pair of parentheses
`i)` or `ib` | Inside a pair of parentheses
`a}` or `aB` | A pair of braces
`i}` or `iB` | Inside a pair of braces
`a]`         | A pair of square brackets
`i]`         | Inside a pair of square brackets
`a>`         | A pair of angle brackets
`i>`         | Inside a pair of angle brackets
`a'`         | A pair of single quotes
`i'`         | Inside a pair of single quotes
`a"`         | A pair of double quotes
`i"`         | Inside a pair of double quotes
``a` ``      | A pair of backticks
``i` ``      | Inside a pair of backticks
`at`         | A pair of xml tags
`it`         | Inside a pair of xml tags

### Operators

All the motion described above can be used with operators to modify the file
from the **Normal Mode**.

Keystrokes   | Ex command      | Action
------------ | --------------- | ---------------------------------------------
`c`          | `:change`       | Change: delete + swith to **Insert Mode**
`d`          | `:delete`       | Delete
`y`          | `:yank`         | Yank into register
`g~`         |                 | Swap case
`gu`         |                 | To lower case
`gU`         |                 | To upper case
`>`          |                 | Shift right
`<`          |                 | Shift left
`=`          |                 | Auto-indent

Examples

- `daw` : Delete A Word
- `ci]` : Delete what is inside of square brackets and switch to 
**Insert Mode**
- `=i}` : Auto indent the content of {...}

### Compound commands

Compound command | Equivalent | Action
-----------------| ---------- | ----------------------------------------------
`C`              | `c$`       | Change until the end of the line
`s`              | `cl`       | Change the letter under the cursor
`S`              | `^C`       | Change the current line
`I`              | `^i`       | Insert at the begining of the line
`A`              | `$a`       | Insert at the end of the line
`o`              | `A<CR>`    | Insert a new line after the current line
`O`              | `ko`       | Insert a new line before the current line

## Jumps

Documentation at `:h jump`.

### Basic Jumps

Keystrokes        | Jump description
----------------- | -----------------------------------------------------------
`{number}G`       | Jump to the line *number*
`%`               | Jump to the matching parentheses
`(` / `)`         | Jump to previous/next sentence
`{` / `}`         | Jump to previous/next paragraph
`H` / `M` / `L`   | Jump to the top / middle / bottom of the screen

### Marked Jumps

A user has access to 52 markers corresponding to the alphabetic lower and
upper case characters: [a-zA-Z]. There other marks described latter.

Documentation at: `:h Mark`.

#### Basic Marks

Keystrokes        | Jump description
----------------- | -----------------------------------------------------------
`m{a-zA-Z}`       | Set mark at cursor position
`` `{mark}``      | Move the cursor to the exact position of the *mark* mark 
`'{mark}`         | Move the cursor to the begin of the line where the mark *mark* was defined

#### Automatic Marks

Mark              | Function
----------------- | -----------------------------------------------------------
`` ` ``           | Location before the last jump
`.`               | Location of the last change
`[`               | Start of the last change or yank
`]`               | End of the last change or yank
`<`               | Start of the last visual selection
`>`               | End of the last visual selection

### Navigation through the history of jumps

History of the jumps are accessible thanks to the Ex command `:jump`.

Keystrokes        | Description
----------------- | -----------------------------------------------------------
`<C-o>`           | Backward through the history of jumps.
`<C-i>`           | Foreward through the history of jumps.

## Visual Mode

Documentation at: `:h visual-mode`.

### Enter Visual Mode

Keystrokes        | Description
----------------- | -----------------------------------------------------------
`v`               | Enter visual mode characterwise
`V`               | Enter visual mode linewise
`C-v`             | Enter visual mode blockwise
`gv`              | Reselect the last visual selection

### Exit Visual Mode

Keystrokes        | Description
----------------- | -----------------------------------------------------------
`<ESC>`           | Exit visual mode
`v`               | Exit visual from visual mode characterwise
`V`               | Exit visual from visual mode linewise
`C-v`             | Exit visual from visual mode blockwise

### Switch Visual Mode Type

Keystrokes        | Description
----------------- | -----------------------------------------------------------
`v`               | Switch to visual characterwise from line/block wise
`V`               | Switch to visual linewise from character/block wise
`C-v`             | Switch to visual block from character/line wise

### Operations in Visual Mode

Keystrokes        | Description
----------------- | -----------------------------------------------------------
`~`/`d`/`y`...    | Switch case/Delete/Yank... See `:h visual-operators`
`o`               | Go to other end of highlighted selection

## Insert Mode

Keystrokes            | Description
--------------------- | -----------------------------------------------------------
`<C-h>`               | Like backspace
`<C-w>`               | Delete the previous word
`<C-u>`               | Remove the current line (like in shell)
`<C-o>`               | Switch to Insert Normal Mode
`<C-v>{code}`         | Insert special character by its code
`<C-k>{char1}{char2}` | Insert special character by digraph

Example:

- In french, to insert 'œ' simply type: `<C-k>oe`.
- The 'ù' letter in french is only used in one word but has its own key. You can
also use ``<C-k>`u``.

## Registers

Documentation at: `:h reg`.

User's registers ([a-z]) are called Named Register. They are accessible:

- from Normal Mode with `"` (e.g. `"ay` will yank into register **a**)
- from Insert/CmdLine/Replace Modes with `<C-r>{register}`

### Special Registers

Register | Meaning
-------- | -------------------------------------------------------------------
`"`      | Unnamed register is the default register.
`_`      | Black Hole register: putting something in it is lost.
`0`      | By default, yanking operation fills this register.
`1`..`9` | The history of the delete/yank is stored in these registers.
`+`      | System Clipboard Register.
`*`      | System Clipboard Register.
`=`      | Expression Register.
`%`      | Name of the current file.
`/`      | Last search command.
`:`      | Last Ex command.
`.`      | Last inserted text.

Example:

- In Insert Mode, `<C-=>5*6<CR>` will display '30'.
- To definitively delete something you can use `"_d`.
- To paste something in Vim for your OS Clipboard, `"*p`.

## Macros

Documentation at: `:h complex-repeat`.

Keystrokes            | Description
--------------------- | -----------------------------------------------------------
`q{register}`         | Start recording a macro in **register**
`q{REGISTER}`         | Amend the **register** (use uppercase named register)
`@{register}`         | Play the macro in **register**

## Search and Substitute

### Search

Documentation at `:h /`.

Keystrokes            | Description
--------------------- | -----------------------------------------------------------
`/{pattern}<CR>`      | Search forward **pattern**.
`?{pattern}<CR>`      | Search backward **pattern**.
`n`                   | Next matching element.
`N`                   | Previous matching element.
`/\v{pattern}<CR>`    | Search forward **pattern** in very magic mode.
`/\V{text}<CR>`       | Search forward the exact **text**.
`/<CR>`               | Search forward last **pattern**.

### Substitute

Documentation at: `:h substitute`.

#### Basics

Keystrokes            | Description
--------------------- | -----------------------------------------------------------
`:s/old/new`          | Substitute the first matching *old* into *new* in the current line
`:s/old/new/g`        | Substitute all the matching *old* into *new* in the current line.
`:%s/old/new/g`       | Substitute all the matching *old* into *new* in the current file.
`:%s/old/new/gc`      | Substitute all the matching *old* into *new* in the current file with confirmation request.
`:5,8s/old/new/g`     | Substitute all the matching *old* into *new* between line 5 and 8.

Side note: When in Visual Mode, pressing `:` will automatically fill the range
corresponding to the select block of text.

#### Tips

##### Substitute in several files

1. Fill the args with the list of file to modify: `:args **/*.cpp`.
2. Apply the substitution: `:argdo %s/old/new/g`.

##### Convert from CamelCase to underscore_case

The trick is to use: 

- the `\l` (lowercase 'L'). Documentation at: `:h \l`.
- the `\1`, `\2`... syntax. Documentation at: `:h pattern`.

This gives the following command: `:%s/\v(\l)(\u)/\1_\l\2/gc`.
