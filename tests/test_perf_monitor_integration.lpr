program test_perf_monitor_integration;

{$mode objfpc}{$H+}

{
================================================================================
  test_perf_monitor_integration - Integration tests for performance monitoring
================================================================================

  Tests PerfMonitor in real-world integration scenarios:
  - Multi-operation pipeline (simulating build workflow)
  - Nested operation chains (3+ levels deep)
  - JSON report completeness validation
  - Threshold detection for slow operations
  - SaveReport file content verification
  - Clear and reuse cycle
  - Memory tracking on Linux
  - Global PerfMon singleton behavior across modules

  B183: TDD Integration Tests for Performance Monitoring

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, DateUtils, fpjson, jsonparser,
  fpdev.perf.monitor;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;
  GTempDir: string;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ ===== Group 1: Build pipeline simulation ===== }

procedure TestBuildPipelineSimulation;
var
  Mon: TPerfMonitor;
  I: Integer;
  AllSuccess: Boolean;
begin
  Mon := TPerfMonitor.Create;
  try
    // Simulate a typical build pipeline: Preflight -> Compiler -> RTL -> Install
    Mon.StartOperation('Preflight', 'Build');
    Sleep(10);
    Mon.EndOperation('Preflight', True);

    Mon.StartOperation('BuildCompiler', 'Build');
    Mon.SetMetadata('BuildCompiler', 'version=3.2.2');
    Sleep(15);
    Mon.EndOperation('BuildCompiler', True);

    Mon.StartOperation('BuildRTL', 'Build');
    Mon.SetMetadata('BuildRTL', 'version=3.2.2');
    Sleep(10);
    Mon.EndOperation('BuildRTL', True);

    Mon.StartOperation('Install', 'Build');
    Mon.SetMetadata('Install', 'version=3.2.2,dest=/tmp/sandbox');
    Sleep(10);
    Mon.EndOperation('Install', True);

    Test('Pipeline: 4 operations recorded', Length(Mon.Operations) = 4);

    AllSuccess := True;
    for I := 0 to High(Mon.Operations) do
      if not Mon.Operations[I].Success then AllSuccess := False;
    Test('Pipeline: all operations succeeded', AllSuccess);

    Test('Pipeline: all have parent=Build',
      (Mon.Operations[0].ParentName = 'Build') and
      (Mon.Operations[1].ParentName = 'Build') and
      (Mon.Operations[2].ParentName = 'Build') and
      (Mon.Operations[3].ParentName = 'Build'));

    Test('Pipeline: all elapsed > 0',
      (Mon.Operations[0].ElapsedMs > 0) and
      (Mon.Operations[1].ElapsedMs > 0) and
      (Mon.Operations[2].ElapsedMs > 0) and
      (Mon.Operations[3].ElapsedMs > 0));

    Test('Pipeline: metadata preserved on BuildCompiler',
      Mon.Operations[1].Metadata = 'version=3.2.2');
  finally
    Mon.Free;
  end;
end;

{ ===== Group 2: Nested operation chains ===== }

procedure TestNestedOperationChain;
var
  Mon: TPerfMonitor;
  Report: string;
begin
  Mon := TPerfMonitor.Create;
  try
    // 3-level nesting: Build > Compiler > Parse
    Mon.StartOperation('Build');
    Sleep(5);

    Mon.StartOperation('Compiler', 'Build');
    Sleep(5);

    Mon.StartOperation('Parse', 'Compiler');
    Sleep(5);
    Mon.EndOperation('Parse', True);

    Mon.StartOperation('CodeGen', 'Compiler');
    Sleep(5);
    Mon.EndOperation('CodeGen', True);

    Mon.EndOperation('Compiler', True);
    Mon.EndOperation('Build', True);

    Test('Nested: 4 operations total', Length(Mon.Operations) = 4);
    Test('Nested: Build has no parent', Mon.Operations[0].ParentName = '');
    Test('Nested: Compiler parent is Build', Mon.Operations[1].ParentName = 'Build');
    Test('Nested: Parse parent is Compiler', Mon.Operations[2].ParentName = 'Compiler');
    Test('Nested: CodeGen parent is Compiler', Mon.Operations[3].ParentName = 'Compiler');

    // Build elapsed should be >= Compiler elapsed (it wraps it)
    Test('Nested: Build elapsed >= Compiler elapsed',
      Mon.Operations[0].ElapsedMs >= Mon.Operations[1].ElapsedMs);

    Report := Mon.GetReport;
    Test('Nested: report contains parent field', Pos('"parent"', Report) > 0);
  finally
    Mon.Free;
  end;
end;

{ ===== Group 3: JSON report completeness ===== }

procedure TestJsonReportCompleteness;
var
  Mon: TPerfMonitor;
  Report: string;
  JData: TJSONData;
  JArr: TJSONArray;
  JObj: TJSONObject;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('TestOp');
    Mon.SetMetadata('TestOp', 'key=value');
    Sleep(5);
    Mon.EndOperation('TestOp', True);

    Report := Mon.GetReport;

    // Parse JSON
    JData := GetJSON(Report);
    try
      Test('Report: is valid JSON array', JData is TJSONArray);

      JArr := JData as TJSONArray;
      Test('Report: has 1 element', JArr.Count = 1);

      JObj := JArr.Objects[0];
      Test('Report: has name field', JObj.Find('name') <> nil);
      Test('Report: has elapsed_ms field', JObj.Find('elapsed_ms') <> nil);
      Test('Report: has success field', JObj.Find('success') <> nil);
      Test('Report: has start_time field', JObj.Find('start_time') <> nil);
      Test('Report: has end_time field', JObj.Find('end_time') <> nil);
      Test('Report: has metadata field', JObj.Find('metadata') <> nil);
      Test('Report: name is TestOp', JObj.Get('name', '') = 'TestOp');
      Test('Report: success is true', JObj.Get('success', False) = True);
      Test('Report: metadata preserved', JObj.Get('metadata', '') = 'key=value');
    finally
      JData.Free;
    end;
  finally
    Mon.Free;
  end;
end;

{ ===== Group 4: SaveReport file verification ===== }

procedure TestSaveReportFile;
var
  Mon: TPerfMonitor;
  FilePath, Content: string;
  JData: TJSONData;
  JObj: TJSONObject;
  SL: TStringList;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('SaveTest');
    Sleep(5);
    Mon.EndOperation('SaveTest', True);

    FilePath := GTempDir + PathDelim + 'perf_report.json';
    Mon.SaveReport(FilePath);

    Test('SaveReport: file exists', FileExists(FilePath));

    SL := TStringList.Create;
    try
      SL.LoadFromFile(FilePath);
      Content := SL.Text;
    finally
      SL.Free;
    end;

    Test('SaveReport: file not empty', Length(Content) > 0);

    JData := GetJSON(Content);
    try
      Test('SaveReport: valid JSON', JData is TJSONObject);

      JObj := JData as TJSONObject;
      Test('SaveReport: has generated_at', JObj.Find('generated_at') <> nil);
      Test('SaveReport: has total_time_ms', JObj.Find('total_time_ms') <> nil);
      Test('SaveReport: has operations array', JObj.Find('operations') <> nil);
      Test('SaveReport: operations is array',
        JObj.Find('operations') is TJSONArray);
      Test('SaveReport: operations has entries',
        (JObj.Find('operations') as TJSONArray).Count > 0);
    finally
      JData.Free;
    end;
  finally
    Mon.Free;
  end;
end;

{ ===== Group 5: Threshold detection for slow operations ===== }

procedure TestThresholdDetection;
var
  Mon: TPerfMonitor;
  I: Integer;
  SlowOps: Integer;
  ThresholdMs: Int64;
begin
  Mon := TPerfMonitor.Create;
  try
    // Simulate some fast and some slow operations
    Mon.StartOperation('FastOp1');
    Sleep(5);
    Mon.EndOperation('FastOp1', True);

    Mon.StartOperation('SlowOp');
    Sleep(60);  // intentionally slow
    Mon.EndOperation('SlowOp', True);

    Mon.StartOperation('FastOp2');
    Sleep(5);
    Mon.EndOperation('FastOp2', True);

    // Detect operations exceeding threshold (50ms)
    ThresholdMs := 50;
    SlowOps := 0;
    for I := 0 to High(Mon.Operations) do
      if Mon.Operations[I].ElapsedMs > ThresholdMs then
        Inc(SlowOps);

    Test('Threshold: detected slow operations', SlowOps >= 1);
    Test('Threshold: SlowOp exceeds 50ms', Mon.GetOperationTime('SlowOp') > ThresholdMs);
    Test('Threshold: FastOp1 within threshold', Mon.GetOperationTime('FastOp1') < ThresholdMs);
  finally
    Mon.Free;
  end;
end;

{ ===== Group 6: Clear and reuse cycle ===== }

procedure TestClearAndReuse;
var
  Mon: TPerfMonitor;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('BeforeClear');
    Sleep(5);
    Mon.EndOperation('BeforeClear', True);

    Test('ClearReuse: 1 op before clear', Length(Mon.Operations) = 1);

    Mon.Clear;

    Test('ClearReuse: 0 ops after clear', Length(Mon.Operations) = 0);
    Test('ClearReuse: GetOperationTime returns 0 after clear',
      Mon.GetOperationTime('BeforeClear') = 0);

    // Can reuse after clear
    Mon.StartOperation('AfterClear');
    Sleep(5);
    Mon.EndOperation('AfterClear', True);

    Test('ClearReuse: 1 op after reuse', Length(Mon.Operations) = 1);
    Test('ClearReuse: new op name correct', Mon.Operations[0].Name = 'AfterClear');
    Test('ClearReuse: new op elapsed > 0', Mon.Operations[0].ElapsedMs > 0);
  finally
    Mon.Free;
  end;
end;

{ ===== Group 7: Failed operation tracking ===== }

procedure TestFailedOperationPipeline;
var
  Mon: TPerfMonitor;
  Summary: string;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('Step1');
    Sleep(5);
    Mon.EndOperation('Step1', True);

    Mon.StartOperation('Step2');
    Sleep(5);
    Mon.EndOperation('Step2', False);  // failure

    Mon.StartOperation('Step3');
    Sleep(5);
    Mon.EndOperation('Step3', True);

    Test('FailedPipeline: Step1 success', Mon.Operations[0].Success);
    Test('FailedPipeline: Step2 failed', not Mon.Operations[1].Success);
    Test('FailedPipeline: Step3 success', Mon.Operations[2].Success);

    Summary := Mon.GetSummary;
    Test('FailedPipeline: summary contains [FAIL]', Pos('[FAIL]', Summary) > 0);
    Test('FailedPipeline: summary contains [OK]', Pos('[OK]', Summary) > 0);
  finally
    Mon.Free;
  end;
end;

{ ===== Group 8: Memory tracking (Linux) ===== }

procedure TestMemoryTracking;
var
  Mon: TPerfMonitor;
  MemBefore, MemAfter: Int64;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('MemTest');
    Sleep(5);
    Mon.EndOperation('MemTest', True);

    MemBefore := Mon.Operations[0].MemoryBefore;
    MemAfter := Mon.Operations[0].MemoryAfter;

    {$IFDEF LINUX}
    Test('Memory: MemoryBefore > 0 on Linux', MemBefore > 0);
    Test('Memory: MemoryAfter > 0 on Linux', MemAfter > 0);
    {$ELSE}
    // On non-Linux, memory tracking returns 0
    Test('Memory: MemoryBefore = 0 on non-Linux', MemBefore = 0);
    Test('Memory: MemoryAfter = 0 on non-Linux', MemAfter = 0);
    {$ENDIF}
  finally
    Mon.Free;
  end;
end;

{ ===== Group 9: Global PerfMon singleton ===== }

procedure TestGlobalPerfMonSingleton;
var
  Report: string;
begin
  PerfMon.Clear;

  PerfMon.StartOperation('GlobalTest1');
  Sleep(5);
  PerfMon.EndOperation('GlobalTest1', True);

  PerfMon.StartOperation('GlobalTest2');
  Sleep(5);
  PerfMon.EndOperation('GlobalTest2', True);

  Test('GlobalSingleton: 2 operations recorded', Length(PerfMon.Operations) = 2);

  Report := PerfMon.GetReport;
  Test('GlobalSingleton: report contains GlobalTest1', Pos('GlobalTest1', Report) > 0);
  Test('GlobalSingleton: report contains GlobalTest2', Pos('GlobalTest2', Report) > 0);

  PerfMon.Clear;
  Test('GlobalSingleton: clear works', Length(PerfMon.Operations) = 0);
end;

{ ===== Group 10: Summary format verification ===== }

procedure TestSummaryFormat;
var
  Mon: TPerfMonitor;
  Summary: string;
begin
  Mon := TPerfMonitor.Create;
  try
    Mon.StartOperation('Alpha');
    Sleep(5);
    Mon.EndOperation('Alpha', True);

    Mon.StartOperation('Beta');
    Sleep(5);
    Mon.EndOperation('Beta', False);

    Summary := Mon.GetSummary;

    Test('Summary: contains header', Pos('Performance Summary', Summary) > 0);
    Test('Summary: contains Alpha', Pos('Alpha', Summary) > 0);
    Test('Summary: contains Beta', Pos('Beta', Summary) > 0);
    Test('Summary: contains Total line', Pos('Total', Summary) > 0);
    Test('Summary: contains separator', Pos('===', Summary) > 0);
  finally
    Mon.Free;
  end;
end;

{ ===== Main ===== }
begin
  WriteLn('=== Performance Monitor Integration Tests ===');
  WriteLn;

  GTempDir := GetTempDir + 'fpdev_test_perf_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    // Group 1: Build pipeline simulation
    WriteLn('--- Build Pipeline Simulation ---');
    TestBuildPipelineSimulation;

    // Group 2: Nested operation chains
    WriteLn('');
    WriteLn('--- Nested Operation Chains ---');
    TestNestedOperationChain;

    // Group 3: JSON report completeness
    WriteLn('');
    WriteLn('--- JSON Report Completeness ---');
    TestJsonReportCompleteness;

    // Group 4: SaveReport file verification
    WriteLn('');
    WriteLn('--- SaveReport File Verification ---');
    TestSaveReportFile;

    // Group 5: Threshold detection
    WriteLn('');
    WriteLn('--- Threshold Detection ---');
    TestThresholdDetection;

    // Group 6: Clear and reuse
    WriteLn('');
    WriteLn('--- Clear and Reuse ---');
    TestClearAndReuse;

    // Group 7: Failed operation pipeline
    WriteLn('');
    WriteLn('--- Failed Operation Pipeline ---');
    TestFailedOperationPipeline;

    // Group 8: Memory tracking
    WriteLn('');
    WriteLn('--- Memory Tracking ---');
    TestMemoryTracking;

    // Group 9: Global singleton
    WriteLn('');
    WriteLn('--- Global PerfMon Singleton ---');
    TestGlobalPerfMonSingleton;

    // Group 10: Summary format
    WriteLn('');
    WriteLn('--- Summary Format Verification ---');
    TestSummaryFormat;
  finally
    // Cleanup
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'perf_report.json');
      RemoveDir(GTempDir);
    end;
  end;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  WriteLn;

  if GFailCount > 0 then
    Halt(1);
end.
