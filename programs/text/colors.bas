10 CLS
20 FOR C = 0 TO 15
30 COLOR C
40 PRINT TAB(5, 5+C); "COLOR " + C, ""
50 COLOR 15: READ NAME$
60 PRINT TAB(16, 5+C); NAME$
70 NEXT
1000 DATA Black, White, "Dark Red", Cyan, Violet, Green, Blue, Yellow
1010 DATA Orange, Brown, "Light Red", "Dark Gray", "Med Gray"
1020 DATA "Light Green", "Light Blue", "Light Gray"
