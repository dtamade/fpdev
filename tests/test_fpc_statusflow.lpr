program test_fpc_statusflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.config.interfaces,
  fpdev.fpc.installversionflow,
  fpdev.fpc.metadata,
  fpdev.fpc.statusflow,
  fpdev.fpc.types,
  fpdev.types,
  test_temp_paths;

type
  TStatusFlowCallbacks = class
  public
    ConfiguredInstallPath: string;
    Metadata: TFPDevMetadata;
    HasMetadata: Boolean;
    InferredScope: TFPCStatusScope;
    LastLookupVersion: string;
    LastReadInstallPath: string;
    LastInferVersion: string;
    LastInferInstallPath: string;

    function LookupToolchainInfo(const AVersion: string; out AInfo: TToolchainInfo): Boolean;
    function ReadMetadata(const AInstallPath: string; out AMeta: TFPDevMetadata): Boolean;
    function InferStatusScope(const AVersion, AInstallPath: string): TFPCStatusScope;
  end;

var
  TestRootDir: string;
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

procedure InitTestEnvironment;
begin
  TestRootDir := CreateUniqueTempDir('test_fpc_statusflow');
end;

procedure CleanupTestEnvironment;
begin
  if TestRootDir <> '' then
    CleanupTempDir(TestRootDir);
end;

procedure CreateMockFPCExecutable(const AInstallPath: string);
var
  BinDir: string;
  ExePath: string;
  Lines: TStringList;
begin
  BinDir := AInstallPath + PathDelim + 'bin';
  ForceDirectories(BinDir);
  {$IFDEF MSWINDOWS}
  ExePath := BinDir + PathDelim + 'fpc.exe';
  {$ELSE}
  ExePath := BinDir + PathDelim + 'fpc';
  {$ENDIF}

  Lines := TStringList.Create;
  try
    Lines.Add('mock fpc');
    Lines.SaveToFile(ExePath);
  finally
    Lines.Free;
  end;
end;

function TStatusFlowCallbacks.LookupToolchainInfo(
  const AVersion: string;
  out AInfo: TToolchainInfo
): Boolean;
begin
  LastLookupVersion := AVersion;
  AInfo := Default(TToolchainInfo);
  Result := Trim(ConfiguredInstallPath) <> '';
  if Result then
    AInfo.InstallPath := ConfiguredInstallPath;
end;

function TStatusFlowCallbacks.ReadMetadata(
  const AInstallPath: string;
  out AMeta: TFPDevMetadata
): Boolean;
begin
  LastReadInstallPath := AInstallPath;
  AMeta := Metadata;
  Result := HasMetadata;
end;

function TStatusFlowCallbacks.InferStatusScope(
  const AVersion, AInstallPath: string
): TFPCStatusScope;
begin
  LastInferVersion := AVersion;
  LastInferInstallPath := AInstallPath;
  Result := InferredScope;
end;

procedure TestBuildManagedStatusWithoutConfiguredDefault;
var
  Callbacks: TStatusFlowCallbacks;
  Status: TFPCStatusInfo;
  ErrorText: string;
begin
  Callbacks := TStatusFlowCallbacks.Create;
  try
    Check(
      'statusflow empty version succeeds',
      BuildManagedFPCStatusCore(
        '',
        '',
        @Callbacks.LookupToolchainInfo,
        @Callbacks.ReadMetadata,
        @Callbacks.InferStatusScope,
        Status,
        ErrorText
      ),
      'BuildManagedFPCStatusCore returned false'
    );
    Check('statusflow empty version keeps configured default empty',
      Status.ConfiguredDefault = '',
      'configured=' + Status.ConfiguredDefault);
    Check('statusflow empty version keeps active scope none',
      Status.ActiveScope = fssNone,
      'scope mismatch');
    Check('statusflow empty version keeps verify unknown',
      Status.VerifyStatus = fvsUnknown,
      'verify mismatch');
    Check('statusflow empty version keeps source mode unknown',
      not Status.HasSourceMode,
      'has source mode should be false');
  finally
    Callbacks.Free;
  end;
end;

procedure TestBuildManagedStatusPrefersConfiguredInstallPath;
var
  Callbacks: TStatusFlowCallbacks;
  Status: TFPCStatusInfo;
  ErrorText: string;
  DefaultInstallPath: string;
  ConfiguredInstallPath: string;
begin
  DefaultInstallPath := TestRootDir + PathDelim + 'toolchains' + PathDelim +
    'fpc' + PathDelim + '3.2.2';
  ConfiguredInstallPath := TestRootDir + PathDelim + 'custom' + PathDelim +
    'fpc-3.2.2';
  CreateMockFPCExecutable(ConfiguredInstallPath);

  Callbacks := TStatusFlowCallbacks.Create;
  try
    Callbacks.ConfiguredInstallPath := ConfiguredInstallPath;
    Callbacks.InferredScope := fssProject;

    Check(
      'statusflow configured install path succeeds',
      BuildManagedFPCStatusCore(
        '3.2.2',
        DefaultInstallPath,
        @Callbacks.LookupToolchainInfo,
        @Callbacks.ReadMetadata,
        @Callbacks.InferStatusScope,
        Status,
        ErrorText
      ),
      ErrorText
    );
    Check('statusflow lookup uses requested version',
      Callbacks.LastLookupVersion = '3.2.2',
      'lookup version=' + Callbacks.LastLookupVersion);
    Check('statusflow uses configured install path as managed prefix',
      Status.ManagedPrefix = ConfiguredInstallPath,
      'prefix=' + Status.ManagedPrefix);
    Check('statusflow marks configured default installed',
      Status.ConfiguredDefaultInstalled,
      'configured default should be installed');
    Check('statusflow falls back to inferred scope without metadata',
      Status.ActiveScope = fssProject,
      'scope mismatch');
  finally
    Callbacks.Free;
  end;
end;

procedure TestBuildManagedStatusMapsMetadataFields;
var
  Callbacks: TStatusFlowCallbacks;
  Status: TFPCStatusInfo;
  ErrorText: string;
  InstallPath: string;
begin
  InstallPath := TestRootDir + PathDelim + 'metadata' + PathDelim + '3.2.2';
  CreateMockFPCExecutable(InstallPath);

  Callbacks := TStatusFlowCallbacks.Create;
  try
    Callbacks.HasMetadata := True;
    Callbacks.InferredScope := fssProject;
    Callbacks.Metadata := Default(TFPDevMetadata);
    Callbacks.Metadata.Scope := isSystem;
    Callbacks.Metadata.SourceMode := smSource;
    Callbacks.Metadata.Verify.Timestamp := EncodeDate(2026, 4, 11);
    Callbacks.Metadata.Verify.OK := False;

    Check(
      'statusflow metadata mapping succeeds',
      BuildManagedFPCStatusCore(
        '3.2.2',
        InstallPath,
        @Callbacks.LookupToolchainInfo,
        @Callbacks.ReadMetadata,
        @Callbacks.InferStatusScope,
        Status,
        ErrorText
      ),
      ErrorText
    );
    Check('statusflow metadata reader sees resolved install path',
      Callbacks.LastReadInstallPath = InstallPath,
      'read path=' + Callbacks.LastReadInstallPath);
    Check('statusflow maps metadata scope to system',
      Status.ActiveScope = fssSystem,
      'scope mismatch');
    Check('statusflow maps metadata source mode',
      Status.SourceMode = smSource,
      'source mode mismatch');
    Check('statusflow marks source mode as present',
      Status.HasSourceMode,
      'has source mode should be true');
    Check('statusflow maps failed verify metadata',
      Status.VerifyStatus = fvsFail,
      'verify mismatch');
  finally
    Callbacks.Free;
  end;
end;

procedure TestBuildManagedStatusReportsMissingExecutable;
var
  Callbacks: TStatusFlowCallbacks;
  Status: TFPCStatusInfo;
  ErrorText: string;
  InstallPath: string;
begin
  InstallPath := TestRootDir + PathDelim + 'missing' + PathDelim + '3.2.2';

  Callbacks := TStatusFlowCallbacks.Create;
  try
    Check(
      'statusflow missing executable fails',
      not BuildManagedFPCStatusCore(
        '3.2.2',
        InstallPath,
        @Callbacks.LookupToolchainInfo,
        @Callbacks.ReadMetadata,
        @Callbacks.InferStatusScope,
        Status,
        ErrorText
      ),
      'expected missing executable to fail'
    );
    Check('statusflow missing executable reports install path',
      Pos(InstallPath, ErrorText) > 0,
      'error=' + ErrorText);
    Check('statusflow missing executable keeps managed prefix',
      Status.ManagedPrefix = InstallPath,
      'prefix=' + Status.ManagedPrefix);
  finally
    Callbacks.Free;
  end;
end;

begin
  WriteLn('=== FPC Statusflow Tests ===');

  InitTestEnvironment;
  try
    TestBuildManagedStatusWithoutConfiguredDefault;
    TestBuildManagedStatusPrefersConfiguredInstallPath;
    TestBuildManagedStatusMapsMetadataFields;
    TestBuildManagedStatusReportsMissingExecutable;
  finally
    CleanupTestEnvironment;
  end;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount <> 0 then
    Halt(1);
end.
