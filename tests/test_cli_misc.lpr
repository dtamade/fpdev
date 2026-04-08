program test_cli_misc;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_misc - CLI tests for remaining top-level commands
================================================================================

  Covers: config, config list, repo (list/add/remove/show/default/versions/help),
          env, version, help, doctor, index, cache, perf (report/summary/clear/save)

  B200: Config/Repo/Env/Other command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.output.intf,
  fpdev.cli.global,
  fpdev.exitcodes,
  fpdev.paths,
  fpdev.utils,
  fpdev.cmd.config,
  fpdev.cmd.config.show,
  fpdev.cmd.config.get,
  fpdev.cmd.config.setvalue,
  fpdev.cmd.config.export,
  fpdev.cmd.config.import,
  fpdev.cmd.config.list,
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.use,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help,
  fpdev.cmd.env,
  fpdev.cmd.env.data_root,
  fpdev.cmd.system.help,
  fpdev.cmd.system.version,
  fpdev.cmd.system.toolchain.root,
  fpdev.cmd.system.toolchain.check,
  fpdev.cmd.system.toolchain.self_test,
  fpdev.cmd.system.toolchain.fetch,
  fpdev.cmd.system.toolchain.extract,
  fpdev.cmd.system.toolchain.ensure_source,
  fpdev.cmd.system.toolchain.import_bundle,
  fpdev.cmd.env.vars,
  fpdev.cmd.env.path,
  fpdev.cmd.env.export,
  fpdev.cmd.doctor,
  fpdev.cmd.index,
  fpdev.cmd.cache,
  fpdev.cmd.perf,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

function MakeArgs(const AValues: array of string): TStringArray;
var
  I: Integer;
begin
  Initialize(Result);
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

{$I test_cli_internal.inc}

{ ===== config ===== }

procedure TestConfigName;
var Cmd: TConfigCommand;
begin
  Cmd := TConfigCommand.Create;
  try Check('config: name', Cmd.Name = 'config'); finally Cmd.Free; end;
end;

procedure TestConfigHelp;
var Cmd: TConfigCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('config --help EXIT_OK', Ret = EXIT_OK);
    Check('config --help writes usage', StdOut.Contains('Usage: fpdev system config'));
  finally Cmd.Free; end;
end;

procedure TestConfigNoArgs;
var Cmd: TConfigCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('config no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestConfigHelpUnexpectedArg;
var Cmd: TConfigCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigCommand.Create;
  try
    Ret := Cmd.Execute(['help', 'extra'], Ctx);
    Check('config help unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestConfigShowUnexpectedArg;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'config', 'show', 'extra'], Ctx);
  Check('config show unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestConfigGetUnexpectedArg;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'config', 'get', 'mirror', 'extra'], Ctx);
  Check('config get unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestConfigSetUnexpectedArg;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'config', 'set', 'mirror', 'auto', 'extra'], Ctx);
  Check('config set unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestConfigGetUnknownKey;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'config', 'get', 'unknown_key'], Ctx);
  Check('config get unknown key EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  Check('config get unknown key writes error', StdErr.Contains('Unknown configuration key'));
end;

procedure TestConfigSetInvalidMirror;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'config', 'set', 'mirror', 'not-a-valid-mirror'], Ctx);
  Check('config set invalid mirror EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  Check('config set invalid mirror writes error', StdErr.Contains('Invalid mirror value'));
end;

{ ===== config list ===== }

procedure TestConfigListName;
var Cmd: TConfigListCommand;
begin
  Cmd := TConfigListCommand.Create;
  try Check('config list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestConfigListAlias;
var Cmd: TConfigListCommand; A: TStringArray;
begin
  Cmd := TConfigListCommand.Create;
  try
    A := Cmd.Aliases;
    Check('config list: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestConfigListHelp;
var Cmd: TConfigListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('config list --help EXIT_OK', Ret = EXIT_OK);
    Check('config list --help shows --fpc', StdOut.Contains('fpc'));
  finally Cmd.Free; end;
end;

procedure TestConfigListHelpRejectsExtraOption;
var Cmd: TConfigListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigListCommand.Create;
  try
    Ret := Cmd.Execute(['--help', '--fpc'], Ctx);
    Check('config list --help with extra option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('config list --help with extra option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
    Check('config list --help with extra option writes usage to stderr',
      Pos('Usage: fpdev system config list [options]', StdErr.GetBuffer) > 0);
  finally Cmd.Free; end;
end;

procedure TestConfigListNoArgs;
var Cmd: TConfigListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('config list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestConfigListUnknownOption;
var Cmd: TConfigListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TConfigListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('config list unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo list ===== }

procedure TestRepoListName;
var Cmd: TRepoListCommand;
begin
  Cmd := TRepoListCommand.Create;
  try Check('repo list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestRepoListHelp;
var Cmd: TRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo list --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoListNoArgs;
var Cmd: TRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoListUnexpectedArg;
var Cmd: TRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('repo list unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo add ===== }

procedure TestRepoAddName;
var Cmd: TRepoAddCommand;
begin
  Cmd := TRepoAddCommand.Create;
  try Check('repo add: name', Cmd.Name = 'add'); finally Cmd.Free; end;
end;

procedure TestRepoAddHelp;
var Cmd: TRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo add --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoAddMissingArgs;
var Cmd: TRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoAddCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo add no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoAddUnexpectedArg;
var Cmd: TRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['demo', 'https://example.com/repo.json', 'extra'], Ctx);
    Check('repo add unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoAddDuplicateRepo;
var
  Cmd: TRepoAddCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['dup_repo', 'https://example.com/repo-a.json'], Ctx);
    Check('repo add first add EXIT_OK', Ret = EXIT_OK);

    Ret := Cmd.Execute(['dup_repo', 'https://example.com/repo-b.json'], Ctx);
    Check('repo add duplicate EXIT_ALREADY_EXISTS', Ret = EXIT_ALREADY_EXISTS);
    Check('repo add duplicate writes stderr',
      Pos('exist', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== repo remove ===== }

procedure TestRepoRemoveName;
var Cmd: TRepoRemoveCommand;
begin
  Cmd := TRepoRemoveCommand.Create;
  try Check('repo remove: name', Cmd.Name = 'remove'); finally Cmd.Free; end;
end;

procedure TestRepoRemoveAlias;
var Cmd: TRepoRemoveCommand; A: TStringArray;
begin
  Cmd := TRepoRemoveCommand.Create;
  try
    A := Cmd.Aliases;
    Check('repo remove: has no alias', A = nil);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveHelp;
var Cmd: TRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo remove --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveMissing;
var Cmd: TRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo remove no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveUnexpectedArg;
var Cmd: TRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_remove', 'extra'], Ctx);
    Check('repo remove unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveUnknownRepo;
var
  Cmd: TRepoRemoveCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_remove'], Ctx);
    Check('repo remove unknown repo EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('repo remove unknown repo writes stderr', Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== repo show ===== }

procedure TestRepoShowName;
var Cmd: TRepoShowCommand;
begin
  Cmd := TRepoShowCommand.Create;
  try Check('repo show: name', Cmd.Name = 'show'); finally Cmd.Free; end;
end;

procedure TestRepoShowHelp;
var Cmd: TRepoShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoShowCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo show --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoShowMissing;
var Cmd: TRepoShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoShowCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo show no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoShowUnexpectedArg;
var Cmd: TRepoShowCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoShowCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_show', 'extra'], Ctx);
    Check('repo show unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoShowUnknownRepo;
var
  Cmd: TRepoShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoShowCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_show'], Ctx);
    Check('repo show unknown repo EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('repo show unknown repo writes stderr', Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoShowCurrentRepo;
var
  Cmd: TRepoShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Settings: TFPDevSettings;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not Ctx.Config.GetRepositoryManager.AddRepository('current_repo', 'https://example.com/current.json') then
  begin
    Check('repo show current setup add repo', False);
    Exit;
  end;
  Settings := Ctx.Config.GetSettingsManager.GetSettings;
  Settings.DefaultRepo := 'current_repo';
  if not Ctx.Config.GetSettingsManager.SetSettings(Settings) then
  begin
    Check('repo show current setup set default repo', False);
    Exit;
  end;

  Cmd := TRepoShowCommand.Create;
  try
    Ret := Cmd.Execute(['current'], Ctx);
    Check('repo show current EXIT_OK', Ret = EXIT_OK);
    Check('repo show current prints selected repo', Pos('current_repo = https://example.com/current.json', StdOut.GetBuffer) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== repo use ===== }

procedure TestRepoUseName;
var Cmd: TRepoUseCommand;
begin
  Cmd := TRepoUseCommand.Create;
  try Check('repo use: name', Cmd.Name = 'use'); finally Cmd.Free; end;
end;

procedure TestRepoUseHelp;
var Cmd: TRepoUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoUseCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo use --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoUseMissing;
var Cmd: TRepoUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoUseCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo use no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoUseUnexpectedArg;
var Cmd: TRepoUseCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoUseCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_use', 'extra'], Ctx);
    Check('repo use unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoUseUnknownRepo;
var
  Cmd: TRepoUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoUseCommand.Create;
  try
    Ret := Cmd.Execute(['missing_repo_for_use'], Ctx);
    Check('repo use unknown repo EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('repo use unknown repo writes stderr', Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== repo versions ===== }

procedure TestRepoVersionsName;
var Cmd: TRepoVersionsCommand;
begin
  Cmd := TRepoVersionsCommand.Create;
  try Check('repo versions: name', Cmd.Name = 'versions'); finally Cmd.Free; end;
end;

procedure TestRepoVersionsHelp;
var Cmd: TRepoVersionsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo versions --help EXIT_OK', Ret = EXIT_OK);
    Check('repo versions --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestRepoVersionsNoArgs;
var Cmd: TRepoVersionsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo versions no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestRepoVersionsUnexpectedArg;
var Cmd: TRepoVersionsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('repo versions unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoVersionsUnknownFlag;
var Cmd: TRepoVersionsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('repo versions unknown flag EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

procedure TestRepoVersionsUnknownRepo;
var
  Cmd: TRepoVersionsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute(['--repo=missing_repo_for_versions'], Ctx);
    Check('repo versions unknown repo EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('repo versions unknown repo writes stderr', Pos('not found', LowerCase(StdErr.GetBuffer)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestRepoVersionsParseFailureExitCode;
var
  Cmd: TRepoVersionsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  BadManifestPath: string;
  SL: TStringList;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  BadManifestPath := GTempDir + PathDelim + 'repo_versions_bad_manifest.json';
  SL := TStringList.Create;
  try
    SL.Text := '{ invalid json';
    SL.SaveToFile(BadManifestPath);
  finally
    SL.Free;
  end;

  if not Ctx.Config.GetRepositoryManager.AddRepository('bad_manifest_repo', BadManifestPath) then
  begin
    Check('repo versions parse fail setup add repo', False);
    Exit;
  end;

  Cmd := TRepoVersionsCommand.Create;
  try
    Ret := Cmd.Execute(['--repo=bad_manifest_repo'], Ctx);
    Check('repo versions bad manifest EXIT_ERROR', Ret = EXIT_ERROR);
    Check('repo versions bad manifest writes stderr', Length(StdErr.GetBuffer) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== repo help ===== }

procedure TestRepoHelpName;
var Cmd: TRepoHelpCommand;
begin
  Cmd := TRepoHelpCommand.Create;
  try Check('repo help: name', Cmd.Name = 'help'); finally Cmd.Free; end;
end;

procedure TestRepoHelpNoArgs;
var Cmd: TRepoHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoHelpCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo help no args EXIT_OK', Ret = EXIT_OK);
    Check('repo help shows commands', StdOut.Contains('repo'));
  finally Cmd.Free; end;
end;

procedure TestRepoHelpUnexpectedArg;
var Cmd: TRepoHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoHelpCommand.Create;
  try
    Ret := Cmd.Execute(['add', 'extra'], Ctx);
    Check('repo help unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== env ===== }

procedure TestEnvName;
var Cmd: TEnvCommand;
begin
  Cmd := TEnvCommand.Create;
  try Check('env: name', Cmd.Name = 'env'); finally Cmd.Free; end;
end;

procedure TestEnvHelp;
var Cmd: TEnvCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TEnvCommand.Create;
  try
    Ret := Cmd.Execute(['help'], Ctx);
    Check('env help EXIT_OK', Ret = EXIT_OK);
    Check('env help shows usage', StdOut.Contains('env'));
  finally Cmd.Free; end;
end;

procedure TestEnvNoArgs;
var Cmd: TEnvCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TEnvCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('env no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestEnvVarsUnexpectedArg;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'env', 'vars', 'extra'], Ctx);
  Check('env vars unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestEnvExportUnknownOption;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'env', 'export', '--unknown'], Ctx);
  Check('env export unknown option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestEnvExportMissingShellValue;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'env', 'export', '--shell'], Ctx);
  Check('env export missing --shell value EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

procedure TestGlobalNormalizeLeadingPortable;
var
  Primary: string;
  Params: TStringArray;
  DispatchArgs: TStringArray;
begin
  NormalizePrimaryAndParams(MakeArgs(['--portable', 'fpc', 'list']), Primary, Params);
  DispatchArgs := BuildDispatchArgs(Primary, Params);
  Check('global normalize portable primary', Primary = 'fpc');
  Check('global normalize portable param count', Length(Params) = 1);
  Check('global normalize portable first param', Params[0] = 'list');
  Check('global dispatch args count', Length(DispatchArgs) = 2);
  Check('global dispatch arg0', DispatchArgs[0] = 'fpc');
  Check('global dispatch arg1', DispatchArgs[1] = 'list');
end;

procedure TestGlobalNormalizePortableOnly;
var
  Primary: string;
  Params: TStringArray;
  DispatchArgs: TStringArray;
begin
  NormalizePrimaryAndParams(MakeArgs(['--portable']), Primary, Params);
  DispatchArgs := BuildDispatchArgs(Primary, Params);
  Check('global normalize portable-only primary empty', Primary = '');
  Check('global normalize portable-only params empty', Length(Params) = 0);
  Check('global normalize portable-only dispatch empty', Length(DispatchArgs) = 0);
end;

procedure TestApplyPortableModeLeadingPreludeOnly;
begin
  SetPortableMode(False);
  ApplyPortableModeFromArgs(MakeArgs(['--portable', 'fpc', 'list']));
  Check('apply portable mode handles leading prelude', IsPortableMode);

  SetPortableMode(False);
  ApplyPortableModeFromArgs(MakeArgs(['fpc', 'list', '--portable']));
  Check('apply portable mode ignores non-leading portable flag', not IsPortableMode);
end;

{ ===== doctor ===== }

procedure TestDoctorName;
var Cmd: TDoctorCommand;
begin
  Cmd := TDoctorCommand.Create;
  try Check('doctor: name', Cmd.Name = 'doctor'); finally Cmd.Free; end;
end;

procedure TestDoctorHelp;
var Cmd: TDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('doctor --help EXIT_OK', Ret = EXIT_OK);
    Check('doctor --help shows --quick', StdOut.Contains('quick'));
  finally Cmd.Free; end;
end;

procedure TestDoctorHelpRejectsExtraOption;
var Cmd: TDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help', '--quick'], Ctx);
    Check('doctor --help with extra option EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('doctor --help with extra option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
    Check('doctor --help with extra option writes usage to stderr',
      Pos('Usage: fpdev system doctor', StdErr.GetBuffer) > 0);
  finally Cmd.Free; end;
end;

procedure TestDoctorNoArgs;
var Cmd: TDoctorCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('doctor no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestDoctorUsesSameProcessEnvOverride;
var
  Cmd: TDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ProbeDir: string;
  SavedFPCDir, SavedPP: string;
begin
  ProbeDir := CreateUniqueTempDir('fpdev_doctor_env_probe');
  SavedFPCDir := get_env('FPCDIR');
  SavedPP := get_env('PP');
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    set_env('FPCDIR', ProbeDir);
    set_env('PP', 'ppc-same-process-probe');

    Ret := Cmd.Execute(['--quick'], Ctx);
    Check('doctor --quick with same-process env override returns valid code', Ret >= 0);
    Check('doctor sees same-process FPCDIR override',
      StdOut.Contains('FPCDIR: ' + ProbeDir));
    Check('doctor sees same-process PP warning',
      StdOut.Contains('PP environment variable is set'));
  finally
    RestoreEnv('FPCDIR', SavedFPCDir);
    RestoreEnv('PP', SavedPP);
    CleanupTempDir(ProbeDir);
    Cmd.Free;
  end;
end;

procedure TestDoctorUsesSameProcessHomeForConfigAndInstallPaths;
var
  Cmd: TDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ProbeBaseDir: string;
  ProbeInstallRoot: string;
  ProbeConfigPath: string;
  SavedHome, SavedAppData: string;
  SavedDataRoot, SavedXDGDataHome: string;
  Settings: TFPDevSettings;
begin
  ProbeBaseDir := CreateUniqueTempDir('fpdev_doctor_home_probe');
  SavedHome := get_env('HOME');
  SavedAppData := get_env('APPDATA');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  SavedXDGDataHome := get_env('XDG_DATA_HOME');
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    Settings := Ctx.Config.GetSettingsManager.GetSettings;
    Settings.InstallRoot := '';
    if not Ctx.Config.GetSettingsManager.SetSettings(Settings) then
    begin
      Check('doctor same-process HOME setup clears install root', False);
      Exit;
    end;
    SetPortableMode(False);
    unset_env('FPDEV_DATA_ROOT');
    unset_env('XDG_DATA_HOME');

    {$IFDEF MSWINDOWS}
    ProbeInstallRoot := ProbeBaseDir + PathDelim + '.fpdev';
    ProbeConfigPath := ProbeInstallRoot + PathDelim + 'config.json';
    set_env('APPDATA', ProbeBaseDir);
    {$ELSE}
    ProbeInstallRoot := ProbeBaseDir + PathDelim + '.fpdev';
    ProbeConfigPath := ProbeInstallRoot + PathDelim + 'config.json';
    set_env('HOME', ProbeBaseDir);
    {$ENDIF}
    ForceDirectories(ExtractFileDir(ProbeConfigPath));
    SafeWriteAllText(ProbeConfigPath, '{}');

    Ret := Cmd.Execute([], Ctx);
    Check('doctor full run with same-process HOME/APPDATA override returns valid code', Ret >= 0);
    Check('doctor sees same-process global config path override',
      StdOut.Contains('Global config: ' + ProbeConfigPath));
    Check('doctor sees same-process install root override',
      StdOut.Contains('Install directory exists: ' + ProbeInstallRoot));
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
    RestoreEnv('HOME', SavedHome);
    RestoreEnv('APPDATA', SavedAppData);
    CleanupTempDir(ProbeBaseDir);
    Cmd.Free;
  end;
end;

procedure TestDoctorUsesFPDEVDataRootForConfigAndInstallPaths;
var
  Cmd: TDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ProbeRoot: string;
  ProbeConfigPath: string;
  SavedDataRoot: string;
  Settings: TFPDevSettings;
begin
  ProbeRoot := CreateUniqueTempDir('fpdev_doctor_data_root_probe');
  SavedDataRoot := get_env('FPDEV_DATA_ROOT');
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TDoctorCommand.Create;
  try
    Settings := Ctx.Config.GetSettingsManager.GetSettings;
    Settings.InstallRoot := '';
    if not Ctx.Config.GetSettingsManager.SetSettings(Settings) then
    begin
      Check('doctor FPDEV_DATA_ROOT setup clears install root', False);
      Exit;
    end;

    SetPortableMode(False);
    set_env('FPDEV_DATA_ROOT', ProbeRoot);
    ProbeConfigPath := IncludeTrailingPathDelimiter(ProbeRoot) + 'config.json';
    ForceDirectories(ProbeRoot);
    SafeWriteAllText(ProbeConfigPath, '{}');

    Ret := Cmd.Execute([], Ctx);
    Check('doctor full run with FPDEV_DATA_ROOT override returns valid code', Ret >= 0);
    Check('doctor sees FPDEV_DATA_ROOT global config path override',
      StdOut.Contains('Global config: ' + ProbeConfigPath));
    Check('doctor sees FPDEV_DATA_ROOT install root override',
      StdOut.Contains('Install directory exists: ' + ProbeRoot));
  finally
    RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
    CleanupTempDir(ProbeRoot);
    Cmd.Free;
  end;
end;

{ ===== index ===== }

procedure TestIndexName;
var Cmd: TIndexCommand;
begin
  Cmd := TIndexCommand.Create;
  try Check('index: name', Cmd.Name = 'index'); finally Cmd.Free; end;
end;

procedure TestIndexHelp;
var Cmd: TIndexCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TIndexCommand.Create;
  try
    Ret := Cmd.Execute(['help'], Ctx);
    Check('index help EXIT_OK', Ret = EXIT_OK);
    Check('index help shows usage', StdOut.Contains('index'));
  finally Cmd.Free; end;
end;

procedure TestIndexNoArgs;
var Cmd: TIndexCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TIndexCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('index no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestIndexUnexpectedArg;
var Cmd: TIndexCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TIndexCommand.Create;
  try
    Ret := Cmd.Execute(['status', 'extra'], Ctx);
    Check('index unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== cache ===== }

procedure TestCacheName;
var Cmd: TCacheCommand;
begin
  Cmd := TCacheCommand.Create;
  try Check('cache: name', Cmd.Name = 'cache'); finally Cmd.Free; end;
end;

procedure TestCacheHelp;
var Cmd: TCacheCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCacheCommand.Create;
  try
    Ret := Cmd.Execute(['help'], Ctx);
    Check('cache help EXIT_OK', Ret = EXIT_OK);
    Check('cache help shows usage', StdOut.Contains('cache'));
  finally Cmd.Free; end;
end;

procedure TestCacheNoArgs;
var Cmd: TCacheCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TCacheCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestCacheUnexpectedArg;
var StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Ret := GlobalCommandRegistry.DispatchPath(['system', 'cache', 'stats', 'extra'], Ctx);
  Check('cache unexpected arg EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
end;

{ ===== perf ===== }

procedure TestPerfName;
var Cmd: TPerfCommand;
begin
  Cmd := TPerfCommand.Create;
  try Check('perf: name', Cmd.Name = 'perf'); finally Cmd.Free; end;
end;

procedure TestPerfNoArgs;
var Cmd: TPerfCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPerfCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('perf no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestPerfReportName;
var Cmd: TPerfReportCommand;
begin
  Cmd := TPerfReportCommand.Create;
  try Check('perf report: name', Cmd.Name = 'report'); finally Cmd.Free; end;
end;

procedure TestPerfReportNoArgs;
var Cmd: TPerfReportCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPerfReportCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('perf report no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestPerfSummaryName;
var Cmd: TPerfSummaryCommand;
begin
  Cmd := TPerfSummaryCommand.Create;
  try Check('perf summary: name', Cmd.Name = 'summary'); finally Cmd.Free; end;
end;

procedure TestPerfSummaryNoArgs;
var Cmd: TPerfSummaryCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPerfSummaryCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('perf summary no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestPerfClearName;
var Cmd: TPerfClearCommand;
begin
  Cmd := TPerfClearCommand.Create;
  try Check('perf clear: name', Cmd.Name = 'clear'); finally Cmd.Free; end;
end;

procedure TestPerfClearNoArgs;
var Cmd: TPerfClearCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPerfClearCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('perf clear no args returns valid code', Ret >= 0);
  finally Cmd.Free; end;
end;

procedure TestPerfSaveName;
var Cmd: TPerfSaveCommand;
begin
  Cmd := TPerfSaveCommand.Create;
  try Check('perf save: name', Cmd.Name = 'save'); finally Cmd.Free; end;
end;

procedure TestPerfSaveMissingFile;
var Cmd: TPerfSaveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPerfSaveCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('perf save no args EXIT_ERROR', Ret = EXIT_ERROR);
    Check('perf save no args writes missing filename error', StdErr.Contains('Missing filename'));
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestTopLevelRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundRepo, FoundVersion, FoundSystem: Boolean;
  FoundDefault: Boolean;
  FoundHelp, FoundDoctor, FoundCache, FoundShow, FoundShellHook, FoundResolveVersion: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren([]);
  FoundRepo := False; FoundVersion := False; FoundSystem := False;
  FoundDefault := False; FoundHelp := False; FoundDoctor := False;
  FoundCache := False; FoundShow := False; FoundShellHook := False; FoundResolveVersion := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'repo' then FoundRepo := True;
    if Children[I] = 'system' then FoundSystem := True;
    if Children[I] = 'version' then FoundVersion := True;
    if Children[I] = 'default' then FoundDefault := True;
    if Children[I] = 'help' then FoundHelp := True;
    if Children[I] = 'doctor' then FoundDoctor := True;
    if Children[I] = 'cache' then FoundCache := True;
    if Children[I] = 'show' then FoundShow := True;
    if Children[I] = 'shell-hook' then FoundShellHook := True;
    if Children[I] = 'resolve-version' then FoundResolveVersion := True;
  end;

  Check('repo no longer registered at top level', not FoundRepo);
  Check('system registered at top level', FoundSystem);
  Check('version no longer registered at top level', not FoundVersion);
  Check('default no longer registered at top level', not FoundDefault);
  Check('help no longer registered at top level', not FoundHelp);
  Check('doctor no longer registered at top level', not FoundDoctor);
  Check('cache no longer registered at top level', not FoundCache);
  Check('show no longer registered at top level', not FoundShow);
  Check('shell-hook no longer registered at top level', not FoundShellHook);
  Check('resolve-version no longer registered at top level', not FoundResolveVersion);
end;

procedure TestSystemRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundConfig, FoundEnv, FoundIndex, FoundPerf, FoundRepo, FoundCache, FoundDoctor: Boolean;
  FoundHook, FoundResolve, FoundVars, FoundPath, FoundExport: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['system']);
  FoundConfig := False;
  FoundEnv := False;
  FoundIndex := False;
  FoundPerf := False;
  FoundRepo := False;
  FoundCache := False;
  FoundDoctor := False;
  FoundHook := False;
  FoundResolve := False;
  FoundVars := False;
  FoundPath := False;
  FoundExport := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'config' then FoundConfig := True;
    if Children[I] = 'env' then FoundEnv := True;
    if Children[I] = 'index' then FoundIndex := True;
    if Children[I] = 'perf' then FoundPerf := True;
    if Children[I] = 'repo' then FoundRepo := True;
    if Children[I] = 'cache' then FoundCache := True;
    if Children[I] = 'doctor' then FoundDoctor := True;
  end;

  Check('system config registered', FoundConfig);
  Check('system env registered', FoundEnv);
  Check('system index registered', FoundIndex);
  Check('system perf registered', FoundPerf);
  Check('system repo registered', FoundRepo);
  Check('system cache registered', FoundCache);
  Check('system doctor registered', FoundDoctor);

  Children := GlobalCommandRegistry.ListChildren(['system', 'env']);
  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'vars' then FoundVars := True;
    if Children[I] = 'path' then FoundPath := True;
    if Children[I] = 'export' then FoundExport := True;
    if Children[I] = 'hook' then FoundHook := True;
    if Children[I] = 'resolve' then FoundResolve := True;
  end;
  Check('system env vars registered', FoundVars);
  Check('system env path registered', FoundPath);
  Check('system env export registered', FoundExport);
  Check('system env hook registered', FoundHook);
  Check('system env resolve registered', FoundResolve);
end;

procedure TestRepoRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundAdd, FoundRemove, FoundShow: Boolean;
  FoundUse, FoundVersions, FoundHelp: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['system', 'repo']);
  FoundList := False; FoundAdd := False; FoundRemove := False;
  FoundShow := False; FoundUse := False; FoundVersions := False;
  FoundHelp := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'add' then FoundAdd := True;
    if Children[I] = 'remove' then FoundRemove := True;
    if Children[I] = 'show' then FoundShow := True;
    if Children[I] = 'use' then FoundUse := True;
    if Children[I] = 'versions' then FoundVersions := True;
    if Children[I] = 'help' then FoundHelp := True;
  end;

  Check('system repo list registered', FoundList);
  Check('system repo add registered', FoundAdd);
  Check('system repo remove registered', FoundRemove);
  Check('system repo show registered', FoundShow);
  Check('system repo use registered', FoundUse);
  Check('system repo versions registered', FoundVersions);
  Check('system repo help registered', FoundHelp);
end;

procedure TestPerfRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundReport, FoundSummary, FoundClear, FoundSave: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['system', 'perf']);
  FoundReport := False; FoundSummary := False; FoundClear := False; FoundSave := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'report' then FoundReport := True;
    if Children[I] = 'summary' then FoundSummary := True;
    if Children[I] = 'clear' then FoundClear := True;
    if Children[I] = 'save' then FoundSave := True;
  end;

  Check('perf report registered', FoundReport);
  Check('perf summary registered', FoundSummary);
  Check('perf clear registered', FoundClear);
  Check('perf save registered', FoundSave);
end;

{ ===== Main ===== }
begin
  WriteLn('=== Misc Commands CLI Tests (B200) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_misc');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- config ---');
    TestConfigName;
    TestConfigHelp;
    TestConfigNoArgs;
    TestConfigHelpUnexpectedArg;
    TestConfigShowUnexpectedArg;
    TestConfigGetUnexpectedArg;
    TestConfigSetUnexpectedArg;
    TestConfigGetUnknownKey;
    TestConfigSetInvalidMirror;

    WriteLn('');
  WriteLn('--- config list ---');
  TestConfigListName;
  TestConfigListAlias;
  TestConfigListHelp;
  TestConfigListHelpRejectsExtraOption;
  TestConfigListNoArgs;
  TestConfigListUnknownOption;

    WriteLn('');
    WriteLn('--- repo list ---');
    TestRepoListName;
    TestRepoListHelp;
    TestRepoListNoArgs;
    TestRepoListUnexpectedArg;

    WriteLn('');
    WriteLn('--- repo add ---');
    TestRepoAddName;
    TestRepoAddHelp;
    TestRepoAddMissingArgs;
    TestRepoAddUnexpectedArg;
    TestRepoAddDuplicateRepo;

    WriteLn('');
    WriteLn('--- repo remove ---');
    TestRepoRemoveName;
    TestRepoRemoveAlias;
    TestRepoRemoveHelp;
    TestRepoRemoveMissing;
    TestRepoRemoveUnexpectedArg;
    TestRepoRemoveUnknownRepo;

    WriteLn('');
    WriteLn('--- repo show ---');
    TestRepoShowName;
    TestRepoShowHelp;
    TestRepoShowMissing;
    TestRepoShowUnexpectedArg;
    TestRepoShowUnknownRepo;
    TestRepoShowCurrentRepo;

    WriteLn('');
    WriteLn('--- repo use ---');
    TestRepoUseName;
    TestRepoUseHelp;
    TestRepoUseMissing;
    TestRepoUseUnexpectedArg;
    TestRepoUseUnknownRepo;

    WriteLn('');
    WriteLn('--- repo versions ---');
    TestRepoVersionsName;
    TestRepoVersionsHelp;
    TestRepoVersionsNoArgs;
    TestRepoVersionsUnexpectedArg;
    TestRepoVersionsUnknownFlag;
    TestRepoVersionsUnknownRepo;
    TestRepoVersionsParseFailureExitCode;

    WriteLn('');
    WriteLn('--- repo help ---');
    TestRepoHelpName;
    TestRepoHelpNoArgs;
    TestRepoHelpUnexpectedArg;

    WriteLn('');
    WriteLn('--- env ---');
    TestEnvName;
    TestEnvHelp;
    TestEnvNoArgs;
    TestEnvVarsUnexpectedArg;
    TestEnvExportUnknownOption;
    TestEnvExportMissingShellValue;

    TestGlobalNormalizeLeadingPortable;
    TestGlobalNormalizePortableOnly;
    TestApplyPortableModeLeadingPreludeOnly;
    TestSystemToolchainFetchUsageError;
    TestSystemToolchainExtractUsageError;
    TestSystemToolchainEnsureSourceUsageError;
    TestSystemToolchainImportBundleUsageError;

    WriteLn('');
  WriteLn('--- doctor ---');
  TestDoctorName;
  TestDoctorHelp;
  TestDoctorHelpRejectsExtraOption;
  TestDoctorNoArgs;
  TestDoctorUsesSameProcessEnvOverride;
    TestDoctorUsesSameProcessHomeForConfigAndInstallPaths;
    TestDoctorUsesFPDEVDataRootForConfigAndInstallPaths;

    WriteLn('');
    WriteLn('--- index ---');
    TestIndexName;
    TestIndexHelp;
    TestIndexNoArgs;
    TestIndexUnexpectedArg;

    WriteLn('');
    WriteLn('--- cache ---');
    TestCacheName;
    TestCacheHelp;
    TestCacheNoArgs;
    TestCacheUnexpectedArg;

    WriteLn('');
    WriteLn('--- perf ---');
    TestPerfName;
    TestPerfNoArgs;
    TestPerfReportName;
    TestPerfReportNoArgs;
    TestPerfSummaryName;
    TestPerfSummaryNoArgs;
    TestPerfClearName;
    TestPerfClearNoArgs;
    TestPerfSaveName;
    TestPerfSaveMissingFile;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestTopLevelRegistration;
    TestRepoRegistration;
    TestPerfRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
