program test_cli_lazarus;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_lazarus - CLI tests for all lazarus sub-commands
================================================================================

  Covers: install, list, use, current, show, configure, doctor, run,
          uninstall, update, test

  B191-B192: Lazarus command CLI test coverage
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
  fpdev.cmd.lazarus,             // Register 'lazarus' root
  fpdev.cmd.lazarus.install,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.show,
  fpdev.cmd.lazarus.configure,
  fpdev.cmd.lazarus.doctor,
  fpdev.cmd.lazarus.run,
  fpdev.cmd.lazarus.uninstall,
  fpdev.cmd.lazarus.update,
  fpdev.cmd.lazarus.test,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

{ ===== install ===== }

procedure TestInstallName;
var Cmd: TLazInstallCommand;
begin
  Cmd := TLazInstallCommand.Create;
  try Check('install: name', Cmd.Name = 'install'); finally Cmd.Free; end;
end;

procedure TestInstallHelp;
var Cmd: TLazInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install --help EXIT_OK', Ret = EXIT_OK);
    Check('install --help shows usage', StdOut.Contains('install'));
  finally Cmd.Free; end;
end;

procedure TestInstallHelpShort;
var Cmd: TLazInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('install -h EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestInstallHelpUnexpectedArg;
var Cmd: TLazInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('install help unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestInstallMissingVersion;
var Cmd: TLazInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('install no args shows error', StdErr.Contains('version'));
  finally Cmd.Free; end;
end;

{ ===== list ===== }

procedure TestListName;
var Cmd: TLazListCommand;
begin
  Cmd := TLazListCommand.Create;
  try Check('list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestListHelp;
var Cmd: TLazListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows --all', StdOut.Contains('all'));
    Check('list --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestListJsonOutput;
var Cmd: TLazListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json EXIT_OK', Ret = EXIT_OK);
    Check('list --json has versions key', StdOut.Contains('versions'));
  finally Cmd.Free; end;
end;

procedure TestListUnexpectedArg;
var Cmd: TLazListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestListUnknownOption;
var Cmd: TLazListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== use ===== }

procedure TestUseName;
var Cmd: TLazUseCommand;
begin
  Cmd := TLazUseCommand.Create;
  try Check('use: name', Cmd.Name = 'use'); finally Cmd.Free; end;
end;

procedure TestUseAlias;
var Cmd: TLazUseCommand; A: TStringArray;
begin
  Cmd := TLazUseCommand.Create;
  try
    A := Cmd.Aliases;
    Check('use: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestUseHelp;
var Cmd: TLazUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUseCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('use --help EXIT_OK', Ret = EXIT_OK);
    Check('use --help shows usage', StdOut.Contains('use'));
  finally Cmd.Free; end;
end;

procedure TestUseMissingVersion;
var Cmd: TLazUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUseCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('use no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('use no args shows error', StdErr.Contains('version'));
  finally Cmd.Free; end;
end;

procedure TestUseUnexpectedArg;
var Cmd: TLazUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUseCommand.Create;
  try
    Ret := Cmd.Execute(['invalid-version', 'extra'], Ctx);
    Check('use unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUseUnknownOption;
var Cmd: TLazUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUseCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('use unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== current ===== }

procedure TestCurrentName;
var Cmd: TLazCurrentCommand;
begin
  Cmd := TLazCurrentCommand.Create;
  try Check('current: name', Cmd.Name = 'current'); finally Cmd.Free; end;
end;

procedure TestCurrentHelp;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('current --help EXIT_OK', Ret = EXIT_OK);
    Check('current --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestCurrentNoArgs;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('current no args EXIT_OK', Ret = EXIT_OK);
    Check('current no args produces output', Length(StdOut.GetBuffer) > 0);
  finally Cmd.Free; end;
end;

procedure TestCurrentJsonOutput;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('current --json EXIT_OK', Ret = EXIT_OK);
    Check('current --json has has_default', StdOut.Contains('has_default'));
  finally Cmd.Free; end;
end;

procedure TestCurrentUnexpectedArg;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('current unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestCurrentUnknownOption;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('current unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== show ===== }

procedure TestShowName;
var Cmd: TLazShowCommand;
begin
  Cmd := TLazShowCommand.Create;
  try Check('show: name', Cmd.Name = 'show'); finally Cmd.Free; end;
end;

procedure TestShowHelp;
var Cmd: TLazShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazShowCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('show --help EXIT_OK', Ret = EXIT_OK);
    Check('show --help shows usage', StdOut.Contains('show'));
  finally Cmd.Free; end;
end;

procedure TestShowMissingVersion;
var Cmd: TLazShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazShowCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('show no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestShowUnsupportedVersion;
var
  Cmd: TLazShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazShowCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    Check('show unsupported version EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('show unsupported version writes stderr', StdErr.Contains('Unsupported Lazarus version'));
    Check('show unsupported version does not write error to stdout',
      not StdOut.Contains('Unsupported Lazarus version'));
  finally
    Cmd.Free;
  end;
end;

procedure TestShowUnexpectedArg;
var Cmd: TLazShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazShowCommand.Create;
  try
    Ret := Cmd.Execute(['invalid-version', 'extra'], Ctx);
    Check('show unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestShowUnknownOption;
var Cmd: TLazShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazShowCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('show unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== configure ===== }

procedure TestConfigureName;
var Cmd: TLazConfigureCommand;
begin
  Cmd := TLazConfigureCommand.Create;
  try Check('configure: name', Cmd.Name = 'configure'); finally Cmd.Free; end;
end;

procedure TestConfigureHelp;
var Cmd: TLazConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('configure --help EXIT_OK', Ret = EXIT_OK);
    Check('configure --help shows usage', StdOut.Contains('configure'));
  finally Cmd.Free; end;
end;

procedure TestConfigureMissingVersion;
var Cmd: TLazConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazConfigureCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('configure no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestConfigureUnexpectedArg;
var Cmd: TLazConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['invalid-version', 'extra'], Ctx);
    Check('configure unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestConfigureUnknownOption;
var Cmd: TLazConfigureCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('configure unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== doctor ===== }

procedure TestDoctorName;
var Cmd: TLazarusDoctorCommand;
begin
  Cmd := TLazarusDoctorCommand.Create;
  try Check('doctor: name', Cmd.Name = 'doctor'); finally Cmd.Free; end;
end;

procedure TestDoctorHelp;
var Cmd: TLazarusDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazarusDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('doctor --help EXIT_OK', Ret = EXIT_OK);
    Check('doctor --help shows usage', StdOut.Contains('doctor'));
  finally Cmd.Free; end;
end;

procedure TestDoctorExecution;
var Cmd: TLazarusDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazarusDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('doctor returns valid exit code', Ret >= 0);
    Check('doctor produces output', Length(StdOut.GetBuffer + StdErr.GetBuffer) > 0);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnexpectedArg;
var Cmd: TLazarusDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazarusDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('doctor unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnknownOption;
var Cmd: TLazarusDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazarusDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('doctor unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestDoctorUnwritableInstallRoot;
var
  Cmd: TLazarusDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Settings: TFPDevSettings;
  ReadOnlyRoot: string;
begin
  {$IFDEF UNIX}
  ReadOnlyRoot := GTempDir + PathDelim + 'lazarus_doctor_ro';
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

  Cmd := TLazarusDoctorCommand.Create;
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

{ ===== run ===== }

procedure TestRunName;
var Cmd: TLazRunCommand;
begin
  Cmd := TLazRunCommand.Create;
  try Check('run: name', Cmd.Name = 'run'); finally Cmd.Free; end;
end;

procedure TestRunHelp;
var Cmd: TLazRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazRunCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('run --help EXIT_OK', Ret = EXIT_OK);
    Check('run --help shows usage', StdOut.Contains('run'));
  finally Cmd.Free; end;
end;

procedure TestRunUnexpectedArg;
var Cmd: TLazRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazRunCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.0', 'extra'], Ctx);
    Check('run unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRunUnknownOption;
var Cmd: TLazRunCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazRunCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('run unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== uninstall ===== }

procedure TestUninstallName;
var Cmd: TLazUninstallCommand;
begin
  Cmd := TLazUninstallCommand.Create;
  try Check('uninstall: name', Cmd.Name = 'uninstall'); finally Cmd.Free; end;
end;

procedure TestUninstallHelp;
var Cmd: TLazUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('uninstall --help EXIT_OK', Ret = EXIT_OK);
    Check('uninstall --help shows usage', StdOut.Contains('uninstall'));
  finally Cmd.Free; end;
end;

procedure TestUninstallMissingVersion;
var Cmd: TLazUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUninstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('uninstall no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnexpectedArg;
var Cmd: TLazUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['invalid-version', 'extra'], Ctx);
    Check('uninstall unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUninstallUnknownOption;
var Cmd: TLazUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('uninstall unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== update ===== }

procedure TestUpdateName;
var Cmd: TLazUpdateCommand;
begin
  Cmd := TLazUpdateCommand.Create;
  try Check('update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestUpdateHelp;
var Cmd: TLazUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
  finally Cmd.Free; end;
end;

procedure TestUpdateUnexpectedArg;
var Cmd: TLazUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.0', 'extra'], Ctx);
    Check('update unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestUpdateUnknownOption;
var Cmd: TLazUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('update unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== test ===== }

procedure TestTestName;
var Cmd: TLazTestCommand;
begin
  Cmd := TLazTestCommand.Create;
  try Check('test: name', Cmd.Name = 'test'); finally Cmd.Free; end;
end;

procedure TestTestHelp;
var Cmd: TLazTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('test --help EXIT_OK', Ret = EXIT_OK);
    Check('test --help shows usage', StdOut.Contains('test'));
  finally Cmd.Free; end;
end;

procedure TestTestMissingVersion;
var Cmd: TLazTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazTestCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('test no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestTestUnexpectedArg;
var Cmd: TLazTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazTestCommand.Create;
  try
    Ret := Cmd.Execute(['invalid-version', 'extra'], Ctx);
    Check('test unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestTestUnknownOption;
var Cmd: TLazTestCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazTestCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('test unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestLazarusRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundInstall, FoundList, FoundUse, FoundCurrent, FoundShow: Boolean;
  FoundConfigure, FoundDoctor, FoundRun, FoundUninstall, FoundUpdate, FoundTest: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['lazarus']);
  FoundInstall := False; FoundList := False; FoundUse := False;
  FoundCurrent := False; FoundShow := False; FoundConfigure := False;
  FoundDoctor := False; FoundRun := False; FoundUninstall := False;
  FoundUpdate := False; FoundTest := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'install' then FoundInstall := True;
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'use' then FoundUse := True;
    if Children[I] = 'current' then FoundCurrent := True;
    if Children[I] = 'show' then FoundShow := True;
    if Children[I] = 'configure' then FoundConfigure := True;
    if Children[I] = 'doctor' then FoundDoctor := True;
    if Children[I] = 'run' then FoundRun := True;
    if Children[I] = 'uninstall' then FoundUninstall := True;
    if Children[I] = 'update' then FoundUpdate := True;
    if Children[I] = 'test' then FoundTest := True;
  end;

  Check('lazarus install registered', FoundInstall);
  Check('lazarus list registered', FoundList);
  Check('lazarus use registered', FoundUse);
  Check('lazarus current registered', FoundCurrent);
  Check('lazarus show registered', FoundShow);
  Check('lazarus configure registered', FoundConfigure);
  Check('lazarus doctor registered', FoundDoctor);
  Check('lazarus run registered', FoundRun);
  Check('lazarus uninstall registered', FoundUninstall);
  Check('lazarus update registered', FoundUpdate);
  Check('lazarus test registered', FoundTest);
end;

{ ===== Main ===== }
begin
  WriteLn('=== Lazarus Commands CLI Tests (B191-B192) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_lazarus');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- install ---');
    TestInstallName;
    TestInstallHelp;
    TestInstallHelpShort;
    TestInstallHelpUnexpectedArg;
    TestInstallMissingVersion;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListJsonOutput;
    TestListUnexpectedArg;
    TestListUnknownOption;

    WriteLn('');
    WriteLn('--- use ---');
    TestUseName;
    TestUseAlias;
    TestUseHelp;
    TestUseMissingVersion;
    TestUseUnexpectedArg;
    TestUseUnknownOption;

    WriteLn('');
    WriteLn('--- current ---');
    TestCurrentName;
    TestCurrentHelp;
    TestCurrentNoArgs;
    TestCurrentJsonOutput;
    TestCurrentUnexpectedArg;
    TestCurrentUnknownOption;

    WriteLn('');
    WriteLn('--- show ---');
    TestShowName;
    TestShowHelp;
    TestShowMissingVersion;
    TestShowUnsupportedVersion;
    TestShowUnexpectedArg;
    TestShowUnknownOption;

    WriteLn('');
    WriteLn('--- configure ---');
    TestConfigureName;
    TestConfigureHelp;
    TestConfigureMissingVersion;
    TestConfigureUnexpectedArg;
    TestConfigureUnknownOption;

    WriteLn('');
    WriteLn('--- doctor ---');
    TestDoctorName;
    TestDoctorHelp;
    TestDoctorExecution;
    TestDoctorUnexpectedArg;
    TestDoctorUnknownOption;
    TestDoctorUnwritableInstallRoot;

    WriteLn('');
    WriteLn('--- run ---');
    TestRunName;
    TestRunHelp;
    TestRunUnexpectedArg;
    TestRunUnknownOption;

    WriteLn('');
    WriteLn('--- uninstall ---');
    TestUninstallName;
    TestUninstallHelp;
    TestUninstallMissingVersion;
    TestUninstallUnexpectedArg;
    TestUninstallUnknownOption;

    WriteLn('');
    WriteLn('--- update ---');
    TestUpdateName;
    TestUpdateHelp;
    TestUpdateUnexpectedArg;
    TestUpdateUnknownOption;

    WriteLn('');
    WriteLn('--- test ---');
    TestTestName;
    TestTestHelp;
    TestTestMissingVersion;
    TestTestUnexpectedArg;
    TestTestUnknownOption;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestLazarusRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
