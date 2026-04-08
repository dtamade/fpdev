program test_fpc_status;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces, fpdev.exitcodes,
  fpdev.fpc.metadata, fpdev.fpc.types, fpdev.paths, fpdev.types,
  fpdev.cmd.fpc, fpdev.cmd.fpc.status,
  test_cli_helpers, test_temp_paths;

function CreateStatusTestContext(
  const AName: string;
  out ARootDir: string;
  out AStdOut, AStdErr: TStringOutput
): IContext;
var
  Settings: TFPDevSettings;
begin
  ARootDir := CreateUniqueTempDir('fpdev_test_fpc_status_' + AName);
  Result := CreateTestContext(ARootDir, AStdOut, AStdErr);
  Settings := Result.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := ARootDir;
  Result.Config.GetSettingsManager.SetSettings(Settings);
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

procedure SeedManagedToolchain(
  const Ctx: IContext;
  const AVersion, AInstallPath: string
);
var
  ToolchainInfo: TToolchainInfo;
begin
  ToolchainInfo := Default(TToolchainInfo);
  ToolchainInfo.ToolchainType := ttRelease;
  ToolchainInfo.Version := AVersion;
  ToolchainInfo.InstallPath := AInstallPath;
  ToolchainInfo.Installed := True;
  ToolchainInfo.InstallDate := Now;
  Ctx.Config.GetToolchainManager.AddToolchain('fpc-' + AVersion, ToolchainInfo);
  Ctx.Config.GetToolchainManager.SetDefaultToolchain('fpc-' + AVersion);
end;

procedure SeedMetadata(
  const AInstallPath, AVersion: string;
  AScope: TInstallScope;
  ASourceMode: TSourceMode;
  AVerifyOK: Boolean
);
var
  Meta: TFPDevMetadata;
begin
  Meta := Default(TFPDevMetadata);
  Meta.Version := AVersion;
  Meta.Scope := AScope;
  Meta.SourceMode := ASourceMode;
  Meta.Prefix := AInstallPath;
  Meta.Verify.Timestamp := Now;
  Meta.Verify.OK := AVerifyOK;
  Meta.Verify.DetectedVersion := AVersion;
  Meta.Verify.SmokeTestPassed := AVerifyOK;
  WriteFPCMetadata(AInstallPath, Meta);
end;

procedure TestStatusCommandBasics;
var
  Cmd: TFPCStatusCommand;
begin
  Cmd := TFPCStatusCommand.Create;
  try
    Check('status: name is "status"', Cmd.Name = 'status');
    Check('status: aliases is nil', Cmd.Aliases = nil);
    Check('status: FindSub returns nil', Cmd.FindSub('anything') = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestStatusHelpFlag;
var
  RootDir: string;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Cmd: TFPCStatusCommand;
  Ret: Integer;
begin
  Ctx := CreateStatusTestContext('help', RootDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('status --help returns EXIT_OK', Ret = EXIT_OK);
    Check('status --help shows usage', StdOut.Contains('Usage: fpdev fpc status [--json]'));
    Check('status --help shows json option', StdOut.Contains('--json'));
  finally
    Cmd.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestStatusWithoutConfiguredDefault;
var
  RootDir: string;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Cmd: TFPCStatusCommand;
  Ret: Integer;
begin
  Ctx := CreateStatusTestContext('empty', RootDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('status without default returns EXIT_OK', Ret = EXIT_OK);
    Check('status without default shows effective none',
      StdOut.Contains('Effective version: none'));
    Check('status without default shows configured none',
      StdOut.Contains('Configured default: none'));
    Check('status without default shows scope none',
      StdOut.Contains('Active scope: none'));
    Check('status without default shows source unknown',
      StdOut.Contains('Source mode: unknown'));
    Check('status without default shows verify unknown',
      StdOut.Contains('Verify status: unknown'));
  finally
    Cmd.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestStatusJsonWithoutConfiguredDefault;
var
  RootDir: string;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Cmd: TFPCStatusCommand;
  Ret: Integer;
begin
  Ctx := CreateStatusTestContext('json_empty', RootDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('status --json without default returns EXIT_OK', Ret = EXIT_OK);
    Check('status --json without default shows effective none',
      StdOut.Contains('"effective_version" : "none"'));
    Check('status --json without default shows scope none',
      StdOut.Contains('"active_scope" : "none"'));
    Check('status --json without default shows verify unknown',
      StdOut.Contains('"verify_status" : "unknown"'));
  finally
    Cmd.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestStatusReportsMissingConfiguredDefault;
var
  RootDir: string;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Cmd: TFPCStatusCommand;
  Ret: Integer;
  InstallPath: string;
begin
  Ctx := CreateStatusTestContext('missing', RootDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    InstallPath := BuildFPCInstallDirFromInstallRoot(RootDir, '3.2.2');
    SeedManagedToolchain(Ctx, '3.2.2', InstallPath);

    Ret := Cmd.Execute([], Ctx);
    Check('status missing configured default returns EXIT_NOT_FOUND',
      Ret = EXIT_NOT_FOUND);
    Check('status missing configured default reports missing toolchain',
      StdErr.Contains('Configured default FPC 3.2.2 is missing'));
  finally
    Cmd.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestStatusReportsInstalledMetadata;
var
  RootDir: string;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Cmd: TFPCStatusCommand;
  Ret: Integer;
  InstallPath: string;
begin
  Ctx := CreateStatusTestContext('installed', RootDir, StdOut, StdErr);
  Cmd := TFPCStatusCommand.Create;
  try
    InstallPath := BuildFPCInstallDirFromInstallRoot(RootDir, '3.2.2');
    CreateMockFPCExecutable(InstallPath);
    SeedManagedToolchain(Ctx, '3.2.2', InstallPath);
    SeedMetadata(InstallPath, '3.2.2', isUser, smBinary, True);

    Ret := Cmd.Execute([], Ctx);
    Check('status installed metadata returns EXIT_OK', Ret = EXIT_OK);
    Check('status installed metadata shows effective version',
      StdOut.Contains('Effective version: 3.2.2'));
    Check('status installed metadata shows configured default',
      StdOut.Contains('Configured default: 3.2.2'));
    Check('status installed metadata shows user scope',
      StdOut.Contains('Active scope: user'));
    Check('status installed metadata shows managed prefix',
      StdOut.Contains('Managed prefix: ' + InstallPath));
    Check('status installed metadata shows binary source mode',
      StdOut.Contains('Source mode: binary'));
    Check('status installed metadata shows verify ok',
      StdOut.Contains('Verify status: ok'));
  finally
    Cmd.Free;
    CleanupTempDir(RootDir);
  end;
end;

procedure TestStatusRegistration;
var
  Children: TStringArray;
  Index: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for Index := Low(Children) to High(Children) do
    if SameText(Children[Index], 'status') then
      Found := True;
  Check('fpc status is registered in command registry', Found);
end;

begin
  WriteLn('=== FPC Status Command Tests ===');
  WriteLn;

  TestStatusCommandBasics;
  TestStatusHelpFlag;
  TestStatusWithoutConfiguredDefault;
  TestStatusJsonWithoutConfiguredDefault;
  TestStatusReportsMissingConfiguredDefault;
  TestStatusReportsInstalledMetadata;
  TestStatusRegistration;

  Halt(PrintTestSummary);
end.
