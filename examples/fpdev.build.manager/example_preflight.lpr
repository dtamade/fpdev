program example_preflight;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.build.manager;

procedure Run;
var
  LBM: TBuildManager;
  LRoot, LVer: string;
begin
  LRoot := 'sources' + PathDelim + 'fpc';
  LVer := 'main';
  LBM := TBuildManager.Create(LRoot, 2, True);
  try
    LBM.SetLogVerbosity(1);
    LBM.SetSandboxRoot('plays' + PathDelim + '.sandbox');
    if not LBM.Preflight(LVer) then
    begin
      WriteLn('Preflight FAIL. See log: ', LBM.LogFileName);
      Halt(2);
    end;
    WriteLn('Preflight OK. Log: ', LBM.LogFileName);
  finally
    LBM.Free;
  end;
end;

begin
  Run;
end.

