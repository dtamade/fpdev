@echo off
setlocal EnableDelayedExpansion
set LAZBUILD=lazbuild
set THIS=%~dp0
pushd "%THIS%"
for %%F in (*.lpr) do (
  set NAME=%%~nF
  call :GEN "%%F" "%%~nF.lpi" "bin\%%~nF" "lib\$(TargetCPU)-$(TargetOS)"
  if errorlevel 1 exit /b !errorlevel!
  %LAZBUILD% -B "%%~nF.lpi"
  if errorlevel 1 exit /b !errorlevel!
)
popd
exit /b 0

:GEN
echo ^<?xml version="1.0" encoding="UTF-8"?^> > %2
echo ^<CONFIG^> >> %2
echo   ^<ProjectOptions^> >> %2
echo     ^<Version Value="12"/^> >> %2
echo     ^<PathDelim Value="\"/^> >> %2
echo     ^<General^> >> %2
echo       ^<Title Value="%~n1"/^> >> %2
echo       ^<SessionStorage Value="InProjectDir"/^> >> %2
echo       ^<ResourceType Value="res"/^> >> %2
echo     ^</General^> >> %2
echo     ^<BuildModes^> >> %2
echo       ^<Item Name="Default" Default="True"^> >> %2
echo         ^<CompilerOptions^> >> %2
echo           ^<Version Value="11"/^> >> %2
echo           ^<PathDelim Value="\"/^> >> %2
echo           ^<Target^> >> %2
echo             ^<Filename Value="%3"/^> >> %2
echo           ^</Target^> >> %2
echo           ^<SearchPaths^> >> %2
echo             ^<OtherUnitFiles Value="..\\..\\src"/^> >> %2
echo             ^<IncludeFiles Value="$(ProjOutDir)"/^> >> %2
echo             ^<UnitOutputDirectory Value="%4"/^> >> %2
echo           ^</SearchPaths^> >> %2
echo         ^</CompilerOptions^> >> %2
echo       ^</Item^> >> %2
echo     ^</BuildModes^> >> %2
echo     ^<Units^> >> %2
echo       ^<Unit^> >> %2
echo         ^<Filename Value="%~nx1"/^> >> %2
echo         ^<IsPartOfProject Value="True"/^> >> %2
echo       ^</Unit^> >> %2
echo     ^</Units^> >> %2
echo   ^</ProjectOptions^> >> %2
echo   ^<CompilerOptions^> >> %2
echo     ^<Version Value="11"/^> >> %2
echo     ^<PathDelim Value="\"/^> >> %2
echo     ^<Target^> >> %2
echo       ^<Filename Value="%3"/^> >> %2
echo     ^</Target^> >> %2
echo     ^<SearchPaths^> >> %2
echo       ^<OtherUnitFiles Value="..\\..\\src"/^> >> %2
echo       ^<IncludeFiles Value="$(ProjOutDir)"/^> >> %2
echo       ^<UnitOutputDirectory Value="%4"/^> >> %2
echo     ^</SearchPaths^> >> %2
echo   ^</CompilerOptions^> >> %2
echo ^</CONFIG^> >> %2
