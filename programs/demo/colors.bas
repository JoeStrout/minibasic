10 CLS 
20 FOR C = 0 TO 15
30 COLOR C
40 X = 3 * 14 - 4 : Y =(26 -(5 + C)) * 24 + 8
50 FILL ON : RECT X, Y TO X + 20, Y + 20
60 COLOR 15 : FILL OFF : RECT X, Y TO X + 20, Y + 20
70 IF C = 0 THEN COLOR 15 ELSE COLOR C
80 PRINT TAB(5, 5 + C); "COLOR " + C, ""
90 C$ = PIXEL$(X + 10, Y + 10)
100 READ NAME$
110 PRINT TAB(16, 5 + C); NAME$; TAB(30); C$
120 NEXT 
130 PRINT : PRINT 
140 COLOR 5
1000 DATA Black, White, "Dark Red", Cyan
1010 DATA Violet, Green, Blue, Yellow, Orange
1020 DATA Brown, "Light Red", "Dark Gray", "Med Gray"
1030 DATA "Light Green", "Light Blue", "Light Gray"