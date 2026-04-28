program test_fpc_sourcebuildflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.fpc.sourcebuildflow,
  test_temp_paths;

type
  TBuildProbe = class
  public
    ValidSourceResult: Boolean;
    BuildSourceCalls: Integer;
    ManagedStepCalls: Integer;
    LastBuildSourcePath: string;
    LastManagedVersion: string;
    function IsValidSourceDirectory(const APath: string): Boolean;
    function BuildSource(const ASourcePath: string): Boolean;
    function ManagedStep(const AVersion: string): Boolean;
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

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

function TBuildProbe.IsValidSourceDirectory(const APath: string): Boolean;
begin
  if APath = '' then;
  Result := ValidSourceResult;
end;

function TBuildProbe.BuildSource(const ASourcePath: string): Boolean;
begin
  Inc(BuildSourceCalls);
  LastBuildSourcePath := ASourcePath;
  Result := True;
end;

function TBuildProbe.ManagedStep(const AVersion: string): Boolean;
begin
  Inc(ManagedStepCalls);
  LastManagedVersion := AVersion;
  Result := True;
end;

procedure TestInvalidSourceDirRejected;
var
  Probe: TBuildProbe;
  OK: Boolean;
begin
  Probe := TBuildProbe.Create;
  try
    Probe.ValidSourceResult := False;
    OK := ExecuteFPCSourceBuildCore(
      '3.2.2',
      '/tmp/fpdev-fpc-sourcebuildflow-missing',
      @Probe.IsValidSourceDirectory,
      @Probe.BuildSource
    );

    Check('sourcebuildflow rejects invalid source dir', not OK, 'expected failure');
    Check('sourcebuildflow does not execute build command for invalid dir',
      Probe.BuildSourceCalls = 0, 'calls=' + IntToStr(Probe.BuildSourceCalls));
  finally
    Probe.Free;
  end;
end;

procedure TestManagedCallbacksInvoked;
var
  Probe: TBuildProbe;
  OK: Boolean;
begin
  Probe := TBuildProbe.Create;
  try
    Probe.ValidSourceResult := True;
    OK := ExecuteFPCSourceManagedBuildStepCore(
      '3.2.2',
      '/tmp/fpdev-fpc-sourcebuildflow-valid',
      @Probe.IsValidSourceDirectory,
      @Probe.ManagedStep
    );

    Check('sourcebuildflow managed build step succeeds', OK, 'expected success');
    Check('sourcebuildflow managed build step invokes callback',
      Probe.ManagedStepCalls = 1, 'calls=' + IntToStr(Probe.ManagedStepCalls));
    Check('sourcebuildflow managed build step forwards version',
      Probe.LastManagedVersion = '3.2.2', Probe.LastManagedVersion);
  finally
    Probe.Free;
  end;
end;

procedure TestCacheMetadataMismatchRejected;
var
  TempRoot: string;
  SourcePath: string;
  CachePath: string;
  Probe: TBuildProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcebuildflow_cache_mismatch');
  Probe := TBuildProbe.Create;
  try
    Probe.ValidSourceResult := True;
    SourcePath := TempRoot + PathDelim + 'fpc-3.2.2';
    ForceDirectories(SourcePath + PathDelim + 'compiler');
    ForceDirectories(SourcePath + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('binary');
      SaveToFile(SourcePath + PathDelim + 'compiler' + PathDelim + 'ppcx64');
    finally
      Free;
    end;
    ForceDirectories(TempRoot + PathDelim + 'cache');
    CachePath := TempRoot + PathDelim + 'cache' + PathDelim + 'fpc-3.2.2.cache';
    with TStringList.Create do
    try
      Add('version=3.0.4');
      SaveToFile(CachePath);
    finally
      Free;
    end;

    OK := ExecuteFPCSourceUseCachedBuildCore(
      TempRoot,
      '3.2.2',
      SourcePath,
      @Probe.IsValidSourceDirectory
    );

    Check('sourcebuildflow rejects cache metadata mismatch', not OK, 'expected failure');
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

procedure TestCacheArtifactsAccepted;
var
  TempRoot: string;
  SourcePath: string;
  CachePath: string;
  Probe: TBuildProbe;
  OK: Boolean;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_sourcebuildflow_cache_valid');
  Probe := TBuildProbe.Create;
  try
    Probe.ValidSourceResult := True;
    SourcePath := TempRoot + PathDelim + 'fpc-3.2.2';
    ForceDirectories(SourcePath + PathDelim + 'compiler');
    ForceDirectories(SourcePath + PathDelim + 'rtl');
    with TStringList.Create do
    try
      Add('binary');
      SaveToFile(SourcePath + PathDelim + 'compiler' + PathDelim + 'ppcx64');
    finally
      Free;
    end;
    ForceDirectories(TempRoot + PathDelim + 'cache');
    CachePath := TempRoot + PathDelim + 'cache' + PathDelim + 'fpc-3.2.2.cache';
    with TStringList.Create do
    try
      Add('version=3.2.2');
      Add('built_at=2026-04-14 10:00:00');
      SaveToFile(CachePath);
    finally
      Free;
    end;

    OK := ExecuteFPCSourceUseCachedBuildCore(
      TempRoot,
      '3.2.2',
      SourcePath,
      @Probe.IsValidSourceDirectory
    );

    Check('sourcebuildflow accepts cache when metadata and artifacts match',
      OK, 'expected success');
    Check('sourcebuildflow cache availability helper sees marker',
      ExecuteFPCSourceCacheAvailableCore(TempRoot, '3.2.2'),
      'expected cache marker');
  finally
    CleanupTempDir(TempRoot);
    Probe.Free;
  end;
end;

begin
  TestInvalidSourceDirRejected;
  TestManagedCallbacksInvoked;
  TestCacheMetadataMismatchRejected;
  TestCacheArtifactsAccepted;

  if FailCount > 0 then
    Halt(1);
end.
