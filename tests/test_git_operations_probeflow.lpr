program test_git_operations_probeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, fpdev.git.types, fpdev.utils.process,
  fpdev.git.operations.probeflow;

type
  TGitProbeHarness = class
  private
    FCliResults: array of TProcessResult;
    FCliIndex: Integer;
  public
    DirectoryExistsCalls: Integer;
    Libgit2RepoCalls: Integer;
    Libgit2VersionCalls: Integer;
    CliCalls: Integer;
    LastDirectoryPath: string;
    LastCliCommand: string;
    DirectoryExistsResult: Boolean;
    Libgit2RepoResult: Boolean;
    Libgit2VersionResult: Boolean;
    Libgit2VersionValue: string;
    constructor Create;
    procedure AddCliResult(const AResult: TProcessResult);
    function DirectoryExistsProbe(const APath: string): Boolean;
    function IsRepositoryWithLibgit2(const APath: string): Boolean;
    function TryGetVersionWithLibgit2(out AVersion: string): Boolean;
    function ExecuteCli(const AParams: array of string;
      const AWorkDir: string): TProcessResult;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

procedure Check(const AName: string; ACondition: Boolean;
  const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function NewProcessResult(const ASuccess: Boolean; const AExitCode: Integer;
  const AStdOut: string; const AStdErr: string = '';
  const AErrorMessage: string = ''): TProcessResult;
begin
  Result.Success := ASuccess;
  Result.ExitCode := AExitCode;
  Result.StdOut := AStdOut;
  Result.StdErr := AStdErr;
  Result.ErrorMessage := AErrorMessage;
end;

function JoinParams(const AParams: array of string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AParams) do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + AParams[i];
  end;
end;

constructor TGitProbeHarness.Create;
begin
  inherited Create;
  FCliIndex := 0;
end;

procedure TGitProbeHarness.AddCliResult(const AResult: TProcessResult);
var
  L: Integer;
begin
  L := Length(FCliResults);
  SetLength(FCliResults, L + 1);
  FCliResults[L] := AResult;
end;

function TGitProbeHarness.DirectoryExistsProbe(const APath: string): Boolean;
begin
  Inc(DirectoryExistsCalls);
  LastDirectoryPath := APath;
  Result := DirectoryExistsResult;
end;

function TGitProbeHarness.IsRepositoryWithLibgit2(const APath: string): Boolean;
begin
  Inc(Libgit2RepoCalls);
  if APath = '' then;
  Result := Libgit2RepoResult;
end;

function TGitProbeHarness.TryGetVersionWithLibgit2(out AVersion: string): Boolean;
begin
  Inc(Libgit2VersionCalls);
  AVersion := Libgit2VersionValue;
  Result := Libgit2VersionResult;
end;

function TGitProbeHarness.ExecuteCli(const AParams: array of string;
  const AWorkDir: string): TProcessResult;
begin
  Inc(CliCalls);
  LastCliCommand := JoinParams(AParams) + ' [cwd=' + AWorkDir + ']';
  if FCliIndex < Length(FCliResults) then
  begin
    Result := FCliResults[FCliIndex];
    Inc(FCliIndex);
  end
  else
    Result := NewProcessResult(False, 1, '', '', 'missing cli result');
end;

procedure TestIsRepositoryUsesGitDirFastPathBeforeLibgit2;
var
  Harness: TGitProbeHarness;
  OK: Boolean;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.DirectoryExistsResult := True;
    Harness.Libgit2RepoResult := False;
    OK := ExecuteGitIsRepositorySurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      @Harness.DirectoryExistsProbe,
      @Harness.IsRepositoryWithLibgit2
    );
    Check('probeflow IsRepository returns true from git dir fast path', OK, 'expected true');
    Check('probeflow IsRepository skips libgit2 when git dir exists', Harness.Libgit2RepoCalls = 0,
      'libgit2 repo calls=' + IntToStr(Harness.Libgit2RepoCalls));
    Check('probeflow IsRepository checks .git suffix',
      Harness.LastDirectoryPath = '/tmp/repo/.git',
      Harness.LastDirectoryPath);
  finally
    Harness.Free;
  end;
end;

procedure TestIsRepositoryFallsBackToLibgit2WhenGitDirMissing;
var
  Harness: TGitProbeHarness;
  OK: Boolean;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.DirectoryExistsResult := False;
    Harness.Libgit2RepoResult := True;
    OK := ExecuteGitIsRepositorySurfaceCore(
      '/tmp/repo',
      gbLibgit2,
      @Harness.DirectoryExistsProbe,
      @Harness.IsRepositoryWithLibgit2
    );
    Check('probeflow IsRepository falls back to libgit2', OK, 'expected true');
    Check('probeflow IsRepository calls libgit2 once after missing git dir',
      Harness.Libgit2RepoCalls = 1,
      'libgit2 repo calls=' + IntToStr(Harness.Libgit2RepoCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestIsRepositorySkipsLibgit2WhenBackendNone;
var
  Harness: TGitProbeHarness;
  OK: Boolean;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.DirectoryExistsResult := False;
    Harness.Libgit2RepoResult := True;
    OK := ExecuteGitIsRepositorySurfaceCore(
      '/tmp/repo',
      gbNone,
      @Harness.DirectoryExistsProbe,
      @Harness.IsRepositoryWithLibgit2
    );
    Check('probeflow IsRepository returns false without git dir or libgit2 backend',
      not OK, 'expected false');
    Check('probeflow IsRepository skips libgit2 when backend is none',
      Harness.Libgit2RepoCalls = 0,
      'libgit2 repo calls=' + IntToStr(Harness.Libgit2RepoCalls));
  finally
    Harness.Free;
  end;
end;

procedure TestGetVersionUsesLibgit2First;
var
  Harness: TGitProbeHarness;
  Err: string;
  VersionText: string;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.Libgit2VersionResult := True;
    Harness.Libgit2VersionValue := 'libgit2 1.9.0';
    Err := '';
    VersionText := ExecuteGitVersionSurfaceCore(
      gbLibgit2,
      True,
      @Harness.TryGetVersionWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('probeflow GetVersion returns libgit2 version', VersionText = 'libgit2 1.9.0',
      VersionText);
    Check('probeflow GetVersion skips CLI when libgit2 version exists', Harness.CliCalls = 0,
      'cli calls=' + IntToStr(Harness.CliCalls));
    Check('probeflow GetVersion keeps error empty on libgit2 success', Err = '', Err);
  finally
    Harness.Free;
  end;
end;

procedure TestGetVersionFallsBackToCli;
var
  Harness: TGitProbeHarness;
  Err: string;
  VersionText: string;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.Libgit2VersionResult := False;
    Harness.AddCliResult(NewProcessResult(True, 0, 'git version 2.45.1'#10, '', ''));
    Err := '';
    VersionText := ExecuteGitVersionSurfaceCore(
      gbLibgit2,
      True,
      @Harness.TryGetVersionWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('probeflow GetVersion falls back to CLI output',
      VersionText = 'git version 2.45.1', VersionText);
    Check('probeflow GetVersion uses git --version CLI command',
      Harness.LastCliCommand = '--version [cwd=]',
      Harness.LastCliCommand);
    Check('probeflow GetVersion keeps error empty on CLI success', Err = '', Err);
  finally
    Harness.Free;
  end;
end;

procedure TestGetVersionReportsCliFailure;
var
  Harness: TGitProbeHarness;
  Err: string;
  VersionText: string;
begin
  Harness := TGitProbeHarness.Create;
  try
    Harness.AddCliResult(NewProcessResult(False, 7, '', 'git missing', ''));
    Err := '';
    VersionText := ExecuteGitVersionSurfaceCore(
      gbNone,
      True,
      @Harness.TryGetVersionWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('probeflow GetVersion returns empty string on CLI failure', VersionText = '',
      VersionText);
    Check('probeflow GetVersion reports CLI stderr', Err = 'git missing', Err);
  finally
    Harness.Free;
  end;
end;

procedure TestGetVersionReportsMissingCommandLineGit;
var
  Harness: TGitProbeHarness;
  Err: string;
  VersionText: string;
begin
  Harness := TGitProbeHarness.Create;
  try
    Err := '';
    VersionText := ExecuteGitVersionSurfaceCore(
      gbNone,
      False,
      @Harness.TryGetVersionWithLibgit2,
      @Harness.ExecuteCli,
      Err
    );
    Check('probeflow GetVersion returns empty string when CLI missing',
      VersionText = '', VersionText);
    Check('probeflow GetVersion reports missing CLI',
      Err = 'No command-line git available', Err);
  finally
    Harness.Free;
  end;
end;

begin
  TestIsRepositoryUsesGitDirFastPathBeforeLibgit2;
  TestIsRepositoryFallsBackToLibgit2WhenGitDirMissing;
  TestIsRepositorySkipsLibgit2WhenBackendNone;
  TestGetVersionUsesLibgit2First;
  TestGetVersionFallsBackToCli;
  TestGetVersionReportsCliFailure;
  TestGetVersionReportsMissingCommandLineGit;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
