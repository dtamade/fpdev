program test_fpc_residualflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.config.interfaces,
  fpdev.fpc.installer.config,
  fpdev.fpc.installer.environmentflow,
  fpdev.fpc.metadata,
  fpdev.fpc.residualflow,
  fpdev.fpc.types,
  fpdev.types,
  test_temp_paths;

type
  TResidualProbe = class
  public
    AddedToolchainName: string;
    AddedToolchainInfo: TToolchainInfo;
    AddToolchainCalls: Integer;
    WriteVerificationCalls: Integer;
    LastVerificationVersion: string;
    LastVerificationInstallPath: string;
    LastVerificationResult: TVerificationResult;
    ScopeToReturn: TInstallScope;
    constructor Create;
    function AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
    function ResolveScope(const AVersion, AInstallPath: string): TInstallScope;
    function WriteVerificationMetadata(const AVersion, AInstallPath: string;
      const AVerifResult: TVerificationResult): Boolean;
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

procedure WriteExecutableScript(const APath: string; const ALines: array of string);
var
  Content: TStringList;
  Index: Integer;
begin
  ForceDirectories(ExtractFileDir(APath));
  Content := TStringList.Create;
  try
    for Index := Low(ALines) to High(ALines) do
      Content.Add(ALines[Index]);
    Content.SaveToFile(APath);
  finally
    Content.Free;
  end;
  {$IFDEF UNIX}
  FpChmod(APath, &755);
  {$ENDIF}
end;

constructor TResidualProbe.Create;
begin
  inherited Create;
  ScopeToReturn := isUser;
  Initialize(AddedToolchainInfo);
  Initialize(LastVerificationResult);
end;

function TResidualProbe.AddToolchain(const AName: string; const AInfo: TToolchainInfo): Boolean;
begin
  Inc(AddToolchainCalls);
  AddedToolchainName := AName;
  AddedToolchainInfo := AInfo;
  Result := True;
end;

function TResidualProbe.ResolveScope(const AVersion, AInstallPath: string): TInstallScope;
begin
  if AVersion = '' then;
  if AInstallPath = '' then;
  Result := ScopeToReturn;
end;

function TResidualProbe.WriteVerificationMetadata(const AVersion, AInstallPath: string;
  const AVerifResult: TVerificationResult): Boolean;
begin
  Inc(WriteVerificationCalls);
  LastVerificationVersion := AVersion;
  LastVerificationInstallPath := AInstallPath;
  LastVerificationResult := AVerifResult;
  Result := True;
end;

procedure TestSetupEnvironmentCoreRepairsLayoutAndRegistersToolchain;
var
  Probe: TResidualProbe;
  TempRoot: string;
  InstallDir: string;
  BinDir: string;
  LibDir: string;
  CompilerName: string;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_residualflow_setup');
  Probe := TResidualProbe.Create;
  try
    InstallDir := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
    BinDir := InstallDir + PathDelim + 'bin';
    LibDir := InstallDir + PathDelim + 'lib' + PathDelim + 'fpc' + PathDelim + '3.2.2';
    CompilerName := GetNativeCompilerName;

    ForceDirectories(BinDir);
    ForceDirectories(LibDir);
    WriteExecutableScript(BinDir + PathDelim + 'fpc', ['#!/bin/sh', 'echo "raw source fpc"']);
    WriteExecutableScript(LibDir + PathDelim + CompilerName, [
      '#!/bin/sh',
      'for arg in "$@"; do',
      '  if [ "$arg" = "-iV" ]; then',
      '    echo "3.2.2"',
      '    exit 0',
      '  fi',
      'done',
      'exit 0'
    ]);

    Check('residual flow setup environment repairs layout and registers toolchain',
      ExecuteManagedFPCSetupEnvironmentCore(
        '3.2.2',
        InstallDir,
        nil,
        nil,
        nil,
        @Probe.AddToolchain
      ),
      'expected success');
    Check('residual flow setup environment adds expected toolchain name',
      Probe.AddedToolchainName = 'fpc-3.2.2',
      Probe.AddedToolchainName);
    Check('residual flow setup environment persists install path in toolchain info',
      Probe.AddedToolchainInfo.InstallPath = InstallDir,
      Probe.AddedToolchainInfo.InstallPath);
    Check('residual flow setup environment creates managed config file',
      FileExists(BinDir + PathDelim + 'fpc.cfg'),
      'missing fpc.cfg');
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestWriteInstallMetadataCoreWritesSourceMetadata;
var
  Probe: TResidualProbe;
  TempRoot: string;
  InstallDir: string;
  Meta: TFPDevMetadata;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_residualflow_installmeta');
  Probe := TResidualProbe.Create;
  try
    Probe.ScopeToReturn := isProject;
    InstallDir := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
    ForceDirectories(InstallDir);

    Check('residual flow writes install metadata',
      ExecuteManagedFPCWriteInstallMetadataCore(
        '3.2.2',
        InstallDir,
        True,
        nil,
        @Probe.ResolveScope
      ),
      'expected success');
    Check('residual flow install metadata can be read back',
      ReadFPCMetadata(InstallDir, Meta),
      'metadata missing');
    Check('residual flow install metadata stores project scope',
      Meta.Scope = isProject,
      'scope mismatch');
    Check('residual flow install metadata stores source mode',
      Meta.SourceMode = smSource,
      'source mode mismatch');
    Check('residual flow install metadata stores version',
      Meta.Version = '3.2.2',
      Meta.Version);
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestUpdateVerificationMetadataCorePreservesOrigin;
var
  Probe: TResidualProbe;
  TempRoot: string;
  InstallDir: string;
  ExistingMeta: TFPDevMetadata;
  UpdatedMeta: TFPDevMetadata;
  VerifResult: TVerificationResult;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_residualflow_verifymeta');
  Probe := TResidualProbe.Create;
  try
    InstallDir := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
    ForceDirectories(InstallDir);

    Initialize(ExistingMeta);
    ExistingMeta.Version := '3.2.2';
    ExistingMeta.Scope := isUser;
    ExistingMeta.Channel := 'stable';
    ExistingMeta.Prefix := ExpandFileName(InstallDir);
    ExistingMeta.Origin.RepoURL := 'https://gitlab.example/fpc.git';
    ExistingMeta.Origin.BuiltFromSource := True;
    Check('residual flow prewrites existing metadata',
      WriteFPCMetadata(InstallDir, ExistingMeta),
      'failed to prewrite metadata');

    Initialize(VerifResult);
    VerifResult.Verified := True;
    VerifResult.DetectedVersion := '3.2.2';
    VerifResult.SmokeTestPassed := True;

    Check('residual flow updates verification metadata',
      ExecuteManagedFPCUpdateVerificationMetadataCore(
        '3.2.2',
        InstallDir,
        VerifResult,
        nil,
        @Probe.ResolveScope
      ),
      'expected success');
    Check('residual flow updated metadata is readable',
      ReadFPCMetadata(InstallDir, UpdatedMeta),
      'metadata missing');
    Check('residual flow preserves origin repo url',
      UpdatedMeta.Origin.RepoURL = 'https://gitlab.example/fpc.git',
      UpdatedMeta.Origin.RepoURL);
    Check('residual flow preserves built-from-source flag',
      UpdatedMeta.Origin.BuiltFromSource,
      'expected built_from_source');
    Check('residual flow writes verification ok flag',
      UpdatedMeta.Verify.OK,
      'verify.ok was false');
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestRefreshVerificationMetadataCoreDelegatesToWriter;
var
  Probe: TResidualProbe;
  TempRoot: string;
  InstallDir: string;
begin
  TempRoot := CreateUniqueTempDir('test_fpc_residualflow_refresh');
  Probe := TResidualProbe.Create;
  try
    InstallDir := TempRoot + PathDelim + 'toolchains' + PathDelim + 'fpc' + PathDelim + '3.2.2';
    ForceDirectories(InstallDir);

    Check('residual flow refresh delegates to verification metadata writer',
      not ExecuteManagedFPCRefreshVerificationMetadataCore(
        '3.2.2',
        InstallDir,
        nil,
        @Probe.WriteVerificationMetadata
      ),
      'expected failed verification for missing executable');
    Check('residual flow refresh still calls writer callback',
      Probe.WriteVerificationCalls = 1,
      'calls=' + IntToStr(Probe.WriteVerificationCalls));
    Check('residual flow refresh forwards version',
      Probe.LastVerificationVersion = '3.2.2',
      Probe.LastVerificationVersion);
    Check('residual flow refresh forwards install path',
      Probe.LastVerificationInstallPath = InstallDir,
      Probe.LastVerificationInstallPath);
  finally
    Probe.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestSetupEnvironmentCoreRepairsLayoutAndRegistersToolchain;
  TestWriteInstallMetadataCoreWritesSourceMetadata;
  TestUpdateVerificationMetadataCorePreservesOrigin;
  TestRefreshVerificationMetadataCoreDelegatesToWriter;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
