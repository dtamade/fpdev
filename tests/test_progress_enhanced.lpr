program test_progress_enhanced;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DateUtils, fpdev.ui.progress.enhanced;

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

procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + Format(' (Expected: %d, Got: %d)', [AExpected, AActual]));
end;

procedure TestMultiStageProgressCreation;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress creation...');

  Progress := TMultiStageProgress.Create;
  try
    AssertTrue(Progress <> nil, 'Progress should be created');
    AssertTrue(Progress.ShowETA, 'ShowETA should be true by default');
    AssertTrue(Progress.ShowPercentage, 'ShowPercentage should be true by default');
    AssertEquals(0, Length(Progress.Stages), 'Should have no stages initially');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressAddStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.AddStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.AddStage('Extract');
    Progress.AddStage('Install');

    AssertEquals(3, Length(Progress.Stages), 'Should have 3 stages');
    AssertTrue(Progress.Stages[0].Name = 'Download', 'First stage should be Download');
    AssertTrue(Progress.Stages[1].Name = 'Extract', 'Second stage should be Extract');
    AssertTrue(Progress.Stages[2].Name = 'Install', 'Third stage should be Install');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressStartStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.StartStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.AddStage('Extract');

    Progress.StartStage(0, 'Downloading file...');

    AssertTrue(Progress.Stages[0].Status = ssRunning, 'First stage should be running');
    AssertEquals(0, Progress.Stages[0].Progress, 'Progress should be 0');
    AssertTrue(Progress.Stages[0].Message = 'Downloading file...', 'Message should match');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressUpdateStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.UpdateStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.StartStage(0, 'Downloading...');

    Progress.UpdateStage(0, 50, 'Half done');

    AssertEquals(50, Progress.Stages[0].Progress, 'Progress should be 50');
    AssertTrue(Progress.Stages[0].Message = 'Half done', 'Message should be updated');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressCompleteStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.CompleteStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.StartStage(0, 'Downloading...');
    Progress.CompleteStage(0, 'Download complete');

    AssertTrue(Progress.Stages[0].Status = ssCompleted, 'Stage should be completed');
    AssertEquals(100, Progress.Stages[0].Progress, 'Progress should be 100');
    AssertTrue(Progress.Stages[0].Message = 'Download complete', 'Message should match');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressFailStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.FailStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.StartStage(0, 'Downloading...');
    Progress.FailStage(0, 'Download failed');

    AssertTrue(Progress.Stages[0].Status = ssFailed, 'Stage should be failed');
    AssertTrue(Progress.Stages[0].Message = 'Download failed', 'Message should match');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressSkipStage;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.SkipStage...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Download');
    Progress.SkipStage(0, 'Already downloaded');

    AssertTrue(Progress.Stages[0].Status = ssSkipped, 'Stage should be skipped');
    AssertTrue(Progress.Stages[0].Message = 'Already downloaded', 'Message should match');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressTotalProgress;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.TotalProgress...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Stage1');
    Progress.AddStage('Stage2');
    Progress.AddStage('Stage3');

    // No progress yet
    AssertEquals(0, Progress.TotalProgress, 'Total progress should be 0');

    // Complete first stage
    Progress.StartStage(0);
    Progress.CompleteStage(0);
    AssertEquals(33, Progress.TotalProgress, 'Total progress should be 33% (1/3)');

    // Complete second stage
    Progress.StartStage(1);
    Progress.CompleteStage(1);
    AssertEquals(66, Progress.TotalProgress, 'Total progress should be 66% (2/3)');

    // Complete third stage
    Progress.StartStage(2);
    Progress.CompleteStage(2);
    AssertEquals(100, Progress.TotalProgress, 'Total progress should be 100%');
  finally
    Progress.Free;
  end;
end;

procedure TestDownloadProgressCreation;
var
  Progress: TDownloadProgress;
begin
  WriteLn('Testing TDownloadProgress creation...');

  Progress := TDownloadProgress.Create(1024 * 1024);  // 1 MB
  try
    AssertTrue(Progress <> nil, 'Progress should be created');
    AssertEquals(1024 * 1024, Progress.TotalBytes, 'Total bytes should match');
    AssertEquals(0, Progress.DownloadedBytes, 'Downloaded bytes should be 0');
    AssertEquals(0, Progress.Progress, 'Progress should be 0');
  finally
    Progress.Free;
  end;
end;

procedure TestDownloadProgressUpdate;
var
  Progress: TDownloadProgress;
begin
  WriteLn('Testing TDownloadProgress.Update...');

  Progress := TDownloadProgress.Create(1000);
  try
    Progress.Update(500);
    AssertEquals(500, Progress.DownloadedBytes, 'Downloaded bytes should be 500');
    AssertEquals(50, Progress.Progress, 'Progress should be 50%');

    Progress.Update(1000);
    AssertEquals(1000, Progress.DownloadedBytes, 'Downloaded bytes should be 1000');
    AssertEquals(100, Progress.Progress, 'Progress should be 100%');
  finally
    Progress.Free;
  end;
end;

procedure TestDownloadProgressSpeed;
var
  Progress: TDownloadProgress;
begin
  WriteLn('Testing TDownloadProgress speed calculation...');

  Progress := TDownloadProgress.Create(10000);
  try
    Progress.Update(1000);
    Sleep(100);  // Wait a bit
    Progress.Update(2000);

    // Speed should be calculated (not testing exact value due to timing)
    AssertTrue(Progress.CurrentSpeed >= 0, 'Speed should be non-negative');
  finally
    Progress.Free;
  end;
end;

procedure TestBuildProgressCreation;
var
  Progress: TBuildProgress;
begin
  WriteLn('Testing TBuildProgress creation...');

  Progress := TBuildProgress.Create(100);
  try
    AssertTrue(Progress <> nil, 'Progress should be created');
    AssertEquals(100, Progress.TotalUnits, 'Total units should be 100');
    AssertEquals(0, Progress.CompiledUnits, 'Compiled units should be 0');
    AssertEquals(0, Progress.Progress, 'Progress should be 0');
  finally
    Progress.Free;
  end;
end;

procedure TestBuildProgressUpdate;
var
  Progress: TBuildProgress;
begin
  WriteLn('Testing TBuildProgress.Update...');

  Progress := TBuildProgress.Create(100);
  try
    Progress.Update(25, 'system.pas');
    AssertEquals(25, Progress.CompiledUnits, 'Compiled units should be 25');
    AssertEquals(25, Progress.Progress, 'Progress should be 25%');
    AssertTrue(Progress.CurrentUnit = 'system.pas', 'Current unit should match');

    Progress.Update(100, 'main.pas');
    AssertEquals(100, Progress.CompiledUnits, 'Compiled units should be 100');
    AssertEquals(100, Progress.Progress, 'Progress should be 100%');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressClear;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress.Clear...');

  Progress := TMultiStageProgress.Create;
  try
    Progress.AddStage('Stage1');
    Progress.AddStage('Stage2');
    AssertEquals(2, Length(Progress.Stages), 'Should have 2 stages');

    Progress.Clear;
    AssertEquals(0, Length(Progress.Stages), 'Should have no stages after clear');
  finally
    Progress.Free;
  end;
end;

procedure TestMultiStageProgressProperties;
var
  Progress: TMultiStageProgress;
begin
  WriteLn('Testing TMultiStageProgress properties...');

  Progress := TMultiStageProgress.Create;
  try
    AssertTrue(Progress.ShowETA, 'ShowETA should be true by default');
    AssertTrue(Progress.ShowPercentage, 'ShowPercentage should be true by default');
    AssertTrue(not Progress.ShowSpinner, 'ShowSpinner should be false by default');

    Progress.ShowETA := False;
    Progress.ShowPercentage := False;
    Progress.ShowSpinner := True;

    AssertTrue(not Progress.ShowETA, 'ShowETA should be false');
    AssertTrue(not Progress.ShowPercentage, 'ShowPercentage should be false');
    AssertTrue(Progress.ShowSpinner, 'ShowSpinner should be true');
  finally
    Progress.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Running Progress Feedback Tests');
  WriteLn('========================================');
  WriteLn;

  TestMultiStageProgressCreation;
  TestMultiStageProgressAddStage;
  TestMultiStageProgressStartStage;
  TestMultiStageProgressUpdateStage;
  TestMultiStageProgressCompleteStage;
  TestMultiStageProgressFailStage;
  TestMultiStageProgressSkipStage;
  TestMultiStageProgressTotalProgress;
  TestDownloadProgressCreation;
  TestDownloadProgressUpdate;
  TestDownloadProgressSpeed;
  TestBuildProgressCreation;
  TestBuildProgressUpdate;
  TestMultiStageProgressClear;
  TestMultiStageProgressProperties;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Results');
  WriteLn('========================================');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn;

  if TestsFailed > 0 then
  begin
    WriteLn('FAILED: ', TestsFailed, ' test(s) failed');
    Halt(1);
  end
  else
  begin
    WriteLn('SUCCESS: All tests passed');
    Halt(0);
  end;
end.
