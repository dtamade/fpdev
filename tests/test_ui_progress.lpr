program test_ui_progress;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.ui.progress,
  fpdev.utils;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

function CaptureProgressOutput: string;
var
  SavedOutput: Text;
  TempPath: string;
  Progress: IProgressBar;
begin
  TempPath := GetTempFileName(GetTempDir(False), 'fpd');
  SavedOutput := Output;
  Assign(Output, TempPath);
  Rewrite(Output);
  try
    Progress := CreateProgressBar;
    Progress.Start('Testing progress', 10);
    Progress.Finish;
    Flush(Output);
  finally
    Close(Output);
    Output := SavedOutput;
  end;

  Result := ReadAllTextIfExists(TempPath);
  DeleteFile(TempPath);
end;

procedure TestInteractiveModeWritesOutput;
var
  SavedNonInteractive: string;
  SavedCI: string;
  Captured: string;
begin
  SavedNonInteractive := get_env('FPDEV_NONINTERACTIVE');
  SavedCI := get_env('CI');
  try
    unset_env('FPDEV_NONINTERACTIVE');
    unset_env('CI');

    Captured := CaptureProgressOutput;
    AssertTrue(Trim(Captured) <> '',
      'CreateProgressBar defaults to console output when envs are unset');
  finally
    RestoreEnv('FPDEV_NONINTERACTIVE', SavedNonInteractive);
    RestoreEnv('CI', SavedCI);
  end;
end;

procedure TestNonInteractiveEnvVisibleInSameProcess;
var
  SavedNonInteractive: string;
  SavedCI: string;
  Captured: string;
begin
  SavedNonInteractive := get_env('FPDEV_NONINTERACTIVE');
  SavedCI := get_env('CI');
  try
    unset_env('CI');
    AssertTrue(set_env('FPDEV_NONINTERACTIVE', '1'),
      'set FPDEV_NONINTERACTIVE for same-process progress test');

    Captured := CaptureProgressOutput;
    AssertTrue(Trim(Captured) = '',
      'CreateProgressBar respects FPDEV_NONINTERACTIVE in the same process');
  finally
    RestoreEnv('FPDEV_NONINTERACTIVE', SavedNonInteractive);
    RestoreEnv('CI', SavedCI);
  end;
end;

procedure TestCIEnvVisibleInSameProcess;
var
  SavedNonInteractive: string;
  SavedCI: string;
  Captured: string;
begin
  SavedNonInteractive := get_env('FPDEV_NONINTERACTIVE');
  SavedCI := get_env('CI');
  try
    unset_env('FPDEV_NONINTERACTIVE');
    AssertTrue(set_env('CI', 'true'),
      'set CI env for same-process progress test');

    Captured := CaptureProgressOutput;
    AssertTrue(Trim(Captured) = '',
      'CreateProgressBar respects CI=true in the same process');
  finally
    RestoreEnv('FPDEV_NONINTERACTIVE', SavedNonInteractive);
    RestoreEnv('CI', SavedCI);
  end;
end;

begin
  TestInteractiveModeWritesOutput;
  TestNonInteractiveEnvVisibleInSameProcess;
  TestCIEnvVisibleInSameProcess;

  WriteLn;
  WriteLn('========================================');
  WriteLn('UI Progress Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
