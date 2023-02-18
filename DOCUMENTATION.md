# Welcome to MiniBASIC

MiniBASIC is a classic BASIC interpreter with these design goals:

1. Compatible with 1980s-era code listings, books, and magazines, including such beautiful and fun gems as the [classic Usborne BASIC Programming Books](https://usborne.com/us/books/computer-and-coding-books).

2. Friendly and easy to use, with features like input history (just press up-arrow!) and modern line-editing.

3. A powerful virtual retro computer, with full-color 960x640 resolution graphics and sound, that runs on any modern desktop machine.

That last design goal is achieved by running MiniBASIC on [Mini Micro](https:miniscript.org/MiniMicro/), a powerful neo-retro virtual computer.  (If you like what you can do in MiniBASIC, you will _love_ what you can do in Mini Micro's native language of [MiniScript](https://miniscript.org/)!)

## Overview

## Functions

The following built-in functions are available in MiniBASIC.

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
