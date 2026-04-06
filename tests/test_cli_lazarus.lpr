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
  SysUtils, Classes, Process,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.i18n, fpdev.i18n.strings,
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

function SetInstallRoot(const Ctx: IContext; const AInstallRoot: string): Boolean;
var
  Settings: TFPDevSettings;
begin
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.InstallRoot := AInstallRoot;
  Result := Ctx.Config.GetSettingsManager.SetSettings(Settings);
end;

function RunCommandInDir(const AExecutable: string; const AArgs: array of string;
  const AWorkDir: string): Boolean;
var
  Proc: TProcess;
  I: Integer;
begin
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := AExecutable;
    Proc.CurrentDirectory := AWorkDir;
    Proc.Options := [poWaitOnExit];
    for I := Low(AArgs) to High(AArgs) do
      Proc.Parameters.Add(AArgs[I]);
    try
      Proc.Execute;
      Result := Proc.ExitStatus = 0;
    except
      Result := False;
    end;
  finally
    Proc.Free;
  end;
end;

procedure WriteTextFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

function ConfigureGitUser(const ARepoDir: string): Boolean;
begin
  Result :=
    RunCommandInDir('git', ['config', 'user.name', 'FPDev Test'], ARepoDir) and
    RunCommandInDir('git', ['config', 'user.email', 'fpdev-test@example.invalid'], ARepoDir);
end;

function CommitAll(const ARepoDir, AMessage: string): Boolean;
begin
  Result :=
    RunCommandInDir('git', ['add', '-A'], ARepoDir) and
    RunCommandInDir('git', ['commit', '-m', AMessage], ARepoDir);
end;

function SetupTrackedLazarusSourceRepo(const AInstallRoot, AVersion: string;
  out ASourceDir, ASeedDir: string): Boolean;
var
  FixtureRoot: string;
  RemoteBareDir: string;
begin
  Result := False;
  ASourceDir := AInstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-' + AVersion;
  FixtureRoot := AInstallRoot + PathDelim + '_git_fixture';
  ASeedDir := FixtureRoot + PathDelim + 'seed';
  RemoteBareDir := FixtureRoot + PathDelim + 'remote.git';

  ForceDirectories(AInstallRoot);
  if not RunCommandInDir('git', ['init', '--bare', '--initial-branch=main', RemoteBareDir], GTempDir) then
    Exit;
  if not RunCommandInDir('git', ['clone', RemoteBareDir, ASeedDir], GTempDir) then
    Exit;
  if not ConfigureGitUser(ASeedDir) then
    Exit;

  ForceDirectories(ASeedDir + PathDelim + 'ide');
  ForceDirectories(ASeedDir + PathDelim + 'lcl');
  ForceDirectories(ASeedDir + PathDelim + 'packager');
  WriteTextFile(ASeedDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'base' + LineEnding);
  WriteTextFile(ASeedDir + PathDelim + 'lcl' + PathDelim + '.keep', 'keep' + LineEnding);
  WriteTextFile(ASeedDir + PathDelim + 'packager' + PathDelim + '.keep', 'keep' + LineEnding);
  if not CommitAll(ASeedDir, 'initial commit') then
    Exit;
  if not RunCommandInDir('git', ['branch', '-M', 'main'], ASeedDir) then
    Exit;
  if not RunCommandInDir('git', ['push', '-u', 'origin', 'main'], ASeedDir) then
    Exit;

  ForceDirectories(ExtractFileDir(ASourceDir));
  if not RunCommandInDir('git', ['clone', RemoteBareDir, ASourceDir], GTempDir) then
    Exit;
  if not ConfigureGitUser(ASourceDir) then
    Exit;

  Result := True;
end;

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

procedure TestInstallUnsupportedVersionDoesNotAppendGenericFailure;
var
  Cmd: TLazInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['9.9'], Ctx);
    Check('install unsupported version EXIT_ERROR', Ret = EXIT_ERROR);
    Check('install unsupported version emits concrete error',
      StdErr.Contains(_Fmt(CMD_LAZARUS_UNSUPPORTED_VERSION, ['9.9'])));
    Check('install unsupported version does not append generic failure',
      StdErr.LineCount = 1);
    Check('install unsupported version keeps start banner',
      StdOut.Contains(_Fmt(CMD_LAZARUS_INSTALL_START, ['9.9'])));
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallInvalidJobsValue;
var
  Cmd: TLazInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['9.9', '--jobs=abc'], Ctx);
    Check('install invalid --jobs EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('install invalid --jobs shows usage', StdErr.Contains('install'));
    Check('install invalid --jobs keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallInvalidFromMode;
var
  Cmd: TLazInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['9.9', '--from=garbage'], Ctx);
    Check('install invalid --from EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('install invalid --from shows usage', StdErr.Contains('install'));
    Check('install invalid --from keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallEmptyFPCValue;
var
  Cmd: TLazInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazInstallCommand.Create;
  try
    Ret := Cmd.Execute(['9.9', '--fpc='], Ctx);
    Check('install empty --fpc EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('install empty --fpc shows usage', StdErr.Contains('install'));
    Check('install empty --fpc keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
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

procedure TestListJsonOutputUsesNullWhenDefaultUnset;
var
  Cmd: TLazListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json default-unset EXIT_OK', Ret = EXIT_OK);
    Check('list --json default-unset uses has_default false',
      StdOut.Contains('"has_default" : false'));
    Check('list --json default-unset uses null default',
      StdOut.Contains('"default" : null'));
  finally
    Cmd.Free;
  end;
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

procedure TestCurrentHelpAdvertisesJsonUsage;
var
  Cmd: TLazCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('current --help usage advertises --json', Ret = EXIT_OK);
    Check('current --help usage advertises optional json flag',
      StdOut.Contains('Usage: fpdev lazarus current [--json]'));
  finally
    Cmd.Free;
  end;
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

procedure TestCurrentJsonOutputUsesNullWhenDefaultUnset;
var
  Cmd: TLazCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('current --json default-unset EXIT_OK', Ret = EXIT_OK);
    Check('current --json default-unset uses has_default false',
      StdOut.Contains('"has_default" : false'));
    Check('current --json default-unset uses null version',
      StdOut.Contains('"version" : null'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentUnexpectedArg;
var Cmd: TLazCurrentCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('current unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('current unexpected arg usage advertises optional json flag',
      StdErr.Contains('Usage: fpdev lazarus current [--json]'));
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

procedure TestConfigureMissingInstallDoesNotAppendGenericFailure;
var
  Cmd: TLazConfigureCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazConfigureCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('configure missing install EXIT_ERROR', Ret = EXIT_ERROR);
    Check('configure missing install emits concrete error',
      StdErr.Contains(_Fmt(CMD_LAZARUS_USE_NOT_INSTALLED, ['3.0'])));
    Check('configure missing install does not append generic failed',
      StdErr.LineCount = 1);
    Check('configure missing install keeps start banner',
      StdOut.Contains(_Fmt(CMD_LAZARUS_CONFIG_START, ['3.0'])));
  finally
    Cmd.Free;
  end;
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

procedure TestRunMissingCurrentVersionWritesErrorToStderr;
var
  Cmd: TLazRunCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazRunCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('run missing current version EXIT_ERROR', Ret = EXIT_ERROR);
    Check('run missing current version writes stderr',
      StdErr.Contains(_(CMD_LAZARUS_RUN_NO_VERSION)));
    Check('run missing current version keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestRunMissingInstallWritesErrorToStderr;
var
  Cmd: TLazRunCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TLazRunCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.0'], Ctx);
    Check('run missing install EXIT_ERROR', Ret = EXIT_ERROR);
    Check('run missing install writes stderr',
      StdErr.Contains(_Fmt(CMD_LAZARUS_RUN_NOT_INSTALLED, ['3.2.0'])));
    Check('run missing install keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
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

procedure TestUpdateMissingSourceDoesNotAppendGenericFailure;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_missing_installroot';
  ForceDirectories(InstallRoot);

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update missing source setup install root', False);
    Exit;
  end;

  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-3.0';
  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update missing source EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update missing source emits concrete error',
      StdErr.Contains(_Fmt(CMD_LAZARUS_SOURCE_DIR_NOT_FOUND, [SourceDir])));
    Check('update missing source does not append generic failed',
      StdErr.LineCount = 1);
    Check('update missing source keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateLocalOnlyDoesNotAppendGenericSuccess;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_local_only_installroot';
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'lazarus-3.0';
  ForceDirectories(SourceDir + PathDelim + 'ide');
  ForceDirectories(SourceDir + PathDelim + 'lcl');
  ForceDirectories(SourceDir + PathDelim + 'packager');

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update local-only setup install root', False);
    Exit;
  end;

  if not RunCommandInDir('git', ['init'], SourceDir) then
  begin
    Check('update local-only setup git init', False);
    Exit;
  end;

  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update local-only EXIT_OK', Ret = EXIT_OK);
    Check('update local-only emits local-only status',
      StdOut.Contains(_(MSG_LAZARUS_SOURCE_LOCAL_ONLY) + ' ' + SourceDir));
    Check('update local-only does not append generic success',
      StdOut.LineCount = 1);
    Check('update local-only keeps stderr empty',
      Trim(StdErr.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDirtyWorktreeShowsNormalizedPullFailure;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
  SeedDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_dirty_installroot';

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update dirty setup install root', False);
    Exit;
  end;
  if not SetupTrackedLazarusSourceRepo(InstallRoot, '3.0', SourceDir, SeedDir) then
  begin
    Check('update dirty setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'remote-change' + LineEnding);
  if not CommitAll(SeedDir, 'remote change') then
  begin
    Check('update dirty setup remote commit', False);
    Exit;
  end;
  if not RunCommandInDir('git', ['push'], SeedDir) then
  begin
    Check('update dirty setup remote push', False);
    Exit;
  end;

  WriteTextFile(SourceDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'local-uncommitted' + LineEnding);

  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update dirty EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update dirty emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_LAZARUS_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIRTY_WORKTREE)])));
    Check('update dirty keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDetachedHeadShowsNormalizedPullFailure;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
  SeedDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_detached_installroot';

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update detached setup install root', False);
    Exit;
  end;
  if not SetupTrackedLazarusSourceRepo(InstallRoot, '3.0', SourceDir, SeedDir) then
  begin
    Check('update detached setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'remote-change' + LineEnding);
  if not CommitAll(SeedDir, 'remote change') then
  begin
    Check('update detached setup remote commit', False);
    Exit;
  end;
  if not RunCommandInDir('git', ['push'], SeedDir) then
  begin
    Check('update detached setup remote push', False);
    Exit;
  end;
  if not RunCommandInDir('git', ['checkout', '--detach', 'HEAD'], SourceDir) then
  begin
    Check('update detached setup checkout detach', False);
    Exit;
  end;

  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update detached EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update detached emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_LAZARUS_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DETACHED_HEAD)])));
    Check('update detached keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDivergedConflictShowsNormalizedPullFailure;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
  SeedDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_diverged_installroot';

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update diverged setup install root', False);
    Exit;
  end;
  if not SetupTrackedLazarusSourceRepo(InstallRoot, '3.0', SourceDir, SeedDir) then
  begin
    Check('update diverged setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SourceDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'local-commit' + LineEnding);
  if not CommitAll(SourceDir, 'local change') then
  begin
    Check('update diverged setup local commit', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'ide' + PathDelim + 'README.txt', 'remote-commit' + LineEnding);
  if not CommitAll(SeedDir, 'remote change') then
  begin
    Check('update diverged setup remote commit', False);
    Exit;
  end;
  if not RunCommandInDir('git', ['push'], SeedDir) then
  begin
    Check('update diverged setup remote push', False);
    Exit;
  end;

  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update diverged EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update diverged emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_LAZARUS_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIVERGED_HISTORY)])));
    Check('update diverged keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateNonConflictingDivergedHistoryFailsFastForwardOnly;
var
  Cmd: TLazUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
  SeedDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_ffonly_diverged_installroot';

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update ff-only diverged setup install root', False);
    Exit;
  end;
  if not SetupTrackedLazarusSourceRepo(InstallRoot, '3.0', SourceDir, SeedDir) then
  begin
    Check('update ff-only diverged setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SourceDir + PathDelim + 'local.txt', 'local-commit' + LineEnding);
  if not CommitAll(SourceDir, 'local change') then
  begin
    Check('update ff-only diverged setup local commit', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'remote.txt', 'remote-commit' + LineEnding);
  if not CommitAll(SeedDir, 'remote change') then
  begin
    Check('update ff-only diverged setup remote commit', False);
    Exit;
  end;
  if not RunCommandInDir('git', ['push'], SeedDir) then
  begin
    Check('update ff-only diverged setup remote push', False);
    Exit;
  end;

  Cmd := TLazUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.0'], Ctx);
    Check('update ff-only diverged EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update ff-only diverged emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_LAZARUS_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIVERGED_HISTORY)])));
    Check('update ff-only diverged keeps stdout empty',
      Trim(StdOut.GetBuffer) = '');
    Check('update ff-only diverged keeps local-only file',
      FileExists(SourceDir + PathDelim + 'local.txt'));
    Check('update ff-only diverged does not materialize remote file',
      not FileExists(SourceDir + PathDelim + 'remote.txt'));
  finally
    Cmd.Free;
  end;
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
    TestInstallInvalidJobsValue;
    TestInstallInvalidFromMode;
    TestInstallEmptyFPCValue;
    TestInstallUnsupportedVersionDoesNotAppendGenericFailure;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListHelp;
    TestListJsonOutput;
    TestListJsonOutputUsesNullWhenDefaultUnset;
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
    TestCurrentHelpAdvertisesJsonUsage;
    TestCurrentNoArgs;
    TestCurrentJsonOutput;
    TestCurrentJsonOutputUsesNullWhenDefaultUnset;
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
    TestConfigureMissingInstallDoesNotAppendGenericFailure;

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
    TestRunMissingCurrentVersionWritesErrorToStderr;
    TestRunMissingInstallWritesErrorToStderr;

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
    TestUpdateMissingSourceDoesNotAppendGenericFailure;
    TestUpdateLocalOnlyDoesNotAppendGenericSuccess;
    TestUpdateDirtyWorktreeShowsNormalizedPullFailure;
    TestUpdateDetachedHeadShowsNormalizedPullFailure;
    TestUpdateDivergedConflictShowsNormalizedPullFailure;
    TestUpdateNonConflictingDivergedHistoryFailsFastForwardOnly;

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
