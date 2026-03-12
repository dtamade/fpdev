program test_build_manager_make_missing;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.build.manager, fpdev.build.preflight, fpdev.build.strict;

procedure EnsureDir(const APath: string);
begin
  if (APath <> '') and (not DirectoryExists(APath)) then
    ForceDirectories(APath);
end;

procedure Fail(const AMsg: string);
begin
  WriteLn('[FAIL] ', AMsg);
  Halt(1);
end;

procedure Pass(const AMsg: string);
begin
  WriteLn('[PASS] ', AMsg);
end;

procedure AssertContains(const AItems: TStringArray; const AExpected, AMsg: string);
var
  I: Integer;
begin
  for I := 0 to High(AItems) do
    if SameText(AItems[I], AExpected) then
    begin
      Pass(AMsg);
      Exit;
    end;
  Fail(AMsg + ' (missing: ' + AExpected + ')');
end;

procedure TestCollectBuildPreflightIssuesCoreCollectsExpectedIssues;
var
  Inputs: TBuildPreflightInputs;
  Issues: TStringArray;
begin
  Inputs.Version := 'main';
  Inputs.SourcePath := '/tmp/missing-src';
  Inputs.SandboxRoot := '/tmp/sandbox';
  Inputs.LogDir := '/tmp/logs';
  Inputs.SandboxDestRoot := '/tmp/sandbox/fpc-main';
  Inputs.ToolchainStrict := False;
  Inputs.AllowInstall := True;
  Inputs.HasMake := False;
  Inputs.SourceExists := False;
  Inputs.SandboxWritable := False;
  Inputs.LogWritable := False;
  Inputs.SandboxDestExists := True;
  Inputs.SandboxDestWritable := False;
  Inputs.PolicyCheckPassed := True;
  Inputs.PolicyStatus := 'OK';
  Inputs.PolicyReason := '';
  Inputs.PolicyMin := '';
  Inputs.PolicyRecommended := '';
  Inputs.CurrentFpcVersion := '';
  Inputs.ToolchainReportJSON := '{"level":"OK"}';

  Issues := CollectBuildPreflightIssuesCore(Inputs);
  if Length(Issues) <> 5 then
    Fail('CollectBuildPreflightIssuesCore should emit 5 issues, got ' + IntToStr(Length(Issues)));
  AssertContains(Issues, 'source not found: /tmp/missing-src',
    'CollectBuildPreflightIssuesCore reports missing source');
  AssertContains(Issues, 'make not available',
    'CollectBuildPreflightIssuesCore reports missing make');
  AssertContains(Issues, 'sandbox not writable: /tmp/sandbox',
    'CollectBuildPreflightIssuesCore reports sandbox not writable');
  AssertContains(Issues, 'logs not writable: /tmp/logs',
    'CollectBuildPreflightIssuesCore reports logs not writable');
  AssertContains(Issues, 'sandbox dest not writable: /tmp/sandbox/fpc-main',
    'CollectBuildPreflightIssuesCore reports sandbox dest not writable');
end;

type
  TStrictLogHarness = class
  private
    FLines: TStringList;
    FSamples: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Log(const ALine: string);
    procedure LogSample(const ADir: string; ALimit: Integer);
    property Lines: TStringList read FLines;
    property Samples: TStringList read FSamples;
  end;

constructor TStrictLogHarness.Create;
begin
  inherited Create;
  FLines := TStringList.Create;
  FSamples := TStringList.Create;
end;

destructor TStrictLogHarness.Destroy;
begin
  FSamples.Free;
  FLines.Free;
  inherited Destroy;
end;

procedure TStrictLogHarness.Log(const ALine: string);
begin
  FLines.Add(ALine);
end;

procedure TStrictLogHarness.LogSample(const ADir: string; ALimit: Integer);
begin
  FSamples.Add(ADir + '#' + IntToStr(ALimit));
end;

procedure TestBuildManagerValidateDirRuleCoreRequiresConfiguredSubdir;
var
  TempDir: string;
  ShareDir: string;
  Rule: TBuildStrictDirRule;
  Harness: TStrictLogHarness;
begin
  TempDir := GetTempFileName(GetTempDir(False), 'strictdir');
  if FileExists(TempDir) then
    DeleteFile(TempDir);
  TempDir := TempDir + '_dir_rule';
  ForceDirectories(TempDir);
  ShareDir := IncludeTrailingPathDelimiter(TempDir) + 'share';
  ForceDirectories(ShareDir);

  Harness := TStrictLogHarness.Create;
  try
    Rule.SectionName := 'share';
    Rule.RelativeDir := 'share';
    Rule.Required := True;
    Rule.MinCount := 0;
    Rule.RequireSubdir := False;
    Rule.RequiredSubdir := 'fpmake';

    if BuildManagerValidateDirRuleCore(TempDir, Rule, 1, @Harness.Log, @Harness.LogSample) then
      Fail('BuildManagerValidateDirRuleCore should fail when required subdir is missing');
    if Harness.Lines.IndexOf('FAIL: [share] required_subdir missing: fpmake') < 0 then
      Fail('BuildManagerValidateDirRuleCore should report missing required subdir');
    if Harness.Lines.IndexOf('hint: [share] expected subdir: fpmake') < 0 then
      Fail('BuildManagerValidateDirRuleCore should emit required-subdir hint');
    Pass('BuildManagerValidateDirRuleCore reports missing required subdir');
  finally
    Harness.Free;
    RemoveDir(ShareDir);
    RemoveDir(TempDir);
  end;
end;

procedure TestBuildManagerValidateDirRuleCoreReportsOptionalPresenceAtVerbose;
var
  TempDir: string;
  DocDir: string;
  Rule: TBuildStrictDirRule;
  Harness: TStrictLogHarness;
begin
  TempDir := GetTempFileName(GetTempDir(False), 'strictdir');
  if FileExists(TempDir) then
    DeleteFile(TempDir);
  TempDir := TempDir + '_optional_rule';
  ForceDirectories(TempDir);
  DocDir := IncludeTrailingPathDelimiter(TempDir) + 'doc';
  ForceDirectories(DocDir);

  Harness := TStrictLogHarness.Create;
  try
    Rule.SectionName := 'doc';
    Rule.RelativeDir := 'doc';
    Rule.Required := False;
    Rule.MinCount := 0;
    Rule.RequireSubdir := False;
    Rule.RequiredSubdir := '';

    if not BuildManagerValidateDirRuleCore(TempDir, Rule, 1, @Harness.Log, @Harness.LogSample) then
      Fail('BuildManagerValidateDirRuleCore should ignore optional present dir');
    if Harness.Lines.IndexOf('info: [doc] present but not required') < 0 then
      Fail('BuildManagerValidateDirRuleCore should log optional present dir at verbose mode');
    Pass('BuildManagerValidateDirRuleCore logs optional present dir');
  finally
    Harness.Free;
    RemoveDir(DocDir);
    RemoveDir(TempDir);
  end;
end;

procedure TestBuildManagerValidateBinRuleCoreReportsMissingExecutableHints;
var
  TempDir: string;
  BinDir: string;
  Harness: TStrictLogHarness;
  F: TextFile;
begin
  TempDir := GetTempFileName(GetTempDir(False), 'strictbin');
  if FileExists(TempDir) then
    DeleteFile(TempDir);
  TempDir := TempDir + '_bin_rule';
  ForceDirectories(TempDir);
  BinDir := IncludeTrailingPathDelimiter(TempDir) + 'bin';
  ForceDirectories(BinDir);

  AssignFile(F, IncludeTrailingPathDelimiter(BinDir) + 'readme.txt');
  Rewrite(F);
  WriteLn(F, 'not an executable');
  CloseFile(F);

  Harness := TStrictLogHarness.Create;
  try
    if BuildManagerValidateBinRuleCore(
      TempDir,
      1,
      'fpc,ppc',
      '.exe,.sh,',
      1,
      @Harness.Log,
      @Harness.LogSample
    ) then
      Fail('BuildManagerValidateBinRuleCore should fail when bin lacks required executable');
    if Harness.Lines.IndexOf('FAIL: [bin] missing required executable (prefix/ext)') < 0 then
      Fail('BuildManagerValidateBinRuleCore should report missing executable');
    if Harness.Lines.IndexOf('hint: [bin] required_prefix=fpc,ppc') < 0 then
      Fail('BuildManagerValidateBinRuleCore should log required_prefix hint');
    if Harness.Lines.IndexOf('hint: [bin] required_ext=.exe,.sh,') < 0 then
      Fail('BuildManagerValidateBinRuleCore should log required_ext hint');
    if Harness.Samples.IndexOf(BinDir + '#20') < 0 then
      Fail('BuildManagerValidateBinRuleCore should request a sample of bin dir');
    Pass('BuildManagerValidateBinRuleCore reports missing executable hints');
  finally
    Harness.Free;
    DeleteFile(IncludeTrailingPathDelimiter(BinDir) + 'readme.txt');
    RemoveDir(BinDir);
    RemoveDir(TempDir);
  end;
end;

procedure TestBuildManagerValidateFpcCfgRuleCoreReportsMissingConfigHints;
var
  TempDir: string;
  Harness: TStrictLogHarness;
begin
  TempDir := GetTempFileName(GetTempDir(False), 'strictcfg');
  if FileExists(TempDir) then
    DeleteFile(TempDir);
  TempDir := TempDir + '_cfg_rule';
  ForceDirectories(TempDir);

  Harness := TStrictLogHarness.Create;
  try
    if BuildManagerValidateFpcCfgRuleCore(
      TempDir,
      True,
      'etc/fpc.cfg,lib/fpc/fpc.cfg',
      1,
      @Harness.Log
    ) then
      Fail('BuildManagerValidateFpcCfgRuleCore should fail when required cfg is missing');
    if Harness.Lines.IndexOf('FAIL: [fpc] missing fpc.cfg in cfg_relative_list') < 0 then
      Fail('BuildManagerValidateFpcCfgRuleCore should report missing config');
    if Harness.Lines.IndexOf('hint: [fpc] tried list=etc/fpc.cfg,lib/fpc/fpc.cfg') < 0 then
      Fail('BuildManagerValidateFpcCfgRuleCore should log tried-list hint');
    if Harness.Lines.IndexOf('hint: [fpc] root=' + TempDir) < 0 then
      Fail('BuildManagerValidateFpcCfgRuleCore should log sandbox root hint');
    Pass('BuildManagerValidateFpcCfgRuleCore reports missing config hints');
  finally
    Harness.Free;
    RemoveDir(TempDir);
  end;
end;

procedure TestFormatBuildPreflightLogLinesCoreHandlesSuccessAndFailure;
var
  Issues: TStringArray;
  Lines: TStringArray;
begin
  SetLength(Issues, 0);
  Lines := FormatBuildPreflightLogLinesCore(Issues, 1);
  if Length(Lines) <> 1 then
    Fail('FormatBuildPreflightLogLinesCore success should emit a single OK line');
  if Lines[0] <> '== Preflight END OK' then
    Fail('FormatBuildPreflightLogLinesCore success line mismatch: ' + Lines[0]);
  Pass('FormatBuildPreflightLogLinesCore emits success output');

  SetLength(Issues, 1);
  Issues[0] := 'make not available';
  Lines := FormatBuildPreflightLogLinesCore(Issues, 1);
  if Length(Lines) <> 2 then
    Fail('FormatBuildPreflightLogLinesCore failure should emit summary plus issues');
  if Lines[0] <> '== Preflight END FAIL issues=1' then
    Fail('FormatBuildPreflightLogLinesCore failure summary mismatch: ' + Lines[0]);
  if Lines[1] <> 'issue: make not available' then
    Fail('FormatBuildPreflightLogLinesCore failure issue line mismatch: ' + Lines[1]);
  Pass('FormatBuildPreflightLogLinesCore reuses failure formatting');
end;

procedure TestFormatBuildPreflightFailureLogLinesCoreRespectsVerbosity;
var
  Issues: TStringArray;
  Lines: TStringArray;
begin
  SetLength(Issues, 2);
  Issues[0] := 'make not available';
  Issues[1] := 'logs not writable: /tmp/logs';

  Lines := FormatBuildPreflightFailureLogLinesCore(Issues, 0);
  if Length(Lines) <> 1 then
    Fail('FormatBuildPreflightFailureLogLinesCore verbosity=0 should emit summary only');
  if Lines[0] <> '== Preflight END FAIL issues=2' then
    Fail('FormatBuildPreflightFailureLogLinesCore summary mismatch: ' + Lines[0]);
  Pass('FormatBuildPreflightFailureLogLinesCore emits summary-only output at verbosity 0');

  Lines := FormatBuildPreflightFailureLogLinesCore(Issues, 1);
  if Length(Lines) <> 3 then
    Fail('FormatBuildPreflightFailureLogLinesCore verbosity=1 should emit summary plus issues');
  if Lines[1] <> 'issue: make not available' then
    Fail('FormatBuildPreflightFailureLogLinesCore missing first issue line');
  if Lines[2] <> 'issue: logs not writable: /tmp/logs' then
    Fail('FormatBuildPreflightFailureLogLinesCore missing second issue line');
  Pass('FormatBuildPreflightFailureLogLinesCore emits verbose issue lines');
end;

var
  LBM: TBuildManager;
  LSrcRoot, LSrcTree: string;
  LOk: Boolean;
  LErr: string;
begin
  TestCollectBuildPreflightIssuesCoreCollectsExpectedIssues;
  TestBuildManagerValidateDirRuleCoreRequiresConfiguredSubdir;
  TestBuildManagerValidateDirRuleCoreReportsOptionalPresenceAtVerbose;
  TestBuildManagerValidateBinRuleCoreReportsMissingExecutableHints;
  TestBuildManagerValidateFpcCfgRuleCoreReportsMissingConfigHints;
  TestFormatBuildPreflightLogLinesCoreHandlesSuccessAndFailure;
  TestFormatBuildPreflightFailureLogLinesCoreRespectsVerbosity;

  // BuildManager expects: <sourceRoot>/fpc-<version>/...
  LSrcRoot := 'tests_tmp' + PathDelim + 'bm_make_missing' + PathDelim + 'sources' + PathDelim + 'fpc';
  LSrcTree := IncludeTrailingPathDelimiter(LSrcRoot) + 'fpc-main';
  EnsureDir(LSrcTree);

  LBM := TBuildManager.Create(LSrcRoot, 1, False);
  try
    // Force a non-existent make command: BuildCompiler should not crash.
    LBM.SetMakeCmd('fpdev-make-does-not-exist');

    try
      LOk := LBM.BuildCompiler('main');
    except
      on E: Exception do
        Fail('BuildCompiler raised exception: ' + E.ClassName + ': ' + E.Message);
    end;

    if LOk then
      Fail('BuildCompiler should fail when make is missing');

    LErr := LBM.GetLastError;
    if LErr = '' then
      Fail('GetLastError should be set when make is missing');

    Pass('BuildCompiler fails gracefully when make is missing');
  finally
    LBM.Free;
  end;
end.

