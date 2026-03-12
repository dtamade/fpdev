program test_cli_cross;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_cross - CLI tests for all cross sub-commands
================================================================================

  Covers: list, show, enable, disable, install, uninstall, configure,
          build, doctor, test, update, clean

  B193-B195: Cross command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.cmd.cross, fpdev.cross.downloader,
  fpdev.cmd.cross.root,
  fpdev.cmd.cross.list,
  fpdev.cmd.cross.show,
  fpdev.cmd.cross.enable,
  fpdev.cmd.cross.disable,
  fpdev.cmd.cross.install,
  fpdev.cmd.cross.uninstall,
  fpdev.cmd.cross.configure,
  fpdev.cmd.cross.build,
  fpdev.cmd.cross.doctor,
  fpdev.cmd.cross.test,
  fpdev.cmd.cross.update,
  fpdev.cmd.cross.clean,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;
  GManifestLoadCalled: Boolean = False;

type
  { TSpyCrossToolchainDownloader - detects unexpected manifest loads during local-only operations }
  TSpyCrossToolchainDownloader = class(TCrossToolchainDownloader)
  public
    function LoadManifest: Boolean; override;
  end;

function TSpyCrossToolchainDownloader.LoadManifest: Boolean;
begin
  GManifestLoadCalled := True;
  Result := False;
end;

function CreateSpyDownloader(const ADataRoot, AManifestURL: string): TCrossToolchainDownloader;
begin
  Result := TSpyCrossToolchainDownloader.Create(ADataRoot, AManifestURL);
end;

{ ===== list ===== }

procedure TestListName;
var Cmd: TCrossListCommand;
begin
  Cmd := TCrossListCommand.Create;
  try Check('list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestListHelp;
var Cmd: TCrossListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows usage', StdOut.Contains('list'));
    Check('list --help shows --all', StdOut.Contains('all'));
  finally Cmd.Free; end;
end;

procedure TestListNoArgs;
var Cmd: TCrossListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('list no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestListNoArgsDoesNotLoadManifest;
var
  Cmd: TCrossListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  GManifestLoadCalled := False;
  CrossToolchainDownloaderFactory := @CreateSpyDownloader;
  try
    Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
    Cmd := TCrossListCommand.Create;
    try
      Ret := Cmd.Execute([], Ctx);
      Check('list no args returns valid code', Ret >= 0);
      Check('list no args should not load cross manifest', not GManifestLoadCalled);
    finally
      Cmd.Free;
    end;
  finally
    CrossToolchainDownloaderFactory := nil;
  end;
end;

procedure TestListJsonOutput;
var Cmd: TCrossListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestListUnexpectedArg;
var Cmd: TCrossListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestListUnknownOption;
var Cmd: TCrossListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== show ===== }

procedure TestShowName;
var Cmd: TCrossShowCommand;
begin
  Cmd := TCrossShowCommand.Create;
  try Check('show: name', Cmd.Name = 'show'); finally Cmd.Free; end;
end;

procedure TestShowHelp;
var Cmd: TCrossShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossShowCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('show --help EXIT_OK', Ret = EXIT_OK);
    Check('show --help shows usage', StdOut.Contains('show'));
  finally Cmd.Free; end;
end;

procedure TestShowMissingTarget;
var Cmd: TCrossShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossShowCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('show no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestShowUnexpectedArg;
var Cmd: TCrossShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossShowCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('show unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestShowUnknownOption;
var Cmd: TCrossShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossShowCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('show unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== enable ===== }

procedure TestEnableName;
var Cmd: TCrossEnableCommand;
begin
  Cmd := TCrossEnableCommand.Create;
  try Check('enable: name', Cmd.Name = 'enable'); finally Cmd.Free; end;
end;

procedure TestEnableHelp;
var Cmd: TCrossEnableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossEnableCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('enable --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestEnableMissingTarget;
var Cmd: TCrossEnableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossEnableCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('enable no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestEnableUnexpectedArg;
var Cmd: TCrossEnableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossEnableCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('enable unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestEnableUnknownOption;
var Cmd: TCrossEnableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossEnableCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('enable unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== disable ===== }

procedure TestDisableName;
var Cmd: TCrossDisableCommand;
begin
  Cmd := TCrossDisableCommand.Create;
  try Check('disable: name', Cmd.Name = 'disable'); finally Cmd.Free; end;
end;

procedure TestDisableHelp;
var Cmd: TCrossDisableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDisableCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('disable --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestDisableMissingTarget;
var Cmd: TCrossDisableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDisableCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('disable no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDisableUnexpectedArg;
var Cmd: TCrossDisableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDisableCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('disable unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDisableUnknownOption;
var Cmd: TCrossDisableCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDisableCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('disable unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== install ===== }

procedure TestInstallName;
var Cmd: TCrossInstallCommand;
begin
  Cmd := TCrossInstallCommand.Create;
  try Check('install: name', Cmd.Name = 'install'); finally Cmd.Free; end;
end;

procedure TestInstallHelp;
var Cmd: TCrossInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install --help EXIT_OK', Ret = EXIT_OK);
    Check('install --help shows usage', StdOut.Contains('install'));
  finally Cmd.Free; end;
end;

procedure TestInstallMissingTarget;
var Cmd: TCrossInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossInstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallUnexpectedArg;
var Cmd: TCrossInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossInstallCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('install unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallUnknownOption;
var Cmd: TCrossInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('install unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== uninstall ===== }

procedure TestUninstallName;
var Cmd: TCrossUninstallCommand;
begin
  Cmd := TCrossUninstallCommand.Create;
  try Check('uninstall: name', Cmd.Name = 'uninstall'); finally Cmd.Free; end;
end;

procedure TestUninstallHelp;
var Cmd: TCrossUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('uninstall --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestUninstallMissingTarget;
var Cmd: TCrossUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUninstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('uninstall no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnexpectedArg;
var Cmd: TCrossUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('uninstall unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnknownOption;
var Cmd: TCrossUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('uninstall unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== configure ===== }

procedure TestConfigureName;
var Cmd: TCrossConfigureCommand;
begin
  Cmd := TCrossConfigureCommand.Create;
  try Check('configure: name', Cmd.Name = 'configure'); finally Cmd.Free; end;
end;

procedure TestConfigureHelp;
var Cmd: TCrossConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('configure --help EXIT_OK', Ret = EXIT_OK);
    Check('configure --help shows --auto', StdOut.Contains('auto'));
  finally Cmd.Free; end;
end;

procedure TestConfigureMissingTarget;
var Cmd: TCrossConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossConfigureCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('configure no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestConfigureUnexpectedArg;
var Cmd: TCrossConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['win64', '--binutils=/tmp/bin', '--libraries=/tmp/lib', 'extra'], Ctx);
    Check('configure unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestConfigureUnknownOption;
var Cmd: TCrossConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['win64', '--unknown'], Ctx);
    Check('configure unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== build ===== }

procedure TestBuildName;
var Cmd: TCrossBuildCommand;
begin
  Cmd := TCrossBuildCommand.Create;
  try Check('build: name', Cmd.Name = 'build'); finally Cmd.Free; end;
end;

procedure TestBuildHelp;
var Cmd: TCrossBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('build --help EXIT_OK', Ret = EXIT_OK);
    Check('build --help shows --dry-run', StdOut.Contains('dry-run'));
  finally Cmd.Free; end;
end;

procedure TestBuildMissingTarget;
var Cmd: TCrossBuildCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('build no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== doctor ===== }

procedure TestDoctorName;
var Cmd: TCrossDoctorCommand;
begin
  Cmd := TCrossDoctorCommand.Create;
  try Check('doctor: name', Cmd.Name = 'doctor'); finally Cmd.Free; end;
end;

procedure TestDoctorHelp;
var Cmd: TCrossDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('doctor --help EXIT_OK', Ret = EXIT_OK);
    Check('doctor --help shows usage', StdOut.Contains('doctor'));
  finally Cmd.Free; end;
end;

procedure TestDoctorNoArgs;
var Cmd: TCrossDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('doctor no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnexpectedArg;
var Cmd: TCrossDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('doctor unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnknownOption;
var Cmd: TCrossDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('doctor unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnwritableInstallRoot;
var
  Cmd: TCrossDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Settings: TFPDevSettings;
  ReadOnlyRoot: string;
begin
  {$IFDEF UNIX}
  ReadOnlyRoot := GTempDir + PathDelim + 'cross_doctor_ro';
  ForceDirectories(ReadOnlyRoot);

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := ReadOnlyRoot;
  if not Ctx.Config.GetSettingsManager.SetSettings(Settings) then
  begin
    Check('doctor unwritable setup: set install root', False);
    Exit;
  end;

  if fpchmod(ReadOnlyRoot, &555) <> 0 then
  begin
    Check('doctor unwritable setup: chmod readonly', False);
    Exit;
  end;

  Cmd := TCrossDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('doctor unwritable install root returns EXIT_ERROR', Ret = EXIT_ERROR);
  finally
    Cmd.Free;
    fpchmod(ReadOnlyRoot, &755);
    RemoveDir(ReadOnlyRoot);
  end;
  {$ELSE}
  Check('doctor unwritable install root skipped on non-UNIX', True);
  {$ENDIF}
end;

{ ===== test ===== }

procedure TestTestName;
var Cmd: TCrossTestCommand;
begin
  Cmd := TCrossTestCommand.Create;
  try Check('test: name', Cmd.Name = 'test'); finally Cmd.Free; end;
end;

procedure TestTestHelp;
var Cmd: TCrossTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('test --help EXIT_OK', Ret = EXIT_OK);
    Check('test --help shows usage', StdOut.Contains('test'));
  finally Cmd.Free; end;
end;

procedure TestTestMissingTarget;
var Cmd: TCrossTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossTestCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('test no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestTestUnexpectedArg;
var Cmd: TCrossTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossTestCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('test unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestTestUnknownOption;
var Cmd: TCrossTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossTestCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('test unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== update ===== }

procedure TestUpdateName;
var Cmd: TCrossUpdateCommand;
begin
  Cmd := TCrossUpdateCommand.Create;
  try Check('update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestUpdateHelp;
var Cmd: TCrossUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
  finally Cmd.Free; end;
end;

procedure TestUpdateMissingTarget;
var Cmd: TCrossUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('update no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnexpectedArg;
var Cmd: TCrossUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('update unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnknownOption;
var Cmd: TCrossUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('update unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== clean ===== }

procedure TestCleanName;
var Cmd: TCrossCleanCommand;
begin
  Cmd := TCrossCleanCommand.Create;
  try Check('clean: name', Cmd.Name = 'clean'); finally Cmd.Free; end;
end;

procedure TestCleanHelp;
var Cmd: TCrossCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('clean --help EXIT_OK', Ret = EXIT_OK);
    Check('clean --help shows usage', StdOut.Contains('clean'));
  finally Cmd.Free; end;
end;

procedure TestCleanMissingTarget;
var Cmd: TCrossCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('clean no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestCleanUnexpectedArg;
var Cmd: TCrossCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossCleanCommand.Create;
  try
    Ret := Cmd.Execute(['win64', 'extra'], Ctx);
    Check('clean unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestCleanUnknownOption;
var Cmd: TCrossCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCrossCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('clean unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestCrossRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundShow, FoundEnable, FoundDisable: Boolean;
  FoundInstall, FoundUninstall, FoundConfigure, FoundBuild: Boolean;
  FoundDoctor, FoundTest, FoundUpdate, FoundClean: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['cross']);
  FoundList := False; FoundShow := False; FoundEnable := False;
  FoundDisable := False; FoundInstall := False; FoundUninstall := False;
  FoundConfigure := False; FoundBuild := False; FoundDoctor := False;
  FoundTest := False; FoundUpdate := False; FoundClean := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'show' then FoundShow := True;
    if Children[I] = 'enable' then FoundEnable := True;
    if Children[I] = 'disable' then FoundDisable := True;
    if Children[I] = 'install' then FoundInstall := True;
    if Children[I] = 'uninstall' then FoundUninstall := True;
    if Children[I] = 'configure' then FoundConfigure := True;
    if Children[I] = 'build' then FoundBuild := True;
    if Children[I] = 'doctor' then FoundDoctor := True;
    if Children[I] = 'test' then FoundTest := True;
    if Children[I] = 'update' then FoundUpdate := True;
    if Children[I] = 'clean' then FoundClean := True;
  end;

  Check('cross list registered', FoundList);
  Check('cross show registered', FoundShow);
  Check('cross enable registered', FoundEnable);
  Check('cross disable registered', FoundDisable);
  Check('cross install registered', FoundInstall);
  Check('cross uninstall registered', FoundUninstall);
  Check('cross configure registered', FoundConfigure);
  Check('cross build registered', FoundBuild);
  Check('cross doctor registered', FoundDoctor);
  Check('cross test registered', FoundTest);
  Check('cross update registered', FoundUpdate);
  Check('cross clean registered', FoundClean);
end;

{ ===== Main ===== }
begin
  WriteLn('=== Cross Commands CLI Tests (B193-B195) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_cross');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListNoArgs;
    TestListNoArgsDoesNotLoadManifest;
    TestListJsonOutput;
    TestListUnexpectedArg;
    TestListUnknownOption;

    WriteLn('');
    WriteLn('--- show ---');
    TestShowName;
    TestShowHelp;
    TestShowMissingTarget;
    TestShowUnexpectedArg;
    TestShowUnknownOption;

    WriteLn('');
    WriteLn('--- enable ---');
    TestEnableName;
    TestEnableHelp;
    TestEnableMissingTarget;
    TestEnableUnexpectedArg;
    TestEnableUnknownOption;

    WriteLn('');
    WriteLn('--- disable ---');
    TestDisableName;
    TestDisableHelp;
    TestDisableMissingTarget;
    TestDisableUnexpectedArg;
    TestDisableUnknownOption;

    WriteLn('');
    WriteLn('--- install ---');
    TestInstallName;
    TestInstallHelp;
    TestInstallMissingTarget;
    TestInstallUnexpectedArg;
    TestInstallUnknownOption;

    WriteLn('');
    WriteLn('--- uninstall ---');
    TestUninstallName;
    TestUninstallHelp;
    TestUninstallMissingTarget;
    TestUninstallUnexpectedArg;
    TestUninstallUnknownOption;

    WriteLn('');
    WriteLn('--- configure ---');
    TestConfigureName;
    TestConfigureHelp;
    TestConfigureMissingTarget;
    TestConfigureUnexpectedArg;
    TestConfigureUnknownOption;

    WriteLn('');
    WriteLn('--- build ---');
    TestBuildName;
    TestBuildHelp;
    TestBuildMissingTarget;

    WriteLn('');
    WriteLn('--- doctor ---');
    TestDoctorName;
    TestDoctorHelp;
    TestDoctorNoArgs;
    TestDoctorUnexpectedArg;
    TestDoctorUnknownOption;
    TestDoctorUnwritableInstallRoot;

    WriteLn('');
    WriteLn('--- test ---');
    TestTestName;
    TestTestHelp;
    TestTestMissingTarget;
    TestTestUnexpectedArg;
    TestTestUnknownOption;

    WriteLn('');
    WriteLn('--- update ---');
    TestUpdateName;
    TestUpdateHelp;
    TestUpdateMissingTarget;
    TestUpdateUnexpectedArg;
    TestUpdateUnknownOption;

    WriteLn('');
    WriteLn('--- clean ---');
    TestCleanName;
    TestCleanHelp;
    TestCleanMissingTarget;
    TestCleanUnexpectedArg;
    TestCleanUnknownOption;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestCrossRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
