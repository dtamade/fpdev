program test_cli_cross;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_cross - CLI tests for all cross sub-commands
================================================================================

  Covers: list, show, enable, disable, install, uninstall, configure,
          build, doctor, test

  B193-B195: Cross command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
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
  test_cli_helpers;

var
  GTempDir: string;

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

{ ===== Registration ===== }

procedure TestCrossRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundShow, FoundEnable, FoundDisable: Boolean;
  FoundInstall, FoundUninstall, FoundConfigure, FoundBuild: Boolean;
  FoundDoctor, FoundTest: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['cross']);
  FoundList := False; FoundShow := False; FoundEnable := False;
  FoundDisable := False; FoundInstall := False; FoundUninstall := False;
  FoundConfigure := False; FoundBuild := False; FoundDoctor := False;
  FoundTest := False;

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
end;

{ ===== Main ===== }
begin
  WriteLn('=== Cross Commands CLI Tests (B193-B195) ===');
  WriteLn;

  GTempDir := GetTempDir + 'fpdev_test_cross_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListNoArgs;
    TestListJsonOutput;

    WriteLn('');
    WriteLn('--- show ---');
    TestShowName;
    TestShowHelp;
    TestShowMissingTarget;

    WriteLn('');
    WriteLn('--- enable ---');
    TestEnableName;
    TestEnableHelp;
    TestEnableMissingTarget;

    WriteLn('');
    WriteLn('--- disable ---');
    TestDisableName;
    TestDisableHelp;
    TestDisableMissingTarget;

    WriteLn('');
    WriteLn('--- install ---');
    TestInstallName;
    TestInstallHelp;
    TestInstallMissingTarget;

    WriteLn('');
    WriteLn('--- uninstall ---');
    TestUninstallName;
    TestUninstallHelp;
    TestUninstallMissingTarget;

    WriteLn('');
    WriteLn('--- configure ---');
    TestConfigureName;
    TestConfigureHelp;
    TestConfigureMissingTarget;

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

    WriteLn('');
    WriteLn('--- test ---');
    TestTestName;
    TestTestHelp;
    TestTestMissingTarget;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestCrossRegistration;
  finally
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'config.json');
      RemoveDir(GTempDir);
    end;
  end;

  Halt(PrintTestSummary);
end.
