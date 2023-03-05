10 REM Barnsley fern
20 REM https://en.wikipedia.org/wiki/Barnsley_fern
30 CLS : PRINT "Barnsley Fern"
40 X = 0 : Y = 0
50 R = RND(1) * 100
60 IF R < 1 THEN X = 0 : Y = 0.16 * Y : GOTO 100
70 IF R < 87 THEN T = 0.85 * X + 0.04 * Y : Y = -0.04 * X + 0.85 * Y + 1.6 : X = T : GOTO 100
80 IF R < 94 THEN T = 0.2 * X - 0.26 * Y : Y = 0.23 * X + 0.22 * Y + 1.6 : X = T : GOTO 100
90 T = -0.15 * X + 0.28 * Y : Y = 0.26 * X + 0.24 * Y + 0.44 : X = T
100 PLOT Y * 96, 320 + X * 96
110 ct = ct + 1
120 GOTO 50