# Welcome to MiniBASIC

MiniBASIC is a classic BASIC interpreter with these design goals:

1. Compatible with 1980s-era code listings, books, and magazines, including such beautiful and fun gems as the [classic Usborne BASIC Programming Books](https://usborne.com/us/books/computer-and-coding-books).

2. Friendly and easy to use, with features like input history (just press up-arrow!) and modern line-editing.

3. A powerful virtual retro computer, with full-color 960x640 resolution graphics and sound, that runs on any modern desktop machine.

That last design goal is achieved by running MiniBASIC on [Mini Micro](https:miniscript.org/MiniMicro/), a powerful neo-retro virtual computer.  (If you like what you can do in MiniBASIC, you will _love_ what you can do in Mini Micro's native language of [MiniScript](https://miniscript.org/)!)

## Overview

- There is always exactly one (possibly empty) program in memory at a time.
- Every line of a program must begin with a line number.
- Programs are created or edited by typing lines (starting with the line number) at the prompt.  Typing a line number alone deletes that line.
- The current program is listed with LIST, or to see only REM (remark) lines, use LISTREM.
- The current program may be saved with SAVE, loaded with LOAD, and cleared with NEW.
- Commands and identifiers are case-insensitive.  (E.g., xvelocity, XVelocity, and xVeLoCiTy are all the same variable.)
- Variable names ending in `$` are strings; any others are numeric.
- Scalar variables do not have to be declared; they are created upon assignment.  Array variables are declared with DIM or REDIM.
- Variable names of one or two letters exist automatically, even if not assigned to; numeric variables have a default value of 0, and string variables have a default value of empty string.  This includes arrays: one- or two-letter arrays, if not DIM or REDIM'd, exist as one-dimensional arrays with a dimension of 10.
- Variables more than two letters long do _not_ exist unless assigned to (for scalars) or declared with DIM/REDIM (for arrays).
- All variables are global.
- Arrays may be of any dimension, and are indexed with parentheses, e.g. N(4) or A$(42).  Valid array indexes are from 0 up to (and including) the size given in the DIM or REDIM statement.

## BASIC Functions

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
| PIXEL(_x_,_y_) | returns the color of the graphics layer at pixel _x_, _y_, as a number 0-15 corresponding to the COLOR palette; returns -1 if pixel color is not in the palette |
| PIXEL$(_x_,_y_) | returns the color of the graphics layer at pixel _x_, _y_, as an HTML color string, e.g. "#00CC55" |
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

## BASIC Commands

The following table lists all MiniBASIC commands.  A command is used as a statement on its own, either in immediate mode or as part of a program line; it may not be used as part of a larger expression.

| Command | Effect |
|---------|--------|
| BREAK | halts the program and reports the line number (for debugging purposes) |
| CLEAR | clears all variables from memory (but leaves program intact) |
| CLOSE _fileNum_ | closes a file previously opened with OPEN |
| CLS | clears the screen (both text and graphics); resets the text cursor to row 1, column 1; and resets the plot point to 0,0; HOME is a synonym |
| COLOR _x_ | if _x_ is a number, sets text and graphic color to palette color _x_ (0-15); if a _x_ is a string, sets text and graphic color to that HTML color (e.g. "#FF000088" for transparent red) |
| DATA _list_ | defines a comma-separated list of data for use with READ and RESTORE.  Data elements may be strings or numbers; strings must be enclosed in quotes if they contain spaces or punctuation |
| DEF FN _name_(_n_) = _expr_ | define a user-defined function; subsequent use of FN _name_(_n_) will be evaluated as expression _expr_, with the actual value substituted for _n_ |
| DIM _name_(_n_ \[,_m_ ...\]) | declares an array with valid indexes from 0 to _n_ inclusive, or a multidimensional array with additional dimensions _m_, etc.  Array will be numeric unless _name_ ends in `$`, in which case it is a string array.  Throws an error if _name_ is already in use as an array. |
| ELLIPSE \[_x1_, _y1_ TO\] _x2_, _y2_ | draws or fills an ellipse from _x1_, _y1_ (or the current plot position) to position _x2_, _y2_ in the current COLOR, and updates the plot position to _x2_, _y2_ |
| END | halts the current program and returns to the MiniBASIC prompt; STOP is a synonym |
| FILL \[ON|OFF\] | turns fill mode ON or OFF, controlling behavior of subsequent RECT, ELLIPSE, or POLY command |
| FOR _var_ = _n_ TO _m_ \[STEP _s_\] | begins a FOR loop running from _n_ to _m_, steps of _s_ (default 1) |
| GET _var_ | waits for a keypress to appear in the keyboard buffer, then returns it.  If _var_ is a string variable, returns the character pressed; if it is a numeric variable, returns the ASC value of the character pressed |
| GOSUB _lineNum_ | pushes the next statement onto the RETURN stack, then jumps to line _lineNum_ |
| GOTO _lineNum_ | jumps to line _lineNum_ |
| HOME | clears the screen (both text and graphics); resets the text cursor to row 1, column 1; and resets the plot point to 0,0; synonym for CLS |
| HTAB _n_ | moves the text cursor to column _n_ (1-68); see also VTAB |
| IF _expr_ THEN _result1_ \[ELSE _result2_] | if _expr_ is true (nonzero), then do _result1_, which may be either a line number to jump to, or one or more statements joined by `:`; otherwise jump to _result2_ if specified, or the next line.  If statements may be nested. |
| IMAGE _path$_, \[_x1_, _y1_ TO\] _x2_, _y2_ | draws an image found on disk at _path_.  If given only _x2_, _y2_, draws the image at its native size and centered on that point; if given four coordinates and/or TO, then stretches the image as needed to fit the rectangular area given; updates the plot position to _x2_, _y2_ in either case |
| INPUT \[prompt\, ] _var_ \[, _var2_ ...] | prints "?" if no _prompt_ specified, or if _prompt_ is followed by `;`; then waits for the user to enter a value to be stored in _var_ (or several values, separated by whitespace or commas, to be stored in _var_, _var2_, etc.).  Note that when reading into a string variable, input stops at a comma **unless** it is the last variable in the input list, in which case it reads all the way to the line break |
| \[LET\] _var_ = _expr_ | assigns the value of _expr_ to the variable _var_, which must be of the same type.  Note that `LET` is optional |
| LINE \[_x1_, _y1_ TO\] _x2_, _y2_ | draws a line from _x1_, _y1_ (or the current plot position) to position _x2_, _y2_ in the current COLOR, and updates the plot position to _x2_, _y2_ |
| NEXT \[_var_ \[, _var2_ ...\]\] | increments the nearest or specified FOR loop variable and jumps to the top of the loop, unless that loop is complete, in which case it advances to the next specified variable or the next statement |
| ON _expr_ GOTO _lineNum1_, _lineNum2_, ... | jumps to the line number corresponding to the (floored) value of _expr_, starting at 1 for _lineNum1_, etc.  If _expr_ evaluates to less than 1 or more than the number of line numbers given, control proceeds to the next statement |
| OPEN _fileNum_, \[_mode_,\] _path_ | opens a disk file for reading/writing.  _mode_ may be a number: 0 to read, or 1 to write; or it may be a standard [mode string](https://miniscript.org/wiki/File.open). _fileNum_ must be a nonzero number that's not already in use. See the File I/O section at bottom for more detail |
| PEN _size_ | changes the pen sized used with PLOT and LINE, as well as RECT, ELLIPSE, and POLY when FILL is OFF; value must be >= 0 |
| PLOT _x_, _y_ | plots pixel _x_ (0-959, measured from left side of screen) by _y_ (0-639, measured from bottom of screen) in the current COLOR, and sets the plot position used with subsequent drawing; may also take arrays to plot multiple points |
| POLY _x()_, _y()_ | draws or fills a polygon defined by arrays _x()_ and _y()_, updating the plot position to the last point in the arrays |
| PRINT \[_expr_, _expr_, ...] | prints zero or more expressions to the text display.  Expressions may be separated by `,`, `;`, or whitespace; a `,` will print a comma, while `;` or whitespace results in no additional space printed.  If the list of expressions does not end with `,`, `;`, or TAB(), then a line break is printed after the last expression.  PRINT may be abbreviated `?` |
| READ _var_ \[, _var2_, ...] | reads the next DATA term into the given variable. Any number of variables may be specified, separated by `,`, to be read in order.  Generates an error if there is insufficient DATA left to be read.  See also RESTORE |
| RECT \[_x1_, _y1_ TO\] _x2_, _y2_ | draws or fills a rectangle from _x1_, _y1_ (or the current plot position) to position _x2_, _y2_ in the current COLOR, and updates the plot position to _x2_, _y2_ |
| REDIM _name_(_n_ \[,_m_ ...\]) | declares an array with valid indexes from 0 to _n_ inclusive, or a multidimensional array with additional dimensions _m_, etc.  Acts just like DIM except that it does not throw an error if the array already exists; in such a case, the previous data is lost as the new array is always cleared |
| REM _text_ | creates a "remark" or comment in the program; any text between REM and the line break is ignored by MiniBASIC.  Note that if REM is the first statement on a line, then it will be included in the output of the LISTREM command |
| RESTORE \[_lineNum_] | resets the DATA pointer (i.e., the next datum read by the READ command) to the first DATA at or after the given _lineNum_, or if no line number is given, then the first DATA in the program |
| RETURN | pops the most recent program location off the RETURN stack (as set by GOSUB), and jumps to that location |
| SOUND [_freq_, _dur_, _vol_, _wave_] | synthesizes a sound with the given parameters: frequency, in Hz if > 0 or in negative MIDI note numbers if <= 0 (default 440 Hz); duration in seconds (default 0.5); volume 0-1 (default 1), and waveform (0=sine, 1=triangle, 2=sawtooth, 3=square, 4=noise, default 1).  Sound is played asynchronously.  Frequency and volume may be given an array (with no index, e.g. `F()`) instead of a scalar value; in this case, the sound interpolates over the values in the array linearly over the duration of the sound |
| STOP | halts the current program and returns to the MiniBASIC prompt; synonym for END |
| VTAB _n_ | moves the text cursor to row _n_ (1-25, with 1 at the top); see also HTAB |
| WAIT \[_n_] | pauses the program for _n_ seconds (default 1) before proceeding with the next statement

## Shell Commands

At the `>` interactive prompt, you may type and execute BASIC code immediately; or enter lines of code; or use one of the following shell commands, which are _only_ usable at the prompt (i.e. not in a program).

| Command | Effect |
|---------|--------|
| CAT\[ALOG\] | list contents of the current directory; synonym for DIR |
| CD _path_ | change the current directory to the given _path_.  Path separators are `/`; use `..` to go up a level |
| DIR | list contents of the current directory; CAT and CATALOG are synonyms |
| LIST \[_from_ - _to_\] | list the current program, or some range of line numbers; _from_ or _to_ may be omitted to list from the beginning or to the end of the program, respectively |
| LISTREM \[_from_ - _to_\] | similar to LIST, but shows only lines that begin with REM |
| LOAD _path_ | load the BASIC program at _path_ relative to the current directory (`.bas` extension may be omitted) |
| NEW | clear the current program and all variables |
| PWD | print working directory (i.e., path to the current directory |
| RENUMBER _from_ - _to_ TO _newStart_ \[STEP _step_\] | renumber lines in the range _from_ to _to_, so that they now start at _newStart_ and increment by _step_ |
| RUN | reset DATA pointers and all variables, then run the current program from the beginning |
| SAVE \[_path_\] | save the current program to _path_ relative to the current directory (`.bas` extension may be omitted); if _path_ is omitted, saves to the previous program path, if any |


## Special Topics

### Graphics

MiniBASIC features a high-resolution, 960x640 pixel full-color graphics display layer under the text layer.

Please see the program **demo/drawing** for examples of how to use the drawing commands (PLOT, LINE, RECT, ELLIPSE, POLY, and IMAGE).

### Sound

MiniBASIC supports a sophisticated synthesized sound system, including four different waveforms, and the ability to interpolate pitch and/or volume over the course of a sound.  All sounds are played asynchronously.

Please see the program **demo/sounds** for examples showing use of the SOUND command.

### File I/O

To write data to disk, follow these steps:

1. Open the file with a command like `OPEN n, 1, "path/to/file.txt"`.  _n_ here is any nonzero number that is not already in use for some other open file.  The second parameter, 1, is equivalent to "w" and means to clear the file (if it exists) and prepare it for writing.  You may also specify `"a"` to append to the end of a file, or some other mode listed [here](https://miniscript.org/wiki/File.open).
2. Write to the file with `PRINT# n, "some data"`.  This version of the `PRINT` command uses all the same syntax and rules as normal `PRINT`, but its output is directed to file _n_ instead of to the screen.
3. Close the file with `CLOSE n`.

To read data from disk, follow these steps:

1. Open the file with a command like `OPEN n, 0, "path/to/file.txt"`.  Again, _n_ is any nonzero number that is not already in use for some other open file.  The second parameter, 0, means to open the file in "r" (read) mode; you may also use other modes listed [here](https://miniscript.org/wiki/File.open).
2. Read from the file with a command like `INPUT# n, A$`.  This `INPUT#` command is just like the standard `INPUT` command, except that any prompt string is ignored, and input is read from the file rather than from the console.  Note that both end-of-file and a blank line will store "" in the given string variable.  OR,
3. Read a single character from the file with a command like `GET# n, A$`.  If we are at end-of-file, then GET# stores empty string into the given string variable.  If given a numeric variable, then at the end of file the value stored is -1.
4. Close the file with `CLOSE n`.
