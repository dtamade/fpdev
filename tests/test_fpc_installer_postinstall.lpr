program test_fpc_installer_postinstall;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.build.cache,
  fpdev.fpc.installer.config, fpdev.fpc.installer.postinstall,
  test_temp_paths;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  TestRoot: string;

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

type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function Contains(const S: string): Boolean;
    function Text: string;
  end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

type
  TSetupProbe = class
  public
    CalledCount: Integer;
    LastVersion: string;
    LastInstallPath: string;
    NextResult: Boolean;
    function Run(const AVersion, AInstallPath: string): Boolean;
  end;

function TSetupProbe.Run(const AVersion, AInstallPath: string): Boolean;
begin
  Inc(CalledCount);
  LastVersion := AVersion;
  LastInstallPath := AInstallPath;
  Result := NextResult;
end;

procedure WriteTextFile(const AFileName, AContent: string);
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create(AContent);
  try
    Stream.SaveToFile(AFileName);
  finally
    Stream.Free;
  end;
end;

procedure PrepareInstallTree(const AInstallDir, AVersion: string; AWithBin: Boolean);
var
  CompilerName: string;
  BinDir: string;
  LibDir: string;
begin
  ForceDirectories(AInstallDir);
  if AWithBin then
  begin
    BinDir := AInstallDir + PathDelim + 'bin';
    ForceDirectories(BinDir);
    WriteTextFile(BinDir + PathDelim + 'fpc', '#!/bin/sh' + LineEnding + 'echo fake');
  end;

  LibDir := AInstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion;
  ForceDirectories(LibDir);

  CompilerName := GetNativeCompilerName;
  WriteTextFile(LibDir + PathDelim + CompilerName, 'fake compiler');
  WriteTextFile(AInstallDir + PathDelim + 'README.txt', 'fixture');
end;

procedure PrepareBrokenInstallTreeMissingDriver(const AInstallDir, AVersion: string);
var
  CompilerName: string;
  BinDir: string;
  LibDir: string;
begin
  ForceDirectories(AInstallDir);

  BinDir := AInstallDir + PathDelim + 'bin';
  ForceDirectories(BinDir);

  LibDir := AInstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + AVersion;
  ForceDirectories(LibDir);

  CompilerName := GetNativeCompilerName;
  WriteTextFile(LibDir + PathDelim + CompilerName, 'fake compiler');
  WriteTextFile(AInstallDir + PathDelim + 'README.txt', 'broken fixture');
end;

procedure TestExecutePostInstallGeneratesConfigAndCaches;
var
  InstallDir: string;
  CacheDir: string;
  Cache: TBuildCache;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  ConfigGen: TFPCConfigGenerator;
  Probe: TSetupProbe;
  Actions: TFPCBinaryPostInstallActions;
begin
  InstallDir := CreateUniqueTempDir('test_fpc_postinstall_ok');
  CacheDir := CreateUniqueTempDir('test_fpc_postinstall_cache');
  PrepareInstallTree(InstallDir, '3.2.2', True);

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ConfigGen := TFPCConfigGenerator.Create(OutBuf);
  Probe := TSetupProbe.Create;
  Cache := TBuildCache.Create(CacheDir);
  try
    Probe.NextResult := True;
    Actions := ExecuteFPCBinaryPostInstall('3.2.2', InstallDir, OutBuf, ErrBuf,
      ConfigGen, @Probe.Run, Cache, False);

    Check('config generation flagged', Actions.ConfigGenerated,
      'expected config generation to run');
    Check('environment setup flagged', Actions.EnvironmentConfigured,
      'expected environment setup to succeed');
    Check('cache save flagged', Actions.CacheSaved,
      'expected cache save to succeed');
    Check('setup callback called once', Probe.CalledCount = 1,
      'called count=' + IntToStr(Probe.CalledCount));
    Check('setup callback gets version', Probe.LastVersion = '3.2.2',
      'version=' + Probe.LastVersion);
    Check('setup callback gets install path', Probe.LastInstallPath = InstallDir,
      'path=' + Probe.LastInstallPath);
    Check('fpc.cfg created', FileExists(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg'),
      'fpc.cfg missing');
    {$IFDEF LINUX}
    Check('wrapper backup created', FileExists(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.orig'),
      'fpc.orig missing');
    {$ENDIF}
    Check('cache has artifacts', Cache.HasArtifacts('3.2.2'),
      'cache should contain saved artifacts');
    Check('output includes completion summary', OutBuf.Contains('Installation completed!'),
      'summary missing');
    Check('output includes cache success', OutBuf.Contains('cached successfully'),
      'cache success missing');
  finally
    Cache.Free;
    Probe.Free;
    ConfigGen.Free;
    CleanupTempDir(CacheDir);
    CleanupTempDir(InstallDir);
  end;
end;

procedure TestExecutePostInstallSkipsConfigWhenBinMissingAndRespectsNoCache;
var
  InstallDir: string;
  CacheDir: string;
  Cache: TBuildCache;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  ConfigGen: TFPCConfigGenerator;
  Probe: TSetupProbe;
  Actions: TFPCBinaryPostInstallActions;
begin
  InstallDir := CreateUniqueTempDir('test_fpc_postinstall_nobin');
  CacheDir := CreateUniqueTempDir('test_fpc_postinstall_nocache');
  PrepareInstallTree(InstallDir, '3.2.3', False);

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ConfigGen := TFPCConfigGenerator.Create(OutBuf);
  Probe := TSetupProbe.Create;
  Cache := TBuildCache.Create(CacheDir);
  try
    Probe.NextResult := True;
    Actions := ExecuteFPCBinaryPostInstall('3.2.3', InstallDir, OutBuf, ErrBuf,
      ConfigGen, @Probe.Run, Cache, True);

    Check('config generation skipped without bin', not Actions.ConfigGenerated,
      'config generation should be skipped');
    Check('environment setup skipped without bin', Probe.CalledCount = 0,
      'called count=' + IntToStr(Probe.CalledCount));
    Check('no-cache keeps cache attempt disabled when layout invalid', not Actions.CacheAttempted,
      'cache attempt should be disabled');
    Check('no-cache leaves cache empty', not Cache.HasArtifacts('3.2.3'),
      'cache should remain empty');
    Check('no fpc.cfg created when bin missing',
      not FileExists(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg'),
      'unexpected fpc.cfg found');
    Check('layout warning emitted when bin missing',
      ErrBuf.Contains('Managed install layout incomplete'),
      'expected managed layout warning');
    Check('completion summary omitted when layout invalid',
      not OutBuf.Contains('Installation completed!'),
      'unexpected completion summary');
    Check('output omits cache save section', not OutBuf.Contains('[CACHE] Saving installation to cache'),
      'cache section should be absent');
  finally
    Cache.Free;
    Probe.Free;
    ConfigGen.Free;
    CleanupTempDir(CacheDir);
    CleanupTempDir(InstallDir);
  end;
end;

procedure TestExecutePostInstallSkipsEnvironmentWhenManagedLayoutRepairFails;
var
  InstallDir: string;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  ConfigGen: TFPCConfigGenerator;
  Probe: TSetupProbe;
  Actions: TFPCBinaryPostInstallActions;
begin
  InstallDir := CreateUniqueTempDir('test_fpc_postinstall_broken_driver');
  PrepareBrokenInstallTreeMissingDriver(InstallDir, '3.2.5');

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ConfigGen := TFPCConfigGenerator.Create(OutBuf);
  Probe := TSetupProbe.Create;
  try
    Probe.NextResult := True;
    Actions := ExecuteFPCBinaryPostInstall('3.2.5', InstallDir, OutBuf, ErrBuf,
      ConfigGen, @Probe.Run, nil, False);

    Check('broken layout does not report config generated', not Actions.ConfigGenerated,
      'config generation should fail for broken layout');
    Check('broken layout skips environment setup', Probe.CalledCount = 0,
      'called count=' + IntToStr(Probe.CalledCount));
    Check('broken layout does not mark environment configured',
      not Actions.EnvironmentConfigured, 'environment should stay false');
    Check('broken layout does not create fpc.cfg',
      not FileExists(InstallDir + PathDelim + 'bin' + PathDelim + 'fpc.cfg'),
      'unexpected fpc.cfg found');
    Check('broken layout warns on stderr',
      ErrBuf.Contains('Managed install layout incomplete'),
      'expected managed layout warning');
    Check('broken layout omits completion summary',
      not OutBuf.Contains('Installation completed!'),
      'unexpected completion summary');
  finally
    Probe.Free;
    ConfigGen.Free;
    CleanupTempDir(InstallDir);
  end;
end;

procedure TestExecutePostInstallWarnsWhenEnvironmentSetupFails;
var
  InstallDir: string;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  ConfigGen: TFPCConfigGenerator;
  Probe: TSetupProbe;
  Actions: TFPCBinaryPostInstallActions;
begin
  InstallDir := CreateUniqueTempDir('test_fpc_postinstall_warn');
  PrepareInstallTree(InstallDir, '3.2.4', True);

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  ConfigGen := TFPCConfigGenerator.Create(OutBuf);
  Probe := TSetupProbe.Create;
  try
    Probe.NextResult := False;
    Actions := ExecuteFPCBinaryPostInstall('3.2.4', InstallDir, OutBuf, ErrBuf,
      ConfigGen, @Probe.Run, nil, False);

    Check('environment failure recorded', not Actions.EnvironmentConfigured,
      'environment should be marked incomplete');
    Check('warning goes to stderr buffer', ErrBuf.Contains('Environment setup incomplete'),
      'warning missing');
    Check('completion summary still printed', OutBuf.Contains('Installation completed!'),
      'completion summary missing');
  finally
    Probe.Free;
    ConfigGen.Free;
    CleanupTempDir(InstallDir);
  end;
end;

begin
  WriteLn('=== FPC Installer Post-Install Tests ===');
  TestRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));

  TestExecutePostInstallGeneratesConfigAndCaches;
  TestExecutePostInstallSkipsConfigWhenBinMissingAndRespectsNoCache;
  TestExecutePostInstallSkipsEnvironmentWhenManagedLayoutRepairFails;
  TestExecutePostInstallWarnsWhenEnvironmentSetupFails;

  WriteLn;
  WriteLn('Total: ', PassCount + FailCount);
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
