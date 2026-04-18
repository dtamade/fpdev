program test_build_logger;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.logger, fpdev.utils, test_temp_paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function AllDigits(const S: string): Boolean;
var
  i: Integer;
begin
  Result := S <> '';
  if not Result then
    Exit;

  for i := 1 to Length(S) do
    if not (S[i] in ['0'..'9']) then
      Exit(False);
end;

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

procedure TestLogFileNameUsesZeroPaddedTimestampWithoutSpaces;
var
  Logger: TBuildLogger;
  LogDir, FileName, Stamp: string;
begin
  LogDir := '';
  Logger := nil;
  try
    LogDir := CreateUniqueTempDir('fpdev_build_logger_name');
    Logger := TBuildLogger.Create(LogDir);

    FileName := ExtractFileName(Logger.LogFileName);
    Check(Pos(' ', FileName) = 0,
      'BuildLogger log filename: contains no spaces');
    Check(Length(FileName) = 29,
      'BuildLogger log filename: fixed-width timestamp');
    Check(Pos('build_', FileName) = 1,
      'BuildLogger log filename: build_ prefix');
    Check(Copy(FileName, 15, 1) = '_',
      'BuildLogger log filename: date/time separator');
    Check(Copy(FileName, 22, 1) = '_',
      'BuildLogger log filename: time/ms separator');
    Check(Copy(FileName, 26, 4) = '.log',
      'BuildLogger log filename: .log suffix');

    Stamp := Copy(FileName, 7, 8) + Copy(FileName, 16, 6) + Copy(FileName, 23, 3);
    Check(AllDigits(Stamp),
      'BuildLogger log filename: timestamp sections are zero-padded digits');
  finally
    Logger.Free;
    CleanupTempDir(LogDir);
  end;
end;

begin
  WriteLn('=== Build Logger Tests ===');
  WriteLn;

  TestLogFileNameUsesZeroPaddedTimestampWithoutSpaces;
  TestLogEnvSnapshotUsesSameProcessPath;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
