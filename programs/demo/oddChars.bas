10 REM Demonstration of the odd characters available
20 REM in the Mini Micro (and so MiniBASIC) text font.
30 CLS 
40 COL = 13
50 ROW = 3
60 READ name$, code : code$ = STR$(code)
70 IF name$ = "" AND code = 0 THEN 900
80 COLOR 5 : PRINT TAB(COL - LEN(code$), ROW); code$
90 COLOR 13 : PRINT TAB(COL + 1, ROW); CHR$(code),
100 COLOR 5 : PRINT name$
110 ROW = ROW + 1
120 IF ROW > 21 THEN COL = COL + 30 : GOTO 50
130 GOTO 60
900 VTAB 24 : END 
1000 DATA left, 17, right, 18, up, 19, down, 20
1010 DATA unprintable, 21
1020 DATA buttonCapLeft, 57856, buttonCapRight, 57857
1030 DATA figureStanding, 57872, figureWaitingToeDown, 57873
1040 DATA figureWaitingToeUp, 57874, figureAkimbo, 57875
1050 DATA tree, 57888
1060 DATA mu,181, pi, 960, tau, 964
1070 DATA invertedBang, 161, copyright, 169, registered, 174
1080 DATA lineEndSymbol, 172, degrees, 176, invertedQuestion, 191
1090 DATA multSign, 215, divSign, 247
1100 DATA bullet, 8226, ellipsis, 8230
1110 DATA emptyBox, 9744, checkedBox, 9745, boxWithX, 9746
1120 DATA spade, 9824, club, 9827, heart, 9829, diamond, 9830
1130 DATA dieFace1, 9856, dieFace2, 9857, dieFace3, 9858
1140 DATA dieFace4, 9859, dieFace5, 9860, dieFace6, 9861
1150 DATA "", 0