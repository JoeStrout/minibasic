10 REM Sounds Demo for MiniBASIC
20 REM
30 REM Syntax for the SOUND command:
40 REM    SOUND freq, duration, volume, waveform
50 REM
60 REM Frequency may be in Hz, like 440, or if <= 0, then
70 REM it is the negative of a MIDI note number (-60 for
80 REM middle C, -61 for C#, -62 for middle D, etc.).
90 REM
100 REM Load Data
110 DIM name$(20), freq(20), dur(20), vol(20), wave(20)
120 i = 0
130 READ name$(i): IF name$(i) = "--end--" THEN maxSimple = i-1: GOTO 160
140 READ freq(i), dur(i), vol(i), wave(i)
150 i = i + 1: GOTO 130
160 DIM special$(20)
170 READ name$(i): IF name$(i) = "--end--" THEN maxi = i-1: GOTO 200
180 READ special$(i)
190 i = i + 1: GOTO 170

200 REM Draw Menu
210 CLS: PRINT TAB(29);"SOUND Demo": PRINT
215 PRINT "Simple Sounds (Freq, Duration, Volume, Waveform):": PRINT
220 for i = 0 TO maxi
230 PRINT i; ". "; name$(i); ":"; TAB(15);
240 IF i > maxSimple THEN 270
250 PRINT "SOUND "; freq(i); ", "; dur(i); ", "; vol(i); ", "; wave(i)
255 IF i < maxSimple THEN 280
260 PRINT: PRINT "Advanced Sounds (using an array for Freq or Volume):": PRINT
265 GOTO 280
270 PRINT special$(i)
280 NEXT
290 PRINT: PRINT "Press key (0-9) to hear the sound, or ESC to exit: ";
300 cursorH = POS(0): cursorV = POS(1)

400 REM Handle User Input
410 HTAB cursorH: VTAB cursorV: GET k: IF k = 27 THEN PRINT: END
415 PRINT CHR$(k)
420 i = k - ASC("0"): IF i < 0 OR i > maxi THEN 300
430 IF i > maxSimple THEN 500
440 SOUND freq(i), dur(i), vol(i), wave(i)
450 GOTO 400
500 ON i - maxSimple GOTO 510, 520, 530: GOTO 400
510 REDIM F(1)
511 F(0)=800: F(1)=100: SOUND F(), 0.5, 1, 3
515 GOTO 400
520 REDIM F(2)
521 F(0)=-12: F(1)=-88: F(2)=-48: SOUND F(), 0.5, 1, 2
525 GOTO 400
530 REDIM V(1)
540 V(0)=1: V(1)=0: SOUND 0.5, 2, V(), 4
550 GOTO 400

1000 REM Example Sound Data
1010 REM Each line is: Name, Freq, Duration, Vol, Waveform
1020 DATA Beep, 880, 0.2, 1, 0
1030 DATA Boop, 440, 0.2, 1, 1
1040 DATA Dooop, 220, 1, 0.5, 3
1050 DATA Scoot, 1, 0.1, 1, 4
1060 DATA Engine, 0.5, 3, 1, 4
1070 DATA "Middle C", -60, 1, 0.5, 1
1080 DATA "Middle G", -67, 1, 0.5, 1
1090 DATA "--end--"
1100 DATA Pew, "F(0)=800: F(1)=100: SOUND F(), 0.5, 1, 3"
1110 DATA WooOoo, "F(0)=-12: F(1)=-88: F(2)=-48: SOUND F(), 0.5, 1, 2"
1120 DATA Booom, "V(0)=1: V(1)=0: SOUND 0.5, 2, V(), 4"
1190 DATA "--end--"
