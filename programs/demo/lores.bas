1 REM Some subroutines to emulate Apple ][ low-res graphics.
2 REM Includes color conversion (subroutine 6080), as well as
3 REM equivalents for PLOT (6000), HLIN (6020), and VLIN (6040).
4 REM Handy if converting old Applesoft programs that use GR.
10 CLS : VTAB 23
15 _color = 7 : GOSUB 6080 : REM COLOR=7
20 _x = 0 : _y = 0 : GOSUB 6000 : REM PLOT 0,0
30 _x = 39 : GOSUB 6000 : REM PLOT 39,0
40 _y = 39 : GOSUB 6000 : REM PLOT 39,39
50 _x = 0 : GOSUB 6000 : REM PLOT 0,39
60 _x = 0 : _x2 = 39 : _y = 0 : GOSUB 6020 : REM HLIN 0,39 AT 0
70 _x = 0 : _y = 0 : _y2 = 39 : GOSUB 6040 : REM VLIN 0,39 AT 0
999 COLOR 5 : END 
6000 REM PLOT x,y
6010 _x2 = _x : _y2 = _y : GOTO 6100
6020 REM HLIN _x,_x2 AT _y
6030 _y2 = _y : GOTO 6100
6040 REM VLIN _y,_y2 AT _x
6050 _x2 = _x : GOTO 6100
6080 REM apply Apple ][ color _color
6085 _pal$ = "000000 901740 402ca5 d043e5 006940 808080 2f95e5 bfabff 405400 d06a1a 808080 ff96bf 2fbc1a bfd35a 6fe8bf ffffff"
6090 COLOR "#" + MID$(_pal$, _color * 7 + 1, 6) : RETURN 
6100 REM Fill rectangle from _x,_y to _x2,_y2
6105 FILL ON 
6110 RECT _x * 24, 627 - _y * 13 TO _x2 * 24 + 24, 640 - _y2 * 13
6120 RETURN 