program example_install_sandbox;
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
  LBM := TBuildManager.Create(LRoot, 2, True);
  try
    LBM.SetSandboxRoot('plays' + PathDelim + '.sandbox');
    LBM.SetAllowInstall(True);
    LBM.SetLogVerbosity(1);
    LBM.SetDryRun(not LReal);
    if LBM.Install(LVer) then WriteLn('Install OK') else WriteLn('Install FAIL');
    WriteLn('Mode: ', BoolToStr(LReal, True), ' (True=REAL, False=DRY)');
    WriteLn('Log: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;
end;

begin
  Run;
end.

