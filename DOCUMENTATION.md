# Welcome to MiniBASIC

MiniBASIC is a classic BASIC interpreter with these design goals:

1. Compatible with 1980s-era code listings, books, and magazines, including such beautiful and fun gems as the [classic Usborne BASIC Programming Books](https://usborne.com/us/books/computer-and-coding-books).

2. Friendly and easy to use, with features like input history (just press up-arrow!) and modern line-editing.

3. A powerful virtual retro computer, with full-color 960x640 resolution graphics and sound, that runs on any modern desktop machine.

That last design goal is achieved by running MiniBASIC on [Mini Micro](https:miniscript.org/MiniMicro/), a powerful neo-retro virtual computer.  (If you like what you can do in MiniBASIC, you will _love_ what you can do in Mini Micro's native language of [MiniScript](https://miniscript.org/)!)

## Overview

## Functions

The following built-in functions are available in MiniBASIC.  These must be used as an argument to a command, or as part of some larger expression.

| Function | Result |
|----------|--------|
| ABS(_n_) | absolute value of _n_ |
| ASC(_a$_) | Unicode code point of the first character in _a$_; inverse of CHR$ |
| ATN(_n_) | arctangent of _n_ radians; inverse of TAN |
| CHR$(_n_) | character with the Unicode code point _n_; inverse of ASC |
| COS(_n_) | cosine of _n_ radians |
| EXP(_n_) | [e](https://en.wikipedia.org/wiki/E_(mathematical_constant))^_n_ |
| FIX(_n_) | integer portion of _n_, i.e., whole number neighboring _n_ closest to 0 |
| INKEY$(_z_) | pulls and returns the first character waiting in the keyboard buffer, if any, else returns "" |
| INT(_n_) | next integer equal to or less than _n_ (generally called _floor_ in other languages) |
| INSTR(\[_start_,] _a$_, _b$_) | 1-based index of substring _b$_ within _a$_, optionally starting at _start_; 0 if not found |
| LEFT$(_a$_, _n_) | leftmost _n_ characters of string _a$_; see also MID$, RIGHT$ |
| LEN(_a$_) | length of (i.e. number of characters in) _a$_ |
| LOWER$(_s_) | string _s_ converted to lowercase; see also UPPER$ |
| MID$(_a$_, _n_ \[, _m_\]) | substring of _a$_ starting at _n_ and containing up to _m_ characters; if _m_ is not specified, returns the rest of _a$_ |
| POS(_n_) | when _n_ is even, returns the current text cursor column; when odd, returns text cursor row |
| RIGHT$(_a$_, _n_) | rightmost _n_ characters of string _a$_; see also LEFT$, MID$ |
| SGN(_n_) | sign of _n_, i.e. 1 if _n_ > 0, -1 if _n_ < 0, and 0 if _n_ = 0 |
| SIN(_n_) | sine of _n_ radians |
| SPACE$(_n_) | a string composed of _n_ space characters |
| SPC(_n_) | immediately prints _n_ space characters, then returns "" |
| SQR(_n_) | square root of _n_ |
| STR$(_n_) | converts number _n_ into a string using standard formatting |
| TAB(_n_ \[, _m_\]) | given both _n_ and _m_, moves text cursor to row _m_, column _n_; given only _n_, advances the text cursor to column _n_ only if it is currently less than that; returns "" |
| TAN(_n_) | tangent of _n_ radians |
| UPPER$(_a$_) | string _a$_ converted to uppercase; see also LOWER$ |
| VAL(_a$_) | converts _a$_ to a number, if possible; else 0 |

## Commands

The following table lists all MiniBASIC commands.  A command is used as a statement on its own, either in immediate mode or as part of a program line; it may not be used as part of a larger expression.

| Command | Effect |
|---------|--------|
| CLEAR | clears all variables from memory (but leaves program intact) |
| CLS | clears the screen (both text and graphics); resets the text cursor to row 26, column 0; and resets the plot point to 0,0; HOME is a synonym |
| COLOR _x_ | if _x_ is a number, sets text and graphic color to palette color _x_ (0-15); if a _x_ is a string, sets text and graphic color to that HTML color (e.g. "#FF000088" for transparent red) |
| DATA _list_ | defines a comma-separated list of data for use with READ and RESTORE.  Data elements may be strings or numbers; strings must be enclosed in quotes if they contain spaces or punctuation |
| DEF FN _name_(_n_) = _expr_ | define a user-defined function; subsequent use of FN _name_(_n_) will be evaluated as expression _expr_, with the actual value substituted for _n_ |
| DIM _name_(_n_ \[,_m_ ...\]) | declare an array with valid indexes from 0 to _n_ inclusive, or a multidimensional array with additional dimensions _m_, etc.  Array will be numeric unless _name_ ends in `$`, in which case it is a string array |
| END | halts the current program and returns to the MiniBASIC prompt; STOP is a synonym |
| FOR _var_ = _n_ TO _m_ \[STEP _s_\] | begins a FOR loop running from _n_ to _m_, steps of _s_ (default 1) |
| GET _var_ | waits for a keypress to appear in the keyboard buffer, then returns it.  If _var_ is a string variable, returns the character pressed; if it is a numeric variable, returns the ASC value of the character pressed |
| GOSUB _lineNum_ | pushes the next statement onto the RETURN stack, then jumps to line _lineNum_ |
| GOTO _lineNum_ | jumps to line _lineNum_ |
| HOME | clears the screen (both text and graphics); resets the text cursor to row 26, column 0; and resets the plot point to 0,0; synonym for CLS |
| HTAB _n_ | moves the text cursor to column _n_; see also VTAB |
| IF _expr_ THEN _result1_ \[ELSE _result2_] | if _expr_ is true (nonzero), then do _result1_, which may be either a line number to jump to, or one or more statements joined by `:`; otherwise jump to _result2_ if specified, or the next line.  If statements may be nested. |
| INPUT \[prompt\, ] _var_ \[, _var2_ ...] | prints "?" if no _prompt_ specified, or if _prompt_ is followed by `;`; then waits for the user to enter a value to be stored in _var_ (or several values, separated by whitespace or commas, to be stored in _var_, _var2_, etc.).  Note that when reading into a string variable, input stops at a comma **unless** it is the last variable in the input list, in which case it reads all the way to the line break |
| \[LET\] _var_ = _expr_ | assigns the value of _expr_ to the variable _var_, which must be of the same type.  Note that `LET` is optional |
| LINE _x_, _y_ | draws a line from current plot position, to position _x_ (0-959, measured from left side of screen) by _y_ (0-639, measured from bottom of screen) in the current COLOR, and updates the plot position to the new coordinates |
| NEXT \[_var_ \[, _var2_ ...\]\] | increments the nearest or specified FOR loop variable and jumps to the top of the loop, unless that loop is complete, in which case it advances to the next specified variable or the next statement |
| ON _expr_ GOTO _lineNum1_, _lineNum2_, ... | jumps to the line number corresponding to the (floored) value of _expr_, starting at 1 for _lineNum1_, etc.  If _expr_ evaluates to less than 1 or more than the number of line numbers given, control proceeds to the next statement |
| PLOT _x_, _y_ | plots pixel _x_ (0-959, measured from left side of screen) by _y_ (0-639, measured from bottom of screen) in the current COLOR, and sets the plot position used with subsequent LINE |
| STOP | halts the current program and returns to the MiniBASIC prompt; synonym for END |

