program example_strict_validate;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.manager;

procedure Run;
var
  LBM: TBuildManager;
  LRoot, LVer, LCfg: string;
begin
  LRoot := 'sources' + PathDelim + 'fpc';
  LVer := 'main';
  LCfg := 'plays' + PathDelim + 'fpdev.build.manager.demo' + PathDelim + 'build-manager.strict.ini';
  LBM := TBuildManager.Create(LRoot, 2, True);
  try
    LBM.SetSandboxRoot('plays' + PathDelim + '.sandbox');
    LBM.SetAllowInstall(True);
    LBM.SetLogVerbosity(1);
    LBM.SetStrictResults(True);
    if FileExists(LCfg) then LBM.SetStrictConfigPath(LCfg);
    // 仅校验，不做真实构建：
    LBM.SetDryRun(True);
    if LBM.TestResults(LVer) then
      WriteLn('Strict TestResults OK')
    else
      WriteLn('Strict TestResults FAIL');
    WriteLn('Log: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;
end;

begin
  Run;
end.

