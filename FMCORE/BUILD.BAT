@echo off
set COREOPTS=-bt=windows -mm -bd -3 -fpi87 -fp3 -zu -s -zl -zq -we
wcc %COREOPTS% -os -fo=OPLCORE.OBJ OPLCORE.C
if errorlevel 1 goto fail
wpp %COREOPTS% -os -fo=FMCORE.OBJ FMCORE.CPP
if errorlevel 1 goto fail
wpp %COREOPTS% -os -fo=OPLSYN.OBJ OPLSYN.CPP
if errorlevel 1 goto fail
wpp %COREOPTS% -ox -fo=DBADAPT.OBJ DBADAPT.CPP
if errorlevel 1 goto fail
wpp %COREOPTS% -ox -fo=DBOPL.OBJ DBOPL.CPP
if errorlevel 1 goto fail
wlink @CORE.LNK
if errorlevel 1 goto fail
goto done
:fail
echo OPLCORE build failed.
:done
set COREOPTS=
