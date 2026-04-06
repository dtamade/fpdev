program test_build_logger;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.logger, fpdev.utils, test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

procedure TestLogEnvSnapshotUsesSameProcessPath;
var
  Logger: TBuildLogger;
  ProbeDir, LogDir, SavedPath, EffectivePath, LogContent: string;
  LogLines: TStringList;
begin
  ProbeDir := '';
  LogDir := '';
  SavedPath := get_env('PATH');
  Logger := nil;
  LogLines := nil;
  try
    ProbeDir := CreateUniqueTempDir('fpdev_build_logger_probe');
    LogDir := CreateUniqueTempDir('fpdev_build_logger_logs');

    if SavedPath <> '' then
      EffectivePath := ProbeDir + PathSeparator + SavedPath
    else
      EffectivePath := ProbeDir;

    Check(set_env('PATH', EffectivePath),
      'BuildLogger PATH override: PATH override applied');

    Logger := TBuildLogger.Create(LogDir);
    Logger.Verbosity := 1;
    Logger.LogEnvSnapshot;

    Check(FileExists(Logger.LogFileName),
      'BuildLogger PATH override: log file created');

    LogLines := TStringList.Create;
    LogLines.LoadFromFile(Logger.LogFileName);
    LogContent := LogLines.Text;

    Check(Pos('env: PATH[0]=' + ProbeDir, LogContent) > 0,
      'BuildLogger PATH override: PATH[0] uses same-process override');
  finally
    RestoreEnv('PATH', SavedPath);
    LogLines.Free;
    Logger.Free;
    CleanupTempDir(ProbeDir);
    CleanupTempDir(LogDir);
  end;
end;

begin
  WriteLn('=== Build Logger Tests ===');
  WriteLn;

  TestLogEnvSnapshotUsesSameProcessPath;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
