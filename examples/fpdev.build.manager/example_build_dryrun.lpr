program example_build_dryrun;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.manager;

procedure Run;
var
  LBM: TBuildManager;
  LRoot, LVer: string;
  LReal: Boolean;
begin
  LRoot := 'sources' + PathDelim + 'fpc';
  LVer := 'main';
  LReal := GetEnvironmentVariable('REAL') = '1';
  LBM := TBuildManager.Create(LRoot, 4, True);
  try
    LBM.SetSandboxRoot('plays' + PathDelim + '.sandbox');
    LBM.SetLogVerbosity(1);
    LBM.SetDryRun(not LReal);
    if LBM.BuildCompiler(LVer) then WriteLn('BuildCompiler OK') else WriteLn('BuildCompiler FAIL');
    if LBM.BuildRTL(LVer) then WriteLn('BuildRTL OK') else WriteLn('BuildRTL FAIL');
    WriteLn('Mode: ', BoolToStr(LReal, True), ' (True=REAL, False=DRY)');
    WriteLn('Log: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;
end;

begin
  Run;
end.

