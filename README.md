# minibasic
[BASIC](https://en.wikipedia.org/wiki/BASIC) interpreter for [Mini Micro](https:miniscript.org/MiniMicro/)


This is a little project to create an interpreter for the BASIC programming language for Mini Micro.  The interpreter itself is written in [MiniScript](https://miniscript.org).

**NOTE:** This project requires MiniScript v1.6, coming in Mini Micro v1.2 (not yet officially released).

## Features Implemented ##

- immediate-mode commands like `PRINT 6*7` (or equivalent shorthand, `?6*7`)
- program editing by entering a line number with code to insert/replace that line, or a line number alone to delete that line
- expression parsing including all standard operators
- support for multiple statements on one line, separated by `:`
- program management:
  - `NEW`
  - `LIST` (note: not yet with range of line numbers)
  - `LISTREM` (lists only lines that start with `REM`)
  - `RUN`
  - `CAT` (lists files on disk)
  - `LOAD` _program name_ (e.g. `LOAD dice`)
- standard BASIC commands:
  - `PRINT` (or `?` for short), with `,` and `;`
  - `INPUT` (without prompt)
  - `GOTO`
  - `IF` _condition_ `THEN` (with optional `ELSE`, nestable)
  - `LET` (optional; `X = 42` also works without `LET`)
  - `FOR` _var_ `=` _start_ `TO` _end_ (with optional `STEP`)
  - `NEXT` (note: not yet supporting a variable name)
  - `END`
  - `REM`
- standard(ish) BASIC functions:
  - `INT`, `STR`, `VAL`
  - `ABS`, `SGN`, etc.
  - `RND`
  - `TAB` (sets horizontal cursor position, then returns "")
- nonstandard BASIC commands:
  - `CLEAR` (resets all variables)
  - `HOME` (clears the screen and resets the cursor)
  - `COLOR` _n_ (pick a color 0-15; or pass a color hex string)
  - `PLOT` _x_, _y_, (plot a single pixel, and set the plot position)
  - `LINE` _x_, _y_, (draw a line from the last plot/line position)

## Features Still To Come ##

- program management:
  - `SAVE`
  - `RENAME`
  - `RENUMBER`
- support for arrays
- distinction between string and numeric variables
- standard BASIC commands:
  - `DATA` and `READ`
  - `GOSUB` and `RETURN`

## Sample Programs

Include in the _programs_ subdirectory are about a hundred classic (old) BASIC demos and games from _Creative Computing_ magazine (via [BASIC Computer Games](https://en.wikipedia.org/wiki/BASIC_Computer_Games).  Most of these don't work yet, though a few of them (like "chemist") do.


## References

Detailed references on various old BASIC dialects can be hard to find.  But here are some:

- [Applesoft BASIC](https://www.calormen.com/jsbasic/reference.html)
- [Microsoft BASIC-80](https://usermanual.wiki/Document/BASIC8028MBASIC29ReferenceManual.204768585/view)
- [Commodore-BASIC V2.0](https://www.c64-wiki.com/wiki/C64-Commands)
- [Classic Usborne BASIC Programming Books](https://usborne.com/us/books/computer-and-coding-books)
