10 CLS: PRINT "MiniBASIC test program.": PRINT
20 PRINT "This program automatically tests as many MiniBASIC commands as"
30 PRINT "possible.  Any BREAK below represents an unexpected failure."
40 PRINT: PRINT "Press any key to begin."
50 GET A$: PRINT
100 REM Numeric Functions
110 PRINT "Testing numeric functions..."
120 IF ABS(-42) <> 42 THEN BREAK
130 IF ABS(ATN(1)-0.785398) > 0.0001 THEN BREAK
140 IF COS(PI) <> -1 OR COS(0) <> 1 THEN BREAK
150 IF EXP(0) <> 1 OR ABS(EXP(1)-2.718282) > 0.0001 THEN BREAK
160 IF FIX(4.8) <> 4 OR FIX(-4.8) <> -4 THEN BREAK
170 IF INT(4.8) <> 4 OR INT(-4.8) <> -5 THEN BREAK
180 IF INSTR("abcde", "cd") <> 3 THEN BREAK
182 IF INSTR("abcde", "cq") <> 0 THEN BREAK
184 IF INSTR(4, "abcdecde", "cd") <> 6 THEN BREAK
190 IF LEN("abcde") <> 5 THEN BREAK
200 IF POS(0) <> 1 THEN BREAK
202 IF POS(1) <> 9 THEN BREAK
210 R = RND(0): IF R < 0 OR R > 1 THEN BREAK
212 X = RND(-42): 
213 IF ABS(RND(0)-0.125518) > 0.0001 THEN BREAK
214 IF ABS(RND(0)-0.522764) > 0.0001 THEN BREAK
215 IF ABS(RND(0)-0.168434) > 0.0001 THEN BREAK
220 IF SGN(-42) <> -1 OR SGN(0) <> 0 OR SGN(42) <> 1 THEN BREAK
230 IF ABS(SIN(PI)) > 0.0001 OR SIN(PI/2) <> 1 THEN BREAK
240 IF SQR(9) <> 3 OR SQR(25) <> 5 THEN BREAK
250 IF ABS(TAN(PI/4)-1) > 0.0001 OR ABS(TAN(PI)) > 0.0001 THEN BREAK
260 IF TIME(1) < 0 OR TIME(1) > TIME(0) THEN BREAK
999 PRINT "Numeric functions OK."
1000 REM String Functions
2000 REM Graphics Functions
3000 REM File I/O
9990 PRINT: PRINT "All tests complete."

