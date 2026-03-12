program test_build_testresultsflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  test_temp_paths,
  fpdev.build.probe,
  fpdev.build.testresultsflow;

type
  TTestResultsHarness = class
  private
    FLogLines: TStringList;
    FSampledDirs: TStringList;
    FSummaries: TStringList;
    FSourcePath: string;
    FStrictResult: Boolean;
    FStrictCalls: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function GetSourcePath(const AVersion: string): string;
    function ApplyStrictConfig(const ASandboxDest: string): Boolean;
    procedure LogLine(const ALine: string);
    procedure LogDirSample(const ADir: string; ALimit: Integer);
    procedure LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
    property LogLines: TStringList read FLogLines;
    property SampledDirs: TStringList read FSampledDirs;
    property Summaries: TStringList read FSummaries;
    property SourcePath: string read FSourcePath write FSourcePath;
    property StrictResult: Boolean read FStrictResult write FStrictResult;
    property StrictCalls: Integer read FStrictCalls;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

constructor TTestResultsHarness.Create;
begin
  inherited Create;
  FLogLines := TStringList.Create;
  FSampledDirs := TStringList.Create;
  FSummaries := TStringList.Create;
  FStrictResult := True;
  FStrictCalls := 0;
end;

destructor TTestResultsHarness.Destroy;
begin
  FSummaries.Free;
  FSampledDirs.Free;
  FLogLines.Free;
  inherited Destroy;
end;

function TTestResultsHarness.GetSourcePath(const AVersion: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FSourcePath) + 'fpc-' + AVersion;
end;

function TTestResultsHarness.ApplyStrictConfig(const ASandboxDest: string): Boolean;
begin
  Inc(FStrictCalls);
  FLogLines.Add('strict:' + ASandboxDest);
  Result := FStrictResult;
end;

procedure TTestResultsHarness.LogLine(const ALine: string);
begin
  FLogLines.Add(ALine);
end;

procedure TTestResultsHarness.LogDirSample(const ADir: string; ALimit: Integer);
begin
  FSampledDirs.Add(ADir + '|' + IntToStr(ALimit));
end;

procedure TTestResultsHarness.LogSummary(const AVersion, AContext, AResult: string; AElapsedMs: Integer);
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

procedure WriteTextFile(const APath, AText: string);
var
  Handle: TextFile;
begin
  AssignFile(Handle, APath);
  Rewrite(Handle);
  try
    WriteLn(Handle, AText);
  finally
    CloseFile(Handle);
  end;
end;

function PathExists(const APath: string): Boolean;
begin
  Result := DirectoryExists(APath);
end;

procedure TestSandboxSuccessLogsSummaryAndSamples;
var
  Harness: TTestResultsHarness;
  RootDir, SandboxRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-ok');
  try
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    BinDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'bin';
    LibDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'lib' + PathDelim + 'fpc';
    ForceDirectories(BinDir);
    ForceDirectories(LibDir);
    WriteTextFile(BinDir + PathDelim + 'fpc', 'demo');
    WriteTextFile(LibDir + PathDelim + 'placeholder', 'demo');

    OK := ExecuteBuildTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      False,
      1,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('sandbox success returns true', OK, 'expected success');
    Check('sandbox success logs ok line',
      Pos('TestResults: sandbox OK at ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('sandbox success records one summary', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('sandbox success summary marks ok',
      Pos('demo|sandbox|OK|', Harness.Summaries[0]) = 1,
      Harness.Summaries[0]);
    Check('sandbox success samples bin and lib', Harness.SampledDirs.Count = 2,
      'sample count=' + IntToStr(Harness.SampledDirs.Count));
    Check('sandbox success skips strict config when disabled', Harness.StrictCalls = 0,
      'strict calls=' + IntToStr(Harness.StrictCalls));
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSandboxMissingRootFailsWithSummary;
var
  Harness: TTestResultsHarness;
  RootDir, SandboxRoot: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-missing-root');
  try
    SandboxRoot := RootDir + PathDelim + 'sandbox';

    OK := ExecuteBuildTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      False,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('sandbox missing root returns false', not OK, 'expected failure');
    Check('sandbox missing root logs failure',
      Pos('TestResults: sandbox root missing: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('sandbox missing root summary marks fail', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('sandbox missing root summary context is sandbox',
      Pos('demo|sandbox|FAIL|', Harness.Summaries[0]) = 1,
      Harness.Summaries[0]);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSandboxStrictEmptyBinFails;
var
  Harness: TTestResultsHarness;
  RootDir, SandboxRoot, BinDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-empty-bin');
  try
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    BinDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'bin';
    ForceDirectories(BinDir);

    OK := ExecuteBuildTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      True,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('strict empty bin returns false', not OK, 'expected failure');
    Check('strict empty bin logs strict failure',
      Pos('FAIL: sandbox bin empty under strict mode: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('strict empty bin summary context is sandbox/bin', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('strict empty bin summary marks fail',
      Pos('demo|sandbox/bin|FAIL|', Harness.Summaries[0]) = 1,
      Harness.Summaries[0]);
    Check('strict empty bin stops before strict config', Harness.StrictCalls = 0,
      'strict calls=' + IntToStr(Harness.StrictCalls));
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSandboxNonStrictEmptyLibWarnsAndContinues;
var
  Harness: TTestResultsHarness;
  RootDir, SandboxRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-empty-lib');
  try
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    BinDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'bin';
    LibDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'lib';
    ForceDirectories(BinDir);
    ForceDirectories(LibDir);
    WriteTextFile(BinDir + PathDelim + 'fpc', 'demo');

    OK := ExecuteBuildTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      False,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('nonstrict empty lib still returns true', OK, 'expected success');
    Check('nonstrict empty lib logs warning',
      Pos('WARN: sandbox lib is empty: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('nonstrict empty lib still logs sandbox success summary', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('nonstrict empty lib summary marks ok',
      Pos('demo|sandbox|OK|', Harness.Summaries[0]) = 1,
      Harness.Summaries[0]);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSandboxStrictConfigFailure;
var
  Harness: TTestResultsHarness;
  RootDir, SandboxRoot, BinDir, LibDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-strict-config');
  try
    Harness.StrictResult := False;
    SandboxRoot := RootDir + PathDelim + 'sandbox';
    BinDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'bin';
    LibDir := SandboxRoot + PathDelim + 'fpc-demo' + PathDelim + 'lib' + PathDelim + 'fpc';
    ForceDirectories(BinDir);
    ForceDirectories(LibDir);
    WriteTextFile(BinDir + PathDelim + 'fpc', 'demo');
    WriteTextFile(LibDir + PathDelim + 'placeholder', 'demo');

    OK := ExecuteBuildTestResultsCore(
      'demo',
      SandboxRoot,
      True,
      True,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('strict config failure returns false', not OK, 'expected failure');
    Check('strict config failure calls strict verifier once', Harness.StrictCalls = 1,
      'strict calls=' + IntToStr(Harness.StrictCalls));
    Check('strict config failure summary context is sandbox/strict', Harness.Summaries.Count = 1,
      'summary count=' + IntToStr(Harness.Summaries.Count));
    Check('strict config failure summary marks fail',
      Pos('demo|sandbox/strict|FAIL|', Harness.Summaries[0]) = 1,
      Harness.Summaries[0]);
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSourceFallbackSuccessSkipsSummary;
var
  Harness: TTestResultsHarness;
  RootDir, CompilerDir, RTLDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-source-ok');
  try
    Harness.SourcePath := RootDir + PathDelim + 'sources';
    CompilerDir := Harness.GetSourcePath('demo') + PathDelim + 'compiler';
    RTLDir := Harness.GetSourcePath('demo') + PathDelim + 'rtl';
    ForceDirectories(CompilerDir);
    ForceDirectories(RTLDir);

    OK := ExecuteBuildTestResultsCore(
      'demo',
      RootDir + PathDelim + 'sandbox',
      False,
      False,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('source fallback success returns true', OK, 'expected success');
    Check('source fallback logs source success',
      Pos('TestResults: source tree OK at ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('source fallback skips summary output', Harness.Summaries.Count = 0,
      'summary count=' + IntToStr(Harness.Summaries.Count));
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

procedure TestSourceFallbackMissingCompilerFails;
var
  Harness: TTestResultsHarness;
  RootDir, RTLDir: string;
  OK: Boolean;
begin
  Harness := TTestResultsHarness.Create;
  RootDir := CreateUniqueTempDir('build-testresults-source-missing');
  try
    Harness.SourcePath := RootDir + PathDelim + 'sources';
    RTLDir := Harness.GetSourcePath('demo') + PathDelim + 'rtl';
    ForceDirectories(RTLDir);

    OK := ExecuteBuildTestResultsCore(
      'demo',
      RootDir + PathDelim + 'sandbox',
      False,
      False,
      0,
      @Harness.GetSourcePath,
      @Harness.ApplyStrictConfig,
      @PathExists,
      @BuildManagerDirHasAnyFile,
      @BuildManagerDirHasAnyEntry,
      @Harness.LogLine,
      @Harness.LogDirSample,
      @Harness.LogSummary
    );

    Check('source fallback missing compiler returns false', not OK, 'expected failure');
    Check('source fallback missing compiler logs error',
      Pos('TestResults: missing compiler dir: ', Harness.LogLines.Text) > 0,
      Harness.LogLines.Text);
    Check('source fallback missing compiler skips summary', Harness.Summaries.Count = 0,
      'summary count=' + IntToStr(Harness.Summaries.Count));
  finally
    CleanupTempDir(RootDir);
    Harness.Free;
  end;
end;

begin
  TestSandboxSuccessLogsSummaryAndSamples;
  TestSandboxMissingRootFailsWithSummary;
  TestSandboxStrictEmptyBinFails;
  TestSandboxNonStrictEmptyLibWarnsAndContinues;
  TestSandboxStrictConfigFailure;
  TestSourceFallbackSuccessSkipsSummary;
  TestSourceFallbackMissingCompilerFails;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
