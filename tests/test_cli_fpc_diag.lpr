program test_cli_fpc_diag;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_fpc_diag - CLI tests for fpdev fpc doctor/status/verify/cache commands
================================================================================

  Tests the FPC diagnostic/cache commands' CLI behavior:
  - doctor: environment check with help, execution
  - status: managed compiler status with offline closure checks
  - verify: installation verification with help, missing args
  - cache list/clean/stats/path: cache management commands

  Uses shared test_cli_helpers unit for TStringOutput/TTestContext.

  B189: FPC diagnostic commands CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, DateUtils, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.types,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.build.cache.key,
  fpdev.paths,
  fpdev.fpc.metadata, fpdev.fpc.types,
  fpdev.cmd.fpc,                // Register 'fpc' root command
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.status,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.verify,
  fpdev.cmd.fpc.cache,          // Register 'fpc cache' root node
  fpdev.cmd.fpc.cache.list,
  fpdev.cmd.fpc.cache.clean,
  fpdev.cmd.fpc.cache.stats,
  fpdev.cmd.fpc.cache.path,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

procedure ConfigureInstallRoot(const Ctx: IContext; const AInstallRoot: string);
var
  Settings: TFPDevSettings;
begin
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := AInstallRoot;
  Ctx.Config.GetSettingsManager.SetSettings(Settings);
end;

procedure CompileMockFPCBinary(const ATargetPath: string);
var
  MockFPCSource: string;
  CompileProcess: TProcess;
begin
  MockFPCSource := ExpandFileName(
    ExtractFileDir(ParamStr(0)) + PathDelim + '..' + PathDelim + 'tests' +
    PathDelim + 'mock_fpc.pas'
  );

  CompileProcess := TProcess.Create(nil);
  try
    CompileProcess.Executable := 'fpc';
    CompileProcess.Parameters.Add('-o' + ATargetPath);
    CompileProcess.Parameters.Add(MockFPCSource);
    CompileProcess.Options := CompileProcess.Options + [poWaitOnExit];
    CompileProcess.Execute;

    if CompileProcess.ExitStatus <> 0 then
      raise Exception.Create('Failed to compile mock FPC executable');
  finally
    CompileProcess.Free;
  end;
end;

procedure SetupMockVerifyInstall(const Ctx: IContext; out AInstallRoot, AInstallDir: string);
var
  FPCExecutable: string;
begin
  AInstallRoot := CreateUniqueTempDir('fpdev_test_verify_exec');
  ConfigureInstallRoot(Ctx, AInstallRoot);

  AInstallDir := BuildFPCInstallDirFromInstallRoot(AInstallRoot, '3.2.2');
  ForceDirectories(AInstallDir + PathDelim + 'bin');
  ForceDirectories(AInstallDir + PathDelim + 'units');

  {$IFDEF MSWINDOWS}
  FPCExecutable := AInstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExecutable := AInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  CompileMockFPCBinary(FPCExecutable);
end;

procedure SetupMockLegacyVerifyInstall(
  const Ctx: IContext;
  out AInstallRoot, APreferredInstallDir, ALegacyInstallDir: string
);
var
  FPCExecutable: string;
begin
  AInstallRoot := CreateUniqueTempDir('fpdev_test_verify_legacy_exec');
  ConfigureInstallRoot(Ctx, AInstallRoot);

  APreferredInstallDir := BuildFPCInstallDirFromInstallRoot(AInstallRoot, '3.2.2');
  ALegacyInstallDir := AInstallRoot + PathDelim + 'fpc' + PathDelim + '3.2.2';
  ForceDirectories(ALegacyInstallDir + PathDelim + 'bin');
  ForceDirectories(ALegacyInstallDir + PathDelim + 'units');

  {$IFDEF MSWINDOWS}
  FPCExecutable := ALegacyInstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExecutable := ALegacyInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  CompileMockFPCBinary(FPCExecutable);
end;

procedure SetupMockConfiguredVerifyInstall(
  const Ctx: IContext;
  out AInstallRoot, APreferredInstallDir, AConfiguredInstallDir: string
);
var
  FPCExecutable: string;
  ToolchainInfo: TToolchainInfo;
begin
  AInstallRoot := CreateUniqueTempDir('fpdev_test_verify_configured_exec');
  ConfigureInstallRoot(Ctx, AInstallRoot);

  APreferredInstallDir := BuildFPCInstallDirFromInstallRoot(AInstallRoot, '3.2.2');
  AConfiguredInstallDir := AInstallRoot + PathDelim + 'custom-toolchains' +
    PathDelim + 'fpc-3.2.2';
  ForceDirectories(AConfiguredInstallDir + PathDelim + 'bin');
  ForceDirectories(AConfiguredInstallDir + PathDelim + 'units');

  ToolchainInfo := Default(TToolchainInfo);
  ToolchainInfo.Version := '3.2.2';
  ToolchainInfo.InstallPath := AConfiguredInstallDir;
  ToolchainInfo.Installed := True;
  ToolchainInfo.InstallDate := Now;
  if not Ctx.Config.GetToolchainManager.AddToolchain('fpc-3.2.2', ToolchainInfo) then
    raise Exception.Create('Failed to add configured FPC toolchain');

  {$IFDEF MSWINDOWS}
  FPCExecutable := AConfiguredInstallDir + PathDelim + 'bin' + PathDelim + 'fpc.exe';
  {$ELSE}
  FPCExecutable := AConfiguredInstallDir + PathDelim + 'bin' + PathDelim + 'fpc';
  {$ENDIF}

  CompileMockFPCBinary(FPCExecutable);
end;

function RegisterInstalledToolchain(
  const Ctx: IContext;
  const AVersion, AInstallDir: string
): Boolean;
var
  ToolchainInfo: TToolchainInfo;
begin
  ToolchainInfo := Default(TToolchainInfo);
  ToolchainInfo.Version := AVersion;
  ToolchainInfo.InstallPath := AInstallDir;
  ToolchainInfo.Installed := True;
  ToolchainInfo.InstallDate := Now;
  Result := Ctx.Config.GetToolchainManager.AddToolchain('fpc-' + AVersion, ToolchainInfo);
end;

{ ===== Group 1: fpc doctor - Command Basics ===== }

procedure TestDoctorCommandName;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: name is "doctor"', Cmd.Name = 'doctor');
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorAliasesNil;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorFindSubNil;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: fpc doctor - Help ===== }

procedure TestDoctorHelpFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('doctor --help returns EXIT_OK', Ret = EXIT_OK);
    Check('doctor --help shows usage', StdOut.Contains('doctor'));
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorHelpShortFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('doctor -h returns EXIT_OK', Ret = EXIT_OK);
    Check('doctor -h shows usage', StdOut.Contains('doctor'));
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorUnexpectedArg;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('doctor unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorUnknownOption;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('doctor unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: fpc doctor - Execution ===== }

procedure TestDoctorExecution;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    Check('doctor produces output', Length(AllOutput) > 0);
    Check('doctor returns valid exit code', Ret >= 0);
    // Doctor runs 11 checks
    Check('doctor shows check numbers', StdOut.Contains('[1/11]'));
    Check('doctor shows final check', StdOut.Contains('[11/11]'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: fpc doctor - Registration ===== }

procedure TestDoctorRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'doctor' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc doctor is registered in command registry', Found);
end;

{ ===== Group 5: fpc verify - Command Basics ===== }

procedure TestVerifyCommandName;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: name is "verify"', Cmd.Name = 'verify');
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyAliasesNil;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyFindSubNil;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: fpc verify - Help ===== }

procedure TestVerifyHelpFlag;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('verify --help returns EXIT_OK', Ret = EXIT_OK);
    Check('verify --help shows usage', StdOut.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyHelpShortFlag;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('verify -h returns EXIT_OK', Ret = EXIT_OK);
    Check('verify -h shows usage', StdOut.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyHelpUnexpectedArg;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('verify help unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('verify help unexpected arg shows usage', StdErr.Contains('verify'));
    Check('verify help unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 7: fpc verify - Missing Arguments ===== }

procedure TestVerifyMissingVersion;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    // verify with no args exits with EXIT_ERROR (not EXIT_OK)
    Check('verify no args returns error', Ret <> EXIT_OK);
    // Usage hint on stderr
    Check('verify no args shows usage hint', StdErr.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyUnexpectedArg;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('verify unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('verify unexpected arg shows usage', StdErr.Contains('verify'));
    Check('verify unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyUnknownOption;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--unknown'], Ctx);
    Check('verify unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('verify unknown option shows usage', StdErr.Contains('verify'));
    Check('verify unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyExecutionSelfHealsMissingMetadata;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot, InstallDir: string;
  MetaPath: string;
  Meta: TFPDevMetadata;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  SetupMockVerifyInstall(Ctx, InstallRoot, InstallDir);
  Cmd := TFPCVerifyCommand.Create;
  try
    MetaPath := GetMetadataPath(InstallDir);
    if FileExists(MetaPath) then
      DeleteFile(MetaPath);

    Ret := Cmd.Execute(['3.2.2'], Ctx);

    Check('verify execution returns EXIT_OK', Ret = EXIT_OK);
    Check('verify execution prints completion message',
      StdOut.Contains('Verification complete: FPC 3.2.2 is working correctly'));
    Check('verify execution reports metadata success',
      StdOut.Contains('PASS: Metadata file exists'));
    Check('verify execution does not print fail banner',
      not StdErr.Contains('FAIL:'));
    Check('verify execution backfills metadata file', FileExists(MetaPath));
    Check('verify execution metadata is readable', ReadFPCMetadata(InstallDir, Meta));
    Check('verify execution metadata ok=true', Meta.Verify.OK);
    Check('verify execution metadata version preserved',
      Meta.Verify.DetectedVersion = '3.2.2');
    Check('verify execution metadata smoke test=true', Meta.Verify.SmokeTestPassed);
  finally
    Cmd.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestVerifyExecutionPreservesExistingSourceMetadata;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot, InstallDir: string;
  Meta, ReadMeta: TFPDevMetadata;
  InstalledAt: TDateTime;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  SetupMockVerifyInstall(Ctx, InstallRoot, InstallDir);
  Cmd := TFPCVerifyCommand.Create;
  try
    InstalledAt := EncodeDate(2026, 3, 19) + EncodeTime(8, 30, 0, 0);
    Meta := Default(TFPDevMetadata);
    Meta.Version := '3.2.2';
    Meta.Scope := isUser;
    Meta.SourceMode := smSource;
    Meta.Channel := 'stable';
    Meta.Prefix := InstallDir;
    Meta.Origin.RepoURL := 'https://example.invalid/fpc.git';
    Meta.Origin.BuiltFromSource := True;
    Meta.InstalledAt := InstalledAt;
    Check('verify preserve test seeds metadata', WriteFPCMetadata(InstallDir, Meta));

    Ret := Cmd.Execute(['3.2.2'], Ctx);

    Check('verify preserve test returns EXIT_OK', Ret = EXIT_OK);
    Check('verify preserve test reloads metadata', ReadFPCMetadata(InstallDir, ReadMeta));
    Check('verify preserve test keeps source mode', ReadMeta.SourceMode = smSource);
    Check('verify preserve test keeps repo url',
      ReadMeta.Origin.RepoURL = 'https://example.invalid/fpc.git');
    Check('verify preserve test keeps built_from_source', ReadMeta.Origin.BuiltFromSource);
    Check('verify preserve test keeps installed_at',
      Abs(ReadMeta.InstalledAt - InstalledAt) < (1 / SecsPerDay));
    Check('verify preserve test updates verify ok', ReadMeta.Verify.OK);
    Check('verify preserve test updates verify version',
      ReadMeta.Verify.DetectedVersion = '3.2.2');
    Check('verify preserve test updates verify smoke test',
      ReadMeta.Verify.SmokeTestPassed);
  finally
    Cmd.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestVerifyExecutionLegacyLayoutBackfillsMetadataAtLegacyPath;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  PreferredInstallDir: string;
  LegacyInstallDir: string;
  Meta: TFPDevMetadata;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  SetupMockLegacyVerifyInstall(Ctx, InstallRoot, PreferredInstallDir, LegacyInstallDir);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);

    Check('verify legacy execution returns EXIT_OK', Ret = EXIT_OK);
    Check('verify legacy execution reports metadata success',
      StdOut.Contains('PASS: Metadata file exists'));
    Check('verify legacy execution backfills metadata at legacy path',
      FileExists(GetMetadataPath(LegacyInstallDir)));
    Check('verify legacy execution metadata is readable',
      ReadFPCMetadata(LegacyInstallDir, Meta));
    Check('verify legacy execution metadata ok=true', Meta.Verify.OK);
    Check('verify legacy execution metadata version preserved',
      Meta.Verify.DetectedVersion = '3.2.2');
    Check('verify legacy execution metadata does not appear in preferred path',
      not FileExists(GetMetadataPath(PreferredInstallDir)));
  finally
    Cmd.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestVerifyExecutionConfiguredInstallPathBackfillsMetadataAtConfiguredPath;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  PreferredInstallDir: string;
  ConfiguredInstallDir: string;
  Meta: TFPDevMetadata;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  SetupMockConfiguredVerifyInstall(
    Ctx,
    InstallRoot,
    PreferredInstallDir,
    ConfiguredInstallDir
  );
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);

    Check('verify configured execution returns EXIT_OK', Ret = EXIT_OK);
    Check('verify configured execution reports metadata success',
      StdOut.Contains('PASS: Metadata file exists'));
    Check('verify configured execution backfills metadata at configured path',
      FileExists(GetMetadataPath(ConfiguredInstallDir)));
    Check('verify configured execution metadata is readable',
      ReadFPCMetadata(ConfiguredInstallDir, Meta));
    Check('verify configured execution metadata ok=true', Meta.Verify.OK);
    Check('verify configured execution metadata version preserved',
      Meta.Verify.DetectedVersion = '3.2.2');
    Check('verify configured execution metadata prefix uses configured path',
      ExpandFileName(Meta.Prefix) = ExpandFileName(ConfiguredInstallDir));
    Check('verify configured execution metadata does not appear in default path',
      not FileExists(GetMetadataPath(PreferredInstallDir)));
  finally
    Cmd.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

{ ===== Group 8: fpc verify - Registration ===== }

procedure TestVerifyRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'verify' then
    begin
      Found := True;
      Break;
  end;
  Check('fpc verify is registered in command registry', Found);
end;

{ ===== Group 9: fpc status - Command Basics ===== }

procedure TestStatusCommandName;
var
  Cmd: TFPCStatusCommand;
begin
  Cmd := TFPCStatusCommand.Create;
  try
    Check('status: name is "status"', Cmd.Name = 'status');
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusAliasesNil;
var
  Cmd: TFPCStatusCommand;
begin
  Cmd := TFPCStatusCommand.Create;
  try
    Check('status: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusFindSubNil;
var
  Cmd: TFPCStatusCommand;
begin
  Cmd := TFPCStatusCommand.Create;
  try
    Check('status: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 10: fpc status - Help ===== }

procedure TestStatusHelpFlag;
var
  Cmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('status --help returns EXIT_OK', Ret = EXIT_OK);
    Check('status --help shows usage',
      StdOut.Contains('Usage: fpdev fpc status [--json]'));
    Check('status --help shows --json option', StdOut.Contains('--json'));
    Check('status --help keeps stderr empty', Trim(StdErr.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusHelpShortFlag;
var
  Cmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('status -h returns EXIT_OK', Ret = EXIT_OK);
    Check('status -h shows usage',
      StdOut.Contains('Usage: fpdev fpc status [--json]'));
    Check('status -h keeps stderr empty', Trim(StdErr.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusHelpUnexpectedArg;
var
  Cmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('status --help extra returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('status --help extra shows usage',
      StdErr.Contains('Usage: fpdev fpc status [--json]'));
    Check('status --help extra keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc status - Execution ===== }

procedure TestStatusNoDefaultConfigured;
var
  Cmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);

    Check('status without default returns EXIT_OK', Ret = EXIT_OK);
    Check('status without default reports none effective version',
      StdOut.Contains('Effective version: none'));
    Check('status without default reports none configured default',
      StdOut.Contains('Configured default: none'));
    Check('status without default reports none scope',
      StdOut.Contains('Active scope: none'));
    Check('status without default reports none prefix',
      StdOut.Contains('Managed prefix: none'));
    Check('status without default reports unknown source mode',
      StdOut.Contains('Source mode: unknown'));
    Check('status without default reports unknown verify status',
      StdOut.Contains('Verify status: unknown'));
    Check('status without default keeps stderr empty', Trim(StdErr.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusMissingConfiguredInstall;
var
  Cmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot, MissingInstallDir: string;
  ToolchainInfo: TToolchainInfo;
  Registered, SetDefault: Boolean;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  InstallRoot := CreateUniqueTempDir('fpdev_test_status_missing_exec');
  ConfigureInstallRoot(Ctx, InstallRoot);
  Cmd := TFPCStatusCommand.Create;
  try
    MissingInstallDir := BuildFPCInstallDirFromInstallRoot(InstallRoot, '3.2.2');
    ToolchainInfo := Default(TToolchainInfo);
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := MissingInstallDir;
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;
    Registered := Ctx.Config.GetToolchainManager.AddToolchain('fpc-3.2.2', ToolchainInfo);
    Check('status missing-install seeds toolchain entry', Registered);
    SetDefault := Registered and
      Ctx.Config.GetToolchainManager.SetDefaultToolchain('fpc-3.2.2');
    Check('status missing-install sets default toolchain', SetDefault);

    Ret := Cmd.Execute([], Ctx);

    Check('status missing-install returns EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('status missing-install reports missing configured version',
      StdErr.Contains('Configured default FPC 3.2.2 is missing:'));
    Check('status missing-install reports resolved install path',
      StdErr.Contains(MissingInstallDir));
    Check('status missing-install keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
    CleanupTempDir(InstallRoot);
  end;
end;

procedure TestStatusExecutionAfterUseVerify;
var
  UseCmd: TFPCUseCommand;
  VerifyCmd: TFPCVerifyCommand;
  StatusCmd: TFPCStatusCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  UseRet, VerifyRet, StatusRet: Integer;
  InstallRoot, InstallDir: string;
  WorkspaceDir, SavedDir: string;
  Registered, WorkspaceReady: Boolean;
  Meta: TFPDevMetadata;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  SetupMockVerifyInstall(Ctx, InstallRoot, InstallDir);
  WorkspaceDir := CreateUniqueTempDir('fpdev_test_status_workspace');
  SavedDir := GetCurrentDir;
  UseCmd := TFPCUseCommand.Create;
  VerifyCmd := TFPCVerifyCommand.Create;
  StatusCmd := TFPCStatusCommand.Create;
  try
    Registered := RegisterInstalledToolchain(Ctx, '3.2.2', InstallDir);
    Check('status closure registers toolchain entry', Registered);

    WorkspaceReady := SetCurrentDir(WorkspaceDir);
    Check('status closure switches to temp workspace', WorkspaceReady);

    if Registered and WorkspaceReady then
    begin
      UseRet := UseCmd.Execute(['3.2.2'], Ctx);
      Check('status closure use returns EXIT_OK', UseRet = EXIT_OK);
      Check('status closure use sets default toolchain',
        Ctx.Config.GetToolchainManager.GetDefaultToolchain = 'fpc-3.2.2');

      StdOut.Clear;
      StdErr.Clear;
      VerifyRet := VerifyCmd.Execute(['3.2.2'], Ctx);
      Check('status closure verify returns EXIT_OK', VerifyRet = EXIT_OK);
      Check('status closure verify writes metadata', ReadFPCMetadata(InstallDir, Meta));
      Check('status closure verify metadata ok=true', Meta.Verify.OK);

      StdOut.Clear;
      StdErr.Clear;
      StatusRet := StatusCmd.Execute([], Ctx);
      Check('status closure text returns EXIT_OK', StatusRet = EXIT_OK);
      Check('status closure reports effective version',
        StdOut.Contains('Effective version: 3.2.2'));
      Check('status closure reports configured default',
        StdOut.Contains('Configured default: 3.2.2'));
      Check('status closure reports active scope user',
        StdOut.Contains('Active scope: user'));
      Check('status closure reports managed prefix',
        StdOut.Contains('Managed prefix: ' + InstallDir));
      Check('status closure reports auto source mode',
        StdOut.Contains('Source mode: auto'));
      Check('status closure reports verify ok',
        StdOut.Contains('Verify status: ok'));
      Check('status closure text keeps stderr empty', Trim(StdErr.GetBuffer) = '');

      StdOut.Clear;
      StdErr.Clear;
      StatusRet := StatusCmd.Execute(['--json'], Ctx);
      Check('status closure json returns EXIT_OK', StatusRet = EXIT_OK);
      Check('status closure json reports effective version',
        StdOut.Contains('"effective_version" : "3.2.2"'));
      Check('status closure json reports configured default',
        StdOut.Contains('"configured_default" : "3.2.2"'));
      Check('status closure json reports active scope user',
        StdOut.Contains('"active_scope" : "user"'));
      Check('status closure json reports managed prefix',
        StdOut.Contains('"managed_prefix" : "' + InstallDir + '"'));
      Check('status closure json reports auto source mode',
        StdOut.Contains('"source_mode" : "auto"'));
      Check('status closure json reports verify ok',
        StdOut.Contains('"verify_status" : "ok"'));
      Check('status closure json keeps stderr empty', Trim(StdErr.GetBuffer) = '');
    end;
  finally
    SetCurrentDir(SavedDir);
    UseCmd.Free;
    VerifyCmd.Free;
    StatusCmd.Free;
    CleanupTempDir(WorkspaceDir);
    CleanupTempDir(InstallRoot);
  end;
end;

{ ===== Group 12: fpc status - Registration ===== }

procedure TestStatusRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'status' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc status is registered in command registry', Found);
end;

{ ===== Group 13: fpc cache list - Command Basics ===== }

procedure TestCacheListCommandName;
var
  Cmd: TFPCCacheListCommand;
begin
  Cmd := TFPCCacheListCommand.Create;
  try
    Check('cache list: name is "list"', Cmd.Name = 'list');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListHelpFlag;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache list --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache list --help shows usage', StdOut.Contains('cache list'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListExecution;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    Check('cache list produces output', Length(AllOutput) > 0);
    Check('cache list returns EXIT_OK', Ret = EXIT_OK);
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListUnexpectedArg;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('cache list unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListUnknownOption;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('cache list unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 10: fpc cache clean - Command Basics ===== }

procedure TestCacheCleanCommandName;
var
  Cmd: TFPCCacheCleanCommand;
begin
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Check('cache clean: name is "clean"', Cmd.Name = 'clean');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanHelpFlag;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache clean --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache clean --help shows usage', StdOut.Contains('cache clean'));
    Check('cache clean --help shows --all option', StdOut.Contains('all'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanNoArgs;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache clean no args returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('cache clean no args shows error', StdErr.Contains('version') or StdErr.Contains('all'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanNonExistent;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    Check('cache clean non-existent returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('cache clean non-existent shows error', StdErr.Contains('not cached'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanAllPartialFailure;
{$IFDEF UNIX}
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  CacheDir, Version, ArchivePath: string;
  StatBuf: TStat;
  OriginalMode: Cardinal;
  TempFile: TStringList;
{$ENDIF}
begin
  {$IFDEF UNIX}
  CacheDir := GetCacheDir;
  ForceDirectories(CacheDir);

  Version := IntToStr((GetTickCount64 mod 1000000) + 1000000) + '.0.0';
  ArchivePath := IncludeTrailingPathDelimiter(CacheDir) + 'fpc-' + Version + '-' +
    BuildCacheGetCurrentCPU + '-' + BuildCacheGetCurrentOS + '.tar.gz';

  TempFile := TStringList.Create;
  try
    TempFile.Add('test');
    TempFile.SaveToFile(ArchivePath);
  finally
    TempFile.Free;
  end;

  OriginalMode := &755;
  if FpStat(CacheDir, StatBuf) = 0 then
    OriginalMode := StatBuf.st_mode and $1FF;

  if FpChmod(CacheDir, &555) <> 0 then
  begin
    DeleteFile(ArchivePath);
    Check('cache clean --all partial failure setup chmod', False);
    Exit;
  end;

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--all'], Ctx);
    Check('cache clean --all partial failure returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('cache clean --all partial failure shows failed delete', StdErr.Contains('Failed to delete'));
  finally
    Cmd.Free;
    FpChmod(CacheDir, OriginalMode);
    DeleteFile(ArchivePath);
  end;
  {$ELSE}
  Check('cache clean --all partial failure test skipped on non-UNIX', True);
  {$ENDIF}
end;

procedure TestCacheCleanUnexpectedArg;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('cache clean unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanUnknownOption;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('cache clean unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanAllUnexpectedArg;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--all', 'extra'], Ctx);
    Check('cache clean --all with extra arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc cache stats - Command Basics ===== }

procedure TestCacheStatsCommandName;
var
  Cmd: TFPCCacheStatsCommand;
begin
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Check('cache stats: name is "stats"', Cmd.Name = 'stats');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsHelpFlag;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache stats --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache stats --help shows usage', StdOut.Contains('cache stats'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsExecution;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache stats returns EXIT_OK', Ret = EXIT_OK);
    Check('cache stats shows statistics', StdOut.Contains('Statistics') or StdOut.Contains('Cached'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsUnexpectedArg;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('cache stats unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsUnknownOption;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('cache stats unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 12: fpc cache path - Command Basics ===== }

procedure TestCachePathCommandName;
var
  Cmd: TFPCCachePathCommand;
begin
  Cmd := TFPCCachePathCommand.Create;
  try
    Check('cache path: name is "path"', Cmd.Name = 'path');
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathHelpFlag;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache path --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache path --help shows usage', StdOut.Contains('cache path'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathExecution;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache path returns EXIT_OK', Ret = EXIT_OK);
    Check('cache path shows cache directory', StdOut.Contains('cache'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathUnexpectedArg;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('cache path unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathUnknownOption;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('cache path unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 13: fpc cache - Registration ===== }

procedure TestCacheRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundCache, FoundList, FoundClean, FoundStats, FoundPath: Boolean;
begin
  // Check 'cache' is a child of 'fpc'
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  FoundCache := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'cache' then
    begin
      FoundCache := True;
      Break;
    end;
  Check('fpc cache is registered', FoundCache);

  // Check sub-commands of 'fpc cache'
  Children := GlobalCommandRegistry.ListChildren(['fpc', 'cache']);
  FoundList := False;
  FoundClean := False;
  FoundStats := False;
  FoundPath := False;
  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'clean' then FoundClean := True;
    if Children[I] = 'stats' then FoundStats := True;
    if Children[I] = 'path' then FoundPath := True;
  end;
  Check('fpc cache list is registered', FoundList);
  Check('fpc cache clean is registered', FoundClean);
  Check('fpc cache stats is registered', FoundStats);
  Check('fpc cache path is registered', FoundPath);
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Diagnostic Commands CLI Tests (doctor/status/verify/cache) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_fpc_diag');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    // Group 1: fpc doctor basics
    WriteLn('--- fpc doctor: Command Basics ---');
    TestDoctorCommandName;
    TestDoctorAliasesNil;
    TestDoctorFindSubNil;

    // Group 2: fpc doctor help
    WriteLn('');
    WriteLn('--- fpc doctor: Help Output ---');
    TestDoctorHelpFlag;
    TestDoctorHelpShortFlag;
    TestDoctorUnexpectedArg;
    TestDoctorUnknownOption;

    // Group 3: fpc doctor execution
    WriteLn('');
    WriteLn('--- fpc doctor: Execution ---');
    TestDoctorExecution;

    // Group 4: fpc doctor registration
    WriteLn('');
    WriteLn('--- fpc doctor: Registration ---');
    TestDoctorRegistration;

    // Group 5: fpc verify basics
    WriteLn('');
    WriteLn('--- fpc verify: Command Basics ---');
    TestVerifyCommandName;
    TestVerifyAliasesNil;
    TestVerifyFindSubNil;

    // Group 6: fpc verify help
    WriteLn('');
    WriteLn('--- fpc verify: Help Output ---');
    TestVerifyHelpFlag;
    TestVerifyHelpShortFlag;
    TestVerifyHelpUnexpectedArg;

    // Group 7: fpc verify missing args
    WriteLn('');
    WriteLn('--- fpc verify: Argument Validation ---');
    TestVerifyMissingVersion;
    TestVerifyUnexpectedArg;
    TestVerifyUnknownOption;

    // Group 7b: fpc verify execution
    WriteLn('');
    WriteLn('--- fpc verify: Execution ---');
    TestVerifyExecutionSelfHealsMissingMetadata;
    TestVerifyExecutionPreservesExistingSourceMetadata;
    TestVerifyExecutionLegacyLayoutBackfillsMetadataAtLegacyPath;
    TestVerifyExecutionConfiguredInstallPathBackfillsMetadataAtConfiguredPath;

    // Group 8: fpc verify registration
    WriteLn('');
    WriteLn('--- fpc verify: Registration ---');
    TestVerifyRegistration;

    // Group 9: fpc status basics
    WriteLn('');
    WriteLn('--- fpc status: Command Basics ---');
    TestStatusCommandName;
    TestStatusAliasesNil;
    TestStatusFindSubNil;

    // Group 10: fpc status help
    WriteLn('');
    WriteLn('--- fpc status: Help Output ---');
    TestStatusHelpFlag;
    TestStatusHelpShortFlag;
    TestStatusHelpUnexpectedArg;

    // Group 11: fpc status execution
    WriteLn('');
    WriteLn('--- fpc status: Execution ---');
    TestStatusNoDefaultConfigured;
    TestStatusMissingConfiguredInstall;
    TestStatusExecutionAfterUseVerify;

    // Group 12: fpc status registration
    WriteLn('');
    WriteLn('--- fpc status: Registration ---');
    TestStatusRegistration;

    // Group 13: fpc cache list
    WriteLn('');
    WriteLn('--- fpc cache list ---');
    TestCacheListCommandName;
    TestCacheListHelpFlag;
    TestCacheListExecution;
    TestCacheListUnexpectedArg;
    TestCacheListUnknownOption;

    // Group 14: fpc cache clean
    WriteLn('');
    WriteLn('--- fpc cache clean ---');
    TestCacheCleanCommandName;
    TestCacheCleanHelpFlag;
    TestCacheCleanNoArgs;
    TestCacheCleanNonExistent;
    TestCacheCleanAllPartialFailure;
    TestCacheCleanUnexpectedArg;
    TestCacheCleanUnknownOption;
    TestCacheCleanAllUnexpectedArg;

    // Group 15: fpc cache stats
    WriteLn('');
    WriteLn('--- fpc cache stats ---');
    TestCacheStatsCommandName;
    TestCacheStatsHelpFlag;
    TestCacheStatsExecution;
    TestCacheStatsUnexpectedArg;
    TestCacheStatsUnknownOption;

    // Group 16: fpc cache path
    WriteLn('');
    WriteLn('--- fpc cache path ---');
    TestCachePathCommandName;
    TestCachePathHelpFlag;
    TestCachePathExecution;
    TestCachePathUnexpectedArg;
    TestCachePathUnknownOption;

    // Group 17: fpc cache registration
    WriteLn('');
    WriteLn('--- fpc cache: Registration ---');
    TestCacheRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
