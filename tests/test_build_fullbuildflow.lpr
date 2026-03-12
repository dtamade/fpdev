program test_build_fullbuildflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.cache.types,
  fpdev.build.fullbuildflow;

type
  TFullBuildHarness = class
  private
    FLog: TStringList;
    FSummaries: TStringList;
    FCalls: TStringList;
    FCurrentStep: TBuildStep;
  public
    constructor Create;
    destructor Destroy; override;
    function PhasePass(const AVersion: string): Boolean;
    function PhaseFail(const AVersion: string): Boolean;
    procedure LogLine(const ALine: string);
    procedure SetStep(AStep: TBuildStep);
    procedure LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    property LogLines: TStringList read FLog;
    property Summaries: TStringList read FSummaries;
    property Calls: TStringList read FCalls;
    property CurrentStep: TBuildStep read FCurrentStep;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TFullBuildHarness.Create;
begin
  inherited Create;
  FLog := TStringList.Create;
  FSummaries := TStringList.Create;
  FCalls := TStringList.Create;
  FCurrentStep := bsIdle;
end;

destructor TFullBuildHarness.Destroy;
begin
  FCalls.Free;
  FSummaries.Free;
  FLog.Free;
  inherited Destroy;
end;

function TFullBuildHarness.PhasePass(const AVersion: string): Boolean;
begin
  FCalls.Add('pass:' + AVersion);
  Result := True;
end;

function TFullBuildHarness.PhaseFail(const AVersion: string): Boolean;
begin
  FCalls.Add('fail:' + AVersion);
  Result := False;
end;

procedure TFullBuildHarness.LogLine(const ALine: string);
begin
  FLog.Add(ALine);
end;

procedure TFullBuildHarness.SetStep(AStep: TBuildStep);
begin
  FCurrentStep := AStep;
end;

procedure TFullBuildHarness.LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
begin
  FSummaries.Add(AVersion + '|' + AContext + '|' + AResult + '|' + IntToStr(AElapsedMs));
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure TestRunFullBuildCoreSuccess;
var
  Harness: TFullBuildHarness;
  OK: Boolean;
begin
  Harness := TFullBuildHarness.Create;
  try
    OK := RunFullBuildCore(
      'demo',
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.SetStep,
      @Harness.LogLine,
      @Harness.LogSummary
    );

    Check('fullbuild success returns true', OK, 'expected success');
    Check('fullbuild marks step complete', Harness.CurrentStep = bsComplete,
      'step=' + IntToStr(Ord(Harness.CurrentStep)));
    Check('fullbuild logs start line', Harness.LogLines.Count > 0,
      'no log lines');
    Check('fullbuild logs start banner', Pos('== FullBuild START version=demo', Harness.LogLines.Text) > 0,
      'start banner missing');
    Check('fullbuild logs end banner', Pos('== FullBuild END OK elapsed_ms=', Harness.LogLines.Text) > 0,
      'end banner missing');
    Check('fullbuild logs one summary', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('fullbuild summary marks ok', Pos('demo|fullbuild|OK|', Harness.Summaries[0]) = 1,
      'summary=' + Harness.Summaries[0]);
    Check('fullbuild executes seven handlers', Harness.Calls.Count = 7,
      'calls=' + IntToStr(Harness.Calls.Count));
  finally
    Harness.Free;
  end;
end;

procedure TestRunFullBuildCoreFailure;
var
  Harness: TFullBuildHarness;
  OK: Boolean;
begin
  Harness := TFullBuildHarness.Create;
  try
    OK := RunFullBuildCore(
      'demo',
      @Harness.PhasePass,
      @Harness.PhaseFail,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.PhasePass,
      @Harness.SetStep,
      @Harness.LogLine,
      @Harness.LogSummary
    );

    Check('fullbuild failure returns false', not OK, 'expected failure');
    Check('fullbuild failure resets idle via pipeline', Harness.CurrentStep = bsIdle,
      'step=' + IntToStr(Ord(Harness.CurrentStep)));
    Check('fullbuild failure logs abort line', Pos('== FullBuild ABORT at BuildCompiler', Harness.LogLines.Text) > 0,
      'abort log missing');
    Check('fullbuild failure skips summary', Harness.Summaries.Count = 0,
      'summary count=' + IntToStr(Harness.Summaries.Count));
  finally
    Harness.Free;
  end;
end;

begin
  TestRunFullBuildCoreSuccess;
  TestRunFullBuildCoreFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
