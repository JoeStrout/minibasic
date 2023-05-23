10 REM Test demo of file I/O
20 PRINT "Writing to test.txt ..." : WAIT 
30 OPEN 42, 1, "test.txt"
40 PRINT# 42, "This is a test."
50 PRINT# 42, "This is also ";
60 PRINT# 42, "a test."
70 CLOSE 42
80 REM 
100 PRINT "Reading from test.txt..." : WAIT 
110 OPEN 42, 0, "test.txt"
115 FOR I = 1 TO 5 : GET# 42, C$ : PRINT C$; : WAIT : NEXT 
120 INPUT# 42, LINE$
130 PRINT LINE$
140 IF NOT EOF(42) THEN 120
150 CLOSE 42
190 PRINT "...And that's it!"