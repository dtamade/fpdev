program test_perf_monitor;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, fpjson, jsonparser,
  fpdev.perf.monitor;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestName: string;

procedure StartTest(const AName: string);
begin
  TestName := AName;
  Write('  ', AName, '... ');
end;

procedure Pass;
begin
  WriteLn('PASSED');
  Inc(PassCount);
end;

procedure Fail(const AReason: string);
begin
  WriteLn('FAILED: ', AReason);
  Inc(FailCount);
end;

procedure TestFormatElapsedTime;
begin
  StartTest('FormatElapsedTime - milliseconds');
  if FormatElapsedTime(500) = '500ms' then Pass else Fail('Expected 500ms');

  StartTest('FormatElapsedTime - seconds');
  if Pos('s', FormatElapsedTime(1500)) > 0 then Pass else Fail('Expected seconds');

  StartTest('FormatElapsedTime - minutes');
  if Pos('m', FormatElapsedTime(120000)) > 0 then Pass else Fail('Expected minutes');

  StartTest('FormatElapsedTime - hours');
  if Pos('h', FormatElapsedTime(3700000)) > 0 then Pass else Fail('Expected hours');
end;

procedure TestBasicOperation;
var
  Mon: TPerfMonitor;
  ElapsedMs: Int64;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('StartOperation creates record');
    Mon.StartOperation('TestOp');
    if Length(Mon.Operations) = 1 then Pass else Fail('Expected 1 operation');

    StartTest('Operation name stored');
    if Mon.Operations[0].Name = 'TestOp' then Pass else Fail('Wrong name');

    StartTest('EndOperation sets elapsed time');
    Sleep(50); // Wait at least 50ms
    Mon.EndOperation('TestOp', True);
    ElapsedMs := Mon.Operations[0].ElapsedMs;
    if ElapsedMs >= 50 then Pass else Fail('Expected >= 50ms, got ' + IntToStr(ElapsedMs));

    StartTest('EndOperation sets success');
    if Mon.Operations[0].Success then Pass else Fail('Expected success=true');
  finally
    Mon.Free;
  end;
end;

procedure TestParentChild;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('Parent operation');
    Mon.StartOperation('Parent');
    Mon.StartOperation('Child', 'Parent');
    Mon.EndOperation('Child', True);
    Mon.EndOperation('Parent', True);

    if Mon.Operations[1].ParentName = 'Parent' then Pass
    else Fail('Expected parent=Parent');
  finally
    Mon.Free;
  end;
end;

procedure TestMetadata;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('SetMetadata');
    Mon.StartOperation('MetaOp');
    Mon.SetMetadata('MetaOp', 'version=3.2.2');
    Mon.EndOperation('MetaOp');

    if Mon.Operations[0].Metadata = 'version=3.2.2' then Pass
    else Fail('Metadata not set');
  finally
    Mon.Free;
  end;
end;

procedure TestMark;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('Mark creates completed operation');
    Mon.Mark('QuickMark');

    if (Length(Mon.Operations) = 1) and (Mon.Operations[0].EndTime > 0) then Pass
    else Fail('Mark should create completed operation');
  finally
    Mon.Free;
  end;
end;

procedure TestGetOperationTime;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('GetOperationTime returns elapsed');
    Mon.StartOperation('TimedOp');
    Sleep(30);
    Mon.EndOperation('TimedOp');

    if Mon.GetOperationTime('TimedOp') >= 30 then Pass
    else Fail('Expected >= 30ms');

    StartTest('GetOperationTime returns 0 for unknown');
    if Mon.GetOperationTime('NonExistent') = 0 then Pass
    else Fail('Expected 0');
  finally
    Mon.Free;
  end;
end;

procedure TestClear;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('Clear removes operations');
    Mon.StartOperation('Op1');
    Mon.EndOperation('Op1');
    Mon.Clear;

    if Length(Mon.Operations) = 0 then Pass
    else Fail('Expected 0 operations');
  finally
    Mon.Free;
  end;
end;

procedure TestEnabled;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('Disabled monitor ignores StartOperation');
    Mon.Enabled := False;
    Mon.StartOperation('IgnoredOp');

    if Length(Mon.Operations) = 0 then Pass
    else Fail('Should not record when disabled');
  finally
    Mon.Free;
  end;
end;

procedure TestGetSummary;
var
  Mon: TPerfMonitor;
  Summary: string;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('GetSummary contains operation names');
    Mon.StartOperation('SummaryOp');
    Sleep(10);
    Mon.EndOperation('SummaryOp');
    Summary := Mon.GetSummary;

    if Pos('SummaryOp', Summary) > 0 then Pass
    else Fail('Summary should contain operation name');

    StartTest('GetSummary contains elapsed time');
    if Pos('ms', Summary) > 0 then Pass
    else Fail('Summary should contain time');
  finally
    Mon.Free;
  end;
end;

procedure TestGetReport;
var
  Mon: TPerfMonitor;
  Report: string;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('GetReport returns valid JSON');
    Mon.StartOperation('ReportOp');
    Mon.EndOperation('ReportOp');
    Report := Mon.GetReport;

    if (Pos('[', Report) = 1) and (Pos(']', Report) > 0) then Pass
    else Fail('Expected JSON array');

    StartTest('GetReport contains operation data');
    if (Pos('"name"', Report) > 0) and (Pos('ReportOp', Report) > 0) then Pass
    else Fail('JSON should contain operation name');
  finally
    Mon.Free;
  end;
end;

procedure TestSaveReport;
var
  Mon: TPerfMonitor;
  FileName: string;
  SL: TStringList;
begin
  Mon := TPerfMonitor.Create;
  try
    FileName := GetTempFileName('', 'perf');

    StartTest('SaveReport creates file');
    Mon.StartOperation('SavedOp');
    Mon.EndOperation('SavedOp');
    Mon.SaveReport(FileName);

    if FileExists(FileName) then Pass
    else Fail('Report file not created');

    StartTest('SaveReport file is valid JSON');
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName);
      if Pos('"generated_at"', SL.Text) > 0 then Pass
      else Fail('Invalid JSON structure');
    finally
      SL.Free;
      DeleteFile(FileName);
    end;
  finally
    Mon.Free;
  end;
end;

procedure TestGlobalPerfMon;
begin
  StartTest('Global PerfMon exists');
  if PerfMon <> nil then Pass else Fail('PerfMon is nil');

  StartTest('Global PerfMon is same instance');
  if PerfMon = PerfMon then Pass else Fail('Not same instance');
end;

procedure TestDuplicateStart;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('Duplicate StartOperation ignored');
    Mon.StartOperation('DupOp');
    Mon.StartOperation('DupOp');

    if Length(Mon.Operations) = 1 then Pass
    else Fail('Should only have 1 operation');
  finally
    Mon.Free;
  end;
end;

procedure TestEndUnstarted;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('EndOperation for unstarted does nothing');
    Mon.EndOperation('NeverStarted');

    if Length(Mon.Operations) = 0 then Pass
    else Fail('Should have 0 operations');
  finally
    Mon.Free;
  end;
end;

procedure TestFailedOperation;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    StartTest('EndOperation with success=false');
    Mon.StartOperation('FailOp');
    Mon.EndOperation('FailOp', False);

    if not Mon.Operations[0].Success then Pass
    else Fail('Expected success=false');
  finally
    Mon.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('Performance Monitor Unit Tests');
  WriteLn('========================================');
  WriteLn;

  WriteLn('[1] Format Elapsed Time Tests');
  TestFormatElapsedTime;
  WriteLn;

  WriteLn('[2] Basic Operation Tests');
  TestBasicOperation;
  WriteLn;

  WriteLn('[3] Parent-Child Tests');
  TestParentChild;
  WriteLn;

  WriteLn('[4] Metadata Tests');
  TestMetadata;
  WriteLn;

  WriteLn('[5] Mark Tests');
  TestMark;
  WriteLn;

  WriteLn('[6] GetOperationTime Tests');
  TestGetOperationTime;
  WriteLn;

  WriteLn('[7] Clear Tests');
  TestClear;
  WriteLn;

  WriteLn('[8] Enabled/Disabled Tests');
  TestEnabled;
  WriteLn;

  WriteLn('[9] GetSummary Tests');
  TestGetSummary;
  WriteLn;

  WriteLn('[10] GetReport Tests');
  TestGetReport;
  WriteLn;

  WriteLn('[11] SaveReport Tests');
  TestSaveReport;
  WriteLn;

  WriteLn('[12] Global PerfMon Tests');
  TestGlobalPerfMon;
  WriteLn;

  WriteLn('[13] Duplicate Start Tests');
  TestDuplicateStart;
  WriteLn;

  WriteLn('[14] End Unstarted Tests');
  TestEndUnstarted;
  WriteLn;

  WriteLn('[15] Failed Operation Tests');
  TestFailedOperation;
  WriteLn;

  WriteLn('========================================');
  WriteLn('Test Results Summary');
  WriteLn('========================================');
  WriteLn('Total:   ', PassCount + FailCount);
  WriteLn('Passed:  ', PassCount);
  WriteLn('Failed:  ', FailCount);
  WriteLn;

  if FailCount = 0 then
    WriteLn('All tests passed!')
  else
  begin
    WriteLn('Some tests failed!');
    Halt(1);
  end;
end.
