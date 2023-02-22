10 CLS 
20 FOR C = 0 TO 15
30 COLOR C
40 PRINT TAB(5, 5 + C); "COLOR " + C, ""
50 X = 3 * 14 - 4 : Y =(26 -(5 + C)) * 24 + 8
60 FILL ON : RECT X, Y TO X + 20, Y + 20
70 COLOR 15 : FILL OFF : RECT X, Y TO X + 20, Y + 20
80 C$ = PIXEL$(X + 10, Y + 10)
100 READ NAME$
110 PRINT TAB(16, 5 + C); NAME$; TAB(30); C$
120 NEXT 
130 PRINT : PRINT 
140 COLOR 5
1000 DATA Black, White, "Dark Red", Cyan, Violet, Green, Blue, Yellow
1010 DATA Orange, Brown, "Light Red", "Dark Gray", "Med Gray"
1020 DATA "Light Green", "Light Blue", "Light Gray"