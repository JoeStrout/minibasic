# MiniBASIC
[BASIC](https://en.wikipedia.org/wiki/BASIC) interpreter for [Mini Micro](https:miniscript.org/MiniMicro/)


This is a little project to create an interpreter for the BASIC programming language for Mini Micro.  The interpreter itself is written in [MiniScript](https://miniscript.org).

**NOTE:** This project requires MiniScript v1.6, coming in Mini Micro v1.2 (not yet officially released).

## Features Implemented ##

- immediate-mode commands like `PRINT 6*7` (or equivalent shorthand, `?6*7`)
- program editing by entering a line number with code to insert/replace that line, or a line number alone to delete that line
- expression parsing including all standard operators
- support for multiple statements on one line, separated by `:`
- one-dimensional arrays
- weird PRINT syntax that lets you just list expressions with no delimiters between them
- support for multidimensional arrays
- program management:
  - `NEW`
  - `LIST` (including range of line numbers)
  - `LISTREM` (lists only lines that start with `REM`)
  - `RUN`
  - `CAT` (lists files on disk)
  - `LOAD` _program name_ (e.g. `LOAD dice`)
  - `SAVE` _program name_ (program name/path may be omitted if previously saved/loaded)
- standard BASIC commands:
  - `PRINT` (or `?` for short), with `,` and `;`
  - `INPUT` (without prompt)
  - `GOTO`
  - `GOSUB` and `RETURN`
  - `IF` _condition_ `THEN` (with optional `ELSE`, nestable)
  - `LET` (optional; `X = 42` also works without `LET`)
  - `FOR` _var_ `=` _start_ `TO` _end_ (with optional `STEP`)
  - `NEXT` (note: not yet supporting a variable name)
  - `END`
  - `REM`
  - `CLEAR` (resets all variables)
  - `DATA`, `READ`, and `RESTORE'
- standard(ish) BASIC functions:
  - `INT`, `STR`, `VAL`
  - `ABS`, `SGN`, etc.
  - `RND`
  - `TAB` (sets cursor position, then returns "")
- nonstandard BASIC commands:
  - `HOME` or `CLS` (clears the screen and resets the cursor)
  - `COLOR` _n_ (pick a color 0-15; or pass a color hex string)
  - `PLOT` _x_, _y_, (plot a single pixel, and set the plot position)
  - `LINE` _x_, _y_, (draw a line from the last plot/line position)
  - `UPPER$`, `LOWER$` (or similar)
  - `DEF FN`
  - `SOUND` command, and more drawing commands
  
## Features Still To Come ##

- program management:
  - `RENAME`
  - `RENUMBER`
- full typechecking (between string and numeric variables)
- make all identifiers case-insensitive
- maybe only make undefined variables default to 0 (or a 10-element array) for identifiers 1 or 2 characters long

## Sample Programs

Included in the _programs/CC_ subdirectory are about a hundred classic (old) BASIC demos and games from _Creative Computing_ magazine (via [BASIC Computer Games](https://en.wikipedia.org/wiki/BASIC_Computer_Games)).  Most of these should work now.

I'm also starting a second collection of programs written specifically for MiniBASIC, or adapted from other sources.  The programs/text subdirectory contains the first of these.  It includes some AppleSoft programs that have not yet been updated to standard MiniBASIC.

## Try It Yourself!

To run this code requires at least a preview release of Mini Micro 1.2 (because it uses some of the latest features of the MiniScript language).  So:

1. grab a preview build of Mini Micro 1.2 for [Mac](https://miniscript.org/MiniMicro/preview/minimicro-mac.zip), [Windows](https://miniscript.org/MiniMicro/preview/minimicro-win.zip), or [Linux](https://miniscript.org/MiniMicro/preview/minimicro-linux.tar.gz)
2. unpack this, and run (you might need to right-click an "open" the first time, as the app is not yet code-signed)
3. download or clone this repo
4. in Mini Micro, click on the top disk slot below the screen, and choose "Mount Folder..."
5. select the folder containing this README.md and basic.ms
6. type `reboot` at the Mini Micro prompt (or quit and relaunch)

That should do it!  Now whenever Mini Micro starts up, it should go straight into MiniBASIC, which you can recognize by the `>` prompt.

If something goes wrong, MiniBASIC may crash, and drop you out into the MiniScript (recognizable by the `]` prompt).  In that case, just type `basic` to restart MiniBASIC (or, `reboot` if all else fails).

## References

Detailed references on various old BASIC dialects can be hard to find.  But here are some:

- [Applesoft BASIC](https://www.calormen.com/jsbasic/reference.html)
- [Applesoft BASIC, in more detail](https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Software/Languages/Applesoft%20BASIC/Manuals/Applesoft%20II%20BASIC%20Programming%20Reference%20Manual.pdf)
- [Microsoft BASIC-80](https://usermanual.wiki/Document/BASIC8028MBASIC29ReferenceManual.204768585/view)
- [Commodore-BASIC V2.0](https://www.c64-wiki.com/wiki/C64-Commands)
- [Classic Usborne BASIC Programming Books](https://usborne.com/us/books/computer-and-coding-books)

For discussion, consider:

- [BASIC4ALL forum](http://basic4all.epizy.com/index.php)
- [MiniScript forums](https://forums.miniscript.org/)

