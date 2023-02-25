10 CLS 
20 CX = 480 : CY = 320 : REM Center X,Y
30 R = 200 : REM Radius
40 PRINT "SPIROGRAPH"
50 INPUT "Enter angle step (e.g. 110): ", dAng
60 COLOR 1
70 ang = 0 : PLOT CX + R, CY
80 REM Top of loop
90 radians = ang * PI / 180
100 LINE TO CX + R * COS(radians), CY + R * SIN(radians)
110 IF ang > 0 AND abs(ang MOD 360) < 0.1 THEN 140
120 ang = ang + dAng
130 GOTO 80
140 REM done!
150 VTAB 24
160 COLOR 5 : PRINT "Enter ";
170 COLOR 4 : PRINT "RUN";
180 COLOR 5 : PRINT " to try again!"