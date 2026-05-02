program test_toolchain_reportflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.toolchain.reportflow,
  fpdev.utils,
  test_temp_paths
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF}
  ;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  LastProbeCommand: string = '';
  LastProbeArg0: string = '';

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

procedure WriteTextFile(const APath, AContent: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  Lines := TStringList.Create;
  try
    Lines.Text := AContent;
    Lines.SaveToFile(APath);
  finally
    Lines.Free;
  end;
end;

procedure CreateToolchainRepoFixture(
  const APrefix: string;
  out ARepoRoot, ALazarusRoot: string
);
begin
  ARepoRoot := CreateUniqueTempDir(APrefix);
  WriteTextFile(ARepoRoot + PathDelim + 'fpdev.lpi', '<CONFIG/>');
  ForceDirectories(ARepoRoot + PathDelim + 'bin');
  ForceDirectories(ARepoRoot + PathDelim + 'lib');

  ALazarusRoot := CreateUniqueTempDir(APrefix + '-lazarus');
  ForceDirectories(ALazarusRoot + PathDelim + 'lcl');
end;

procedure CleanupToolchainRepoFixture(
  const ARepoRoot, ALazarusRoot: string
);
begin
  CleanupTempDir(ARepoRoot);
  CleanupTempDir(ALazarusRoot);
end;

function FakeRunAndCaptureFirstLine(
  const ACmd: string;
  const AArgs: array of string;
  out ALine: string
): Boolean;
begin
  LastProbeCommand := ACmd;
  if Length(AArgs) > 0 then
    LastProbeArg0 := AArgs[0]
  else
    LastProbeArg0 := '';

  ALine := '';
  if ACmd = 'fpc' then
  begin
    ALine := '3.2.2';
    Exit(True);
  end;
  if ACmd = 'make' then
  begin
    ALine := 'GNU Make 4.4';
    Exit(True);
  end;

  Result := False;
end;

function FakeResolvePath(const ACmd: string): string;
begin
  if ACmd = 'fpc' then
    Exit('/usr/bin/fpc');
  if ACmd = 'make' then
    Exit('/usr/bin/make');
  if ACmd = 'lazbuild' then
    Exit('/usr/bin/lazbuild');
  if ACmd = 'git' then
    Exit('/usr/bin/git');
  if ACmd = 'openssl' then
    Exit('/usr/bin/openssl');
  Result := '';
end;

procedure TestSplitPathHead;
var
  Parts: TToolchainStringArray;
begin
  Parts := SplitToolchainPathHeadCore('/a:/b:/c:/d', 2);
  Check('toolchain reportflow splits PATH head with max limit',
    (Length(Parts) = 2) and (Parts[0] = '/a') and (Parts[1] = '/b'),
    IntToStr(Length(Parts)));
end;

procedure TestGetToolchainFPCVersionCore;
var
  FPCVersion: string;
  OK: Boolean;
begin
  LastProbeCommand := '';
  LastProbeArg0 := '';
  OK := GetToolchainFPCVersionCore(@FakeRunAndCaptureFirstLine, FPCVersion);
  Check('toolchain reportflow gets FPC version via probe callback',
    OK and (FPCVersion = '3.2.2'),
    FPCVersion);
  Check('toolchain reportflow uses fpc -iV probe',
    (LastProbeCommand = 'fpc') and (LastProbeArg0 = '-iV'),
    LastProbeCommand + ' ' + LastProbeArg0);
end;

procedure TestReportJSONWithWritableRepoOutputs;
var
  RepoRoot: string;
  LazarusRoot: string;
  JSONStr: string;
begin
  CreateToolchainRepoFixture('test_toolchain_reportflow_ok', RepoRoot, LazarusRoot);
  try
    Check('toolchain reportflow fixture stays under shared temp',
      PathUsesSystemTempRoot(RepoRoot) and PathUsesSystemTempRoot(LazarusRoot),
      RepoRoot + ' | ' + LazarusRoot);

    JSONStr := BuildToolchainReportJSONCore(
      'Unix-like',
      'x86_64',
      RepoRoot + PathSeparator + '/usr/bin',
      RepoRoot,
      '/nowhere',
      LazarusRoot,
      @FakeRunAndCaptureFirstLine,
      @FakeResolvePath
    );

    Check('toolchain reportflow includes overridden PATH head',
      Pos('"pathHead":["' + JsonEscape(RepoRoot) + '"', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow includes writable repo bin output',
      Pos('"name":"repo_bin_writable","found":true', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow includes writable repo lib output',
      Pos('"name":"repo_lib_writable","found":true', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow honors lazarus root override',
      Pos('"name":"lazarus_root","found":true', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow stays OK when required probes succeed',
      Pos('"level":"OK"', JSONStr) > 0,
      JSONStr);
  finally
    CleanupToolchainRepoFixture(RepoRoot, LazarusRoot);
  end;
end;

procedure TestReportJSONFailsWhenRepoLibReadOnly;
var
  RepoRoot: string;
  LazarusRoot: string;
  RepoLib: string;
  JSONStr: string;
begin
  {$IFNDEF UNIX}
  Check('toolchain reportflow read-only repo lib test skipped on non-UNIX', True);
  Exit;
  {$ENDIF}

  CreateToolchainRepoFixture('test_toolchain_reportflow_fail', RepoRoot, LazarusRoot);
  RepoLib := RepoRoot + PathDelim + 'lib';
  try
    if FpChmod(RepoLib, &555) <> 0 then
      raise Exception.Create('Failed to chmod repo lib to read-only');

    JSONStr := BuildToolchainReportJSONCore(
      'Unix-like',
      'x86_64',
      '/tmp:/usr/bin',
      RepoRoot,
      '/nowhere',
      LazarusRoot,
      @FakeRunAndCaptureFirstLine,
      @FakeResolvePath
    );

    Check('toolchain reportflow marks repo lib output not writable',
      Pos('"name":"repo_lib_writable","found":false', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow escalates to FAIL for required repo lib miss',
      Pos('"level":"FAIL"', JSONStr) > 0,
      JSONStr);
    Check('toolchain reportflow reports repo lib write failure issue',
      Pos('repo build output not writable: lib', JSONStr) > 0,
      JSONStr);
  finally
    {$IFDEF UNIX}
    if DirectoryExists(RepoLib) then
      FpChmod(RepoLib, &755);
    {$ENDIF}
    CleanupToolchainRepoFixture(RepoRoot, LazarusRoot);
  end;
end;

begin
  TestSplitPathHead;
  TestGetToolchainFPCVersionCore;
  TestReportJSONWithWritableRepoOutputs;
  TestReportJSONFailsWhenRepoLibReadOnly;

  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
