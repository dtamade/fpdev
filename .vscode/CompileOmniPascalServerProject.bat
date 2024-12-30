@echo off

SET LAZBUILD="D:\devtools\lazarus\nextgen\lazarus\lazbuild.exe"
SET PROJECT="D:\projects\Pascal\lazarus\My\projects\fpdev\src\fpdev.lpi"

REM Modify .lpr file in order to avoid nothing-to-do-bug (http://lists.lazarus.freepascal.org/pipermail/lazarus/2016-February/097554.html)
echo. >> "D:\projects\Pascal\lazarus\My\projects\fpdev\src\fpdev.lpr"

%LAZBUILD% %PROJECT%

if %ERRORLEVEL% NEQ 0 GOTO END

echo. 

if "%1"=="" goto END

if /i %1%==test (
  "D:\projects\Pascal\lazarus\My\projects\fpdev\bin\fpdev.exe" 
)
:END
