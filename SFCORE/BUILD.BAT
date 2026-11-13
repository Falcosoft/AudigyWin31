@echo off
rem Run from SFCORE with the Open Watcom environment set.
set SFOLDINC=%INCLUDE%
set INCLUDE=%WATCOM%\h;%WATCOM%\h\win
set SFOPTS=-bt=windows -bd -3 -zu -s -zl -zq -we -ot
rem Both modules use far code so they share the same runtime helpers.
wcc %SFOPTS% -mm -fo=SFIRQ.OBJ SFIRQ.C
if errorlevel 1 goto fail
wcc %SFOPTS% -mh -fpi87 -fp3 -nt=SFLOAD_TEXT -fo=SFLOAD.OBJ SFLOAD.C
if errorlevel 1 goto fail
wlink @SFCORE.LNK
if errorlevel 1 goto fail
echo Built SFCORE.DLL.
goto done
:fail
echo SFCORE build failed.
:done
set SFOPTS=
set INCLUDE=%SFOLDINC%
set SFOLDINC=
