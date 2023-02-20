5 CLS
10 FOR m = 5 TO 9
20 FOR n = m - 4 TO 22 - m
30 PRINT TAB(27 + m, 3 + n); "*"
40 PRINT TAB(27 + n, 3 + m); "*"
50 PRINT TAB(27 + 18 - m, 3 + n); "*"
60 PRINT TAB(27 + n, 3 + 18 - m); "*"
70 NEXT n
80 NEXT m
90 VTAB 24 : END
