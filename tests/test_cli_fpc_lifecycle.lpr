program test_cli_fpc_lifecycle;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_fpc_lifecycle - CLI tests for fpdev fpc update/test/update-manifest
================================================================================

  Tests the FPC lifecycle commands' CLI behavior:
  - update: source/index update with help, execution
  - test: installation testing with help, missing version
  - update-manifest: manifest cache management with help

  Uses shared test_cli_helpers unit for TStringOutput/TTestContext.

  B190: FPC lifecycle commands CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, Process,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.config.interfaces,
  fpdev.exitcodes,
  fpdev.i18n, fpdev.i18n.strings,
  fpdev.cmd.fpc,                   // Register 'fpc' root command
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.update_manifest,
  fpdev.cmd.fpc.autoinstall,
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

function SetupTrackedFPCSourceRepo(const AInstallRoot, AVersion: string;
  out ASourceDir, ASeedDir: string): Boolean;
var
  FixtureRoot: string;
  RemoteBareDir: string;
begin
  Result := False;
  ASourceDir := AInstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' +
    PathDelim + 'fpc-' + AVersion;
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

  WriteTextFile(ASeedDir + PathDelim + 'README.txt', 'base' + LineEnding);
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

procedure WriteCachedFPCManifest(const ACacheDir: string);
var
  Manifest: TStringList;
  CachePath: string;
begin
  ForceDirectories(ACacheDir);
  CachePath := IncludeTrailingPathDelimiter(ACacheDir) + 'fpc.json';
  Manifest := TStringList.Create;
  try
    Manifest.Add('{');
    Manifest.Add('  "manifest-version": "1",');
    Manifest.Add('  "date": "2026-03-09",');
    Manifest.Add('  "channel": "stable",');
    Manifest.Add('  "pkg": {');
    Manifest.Add('    "fpc": {');
    Manifest.Add('      "version": "3.2.2",');
    Manifest.Add('      "targets": {');
    Manifest.Add('        "linux-x86_64": {');
    Manifest.Add('          "url": "https://example.com/fpc.tar.gz",');
    Manifest.Add('          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",');
    Manifest.Add('          "size": 123456789');
    Manifest.Add('        }');
    Manifest.Add('      }');
    Manifest.Add('    }');
    Manifest.Add('  }');
    Manifest.Add('}');
    Manifest.SaveToFile(CachePath);
  finally
    Manifest.Free;
  end;
end;

{ ===== Group 1: fpc update - Command Basics ===== }

procedure TestUpdateCommandName;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: name is "update"', Cmd.Name = 'update');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateAliasesNil;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateFindSubNil;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: fpc update - Help ===== }

procedure TestUpdateHelpFlag;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help returns EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
    Check('update --help shows optional version', StdOut.Contains('[version]'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateHelpShortFlag;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('update -h returns EXIT_OK', Ret = EXIT_OK);
    Check('update -h shows usage', StdOut.Contains('update'));
    Check('update -h shows optional version', StdOut.Contains('[version]'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: fpc update - Execution ===== }

procedure TestUpdateNoArgs;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // No args = update index only
    Check('update no args produces output', Length(AllOutput) > 0);
    Check('update no args returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateMissingSourceDoesNotAppendGenericFailure;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_missing_installroot';
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  ForceDirectories(InstallRoot);

  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  if not SetInstallRoot(Ctx, InstallRoot) then
  begin
    Check('update missing source setup install root', False);
    Exit;
  end;

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update missing source returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update missing source emits concrete error',
      StdErr.Contains(_Fmt(CMD_FPC_SOURCE_DIR_NOT_FOUND, [SourceDir])));
    Check('update missing source does not append generic failed',
      not StdErr.Contains(_Fmt(CMD_FPC_UPDATE_FAILED, ['3.2.2'])));
    Check('update missing source keeps version banner',
      StdOut.Contains(_Fmt(CMD_FPC_UPDATE_VERSION, ['3.2.2'])));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateLocalOnlyDoesNotAppendGenericSuccess;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  InstallRoot: string;
  SourceDir: string;
begin
  InstallRoot := GTempDir + PathDelim + 'update_local_only_installroot';
  SourceDir := InstallRoot + PathDelim + 'sources' + PathDelim + 'fpc' + PathDelim + 'fpc-3.2.2';
  ForceDirectories(SourceDir);

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

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update local-only returns EXIT_OK', Ret = EXIT_OK);
    Check('update local-only emits local-only status',
      StdOut.Contains(_(MSG_FPC_SOURCE_LOCAL_ONLY) + ' ' + SourceDir));
    Check('update local-only does not append generic success',
      not StdOut.Contains(_(CMD_FPC_UPDATE_DONE)));
    Check('update local-only keeps stderr empty',
      Trim(StdErr.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDirtyWorktreeShowsNormalizedPullFailure;
var
  Cmd: TFPCUpdateCommand;
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
  if not SetupTrackedFPCSourceRepo(InstallRoot, '3.2.2', SourceDir, SeedDir) then
  begin
    Check('update dirty setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'README.txt', 'remote-change' + LineEnding);
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

  WriteTextFile(SourceDir + PathDelim + 'README.txt', 'local-uncommitted' + LineEnding);

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update dirty returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update dirty keeps version banner',
      StdOut.Contains(_Fmt(CMD_FPC_UPDATE_VERSION, ['3.2.2'])));
    Check('update dirty emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIRTY_WORKTREE)])));
    Check('update dirty does not emit success',
      not StdOut.Contains(_(CMD_FPC_UPDATE_DONE)));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDetachedHeadShowsNormalizedPullFailure;
var
  Cmd: TFPCUpdateCommand;
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
  if not SetupTrackedFPCSourceRepo(InstallRoot, '3.2.2', SourceDir, SeedDir) then
  begin
    Check('update detached setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'README.txt', 'remote-change' + LineEnding);
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

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update detached returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update detached keeps version banner',
      StdOut.Contains(_Fmt(CMD_FPC_UPDATE_VERSION, ['3.2.2'])));
    Check('update detached emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DETACHED_HEAD)])));
    Check('update detached does not emit success',
      not StdOut.Contains(_(CMD_FPC_UPDATE_DONE)));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateDivergedConflictShowsNormalizedPullFailure;
var
  Cmd: TFPCUpdateCommand;
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
  if not SetupTrackedFPCSourceRepo(InstallRoot, '3.2.2', SourceDir, SeedDir) then
  begin
    Check('update diverged setup tracked repo', False);
    Exit;
  end;

  WriteTextFile(SourceDir + PathDelim + 'README.txt', 'local-commit' + LineEnding);
  if not CommitAll(SourceDir, 'local change') then
  begin
    Check('update diverged setup local commit', False);
    Exit;
  end;

  WriteTextFile(SeedDir + PathDelim + 'README.txt', 'remote-commit' + LineEnding);
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

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update diverged returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update diverged keeps version banner',
      StdOut.Contains(_Fmt(CMD_FPC_UPDATE_VERSION, ['3.2.2'])));
    Check('update diverged emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIVERGED_HISTORY)])));
    Check('update diverged does not emit success',
      not StdOut.Contains(_(CMD_FPC_UPDATE_DONE)));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateNonConflictingDivergedHistoryFailsFastForwardOnly;
var
  Cmd: TFPCUpdateCommand;
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
  if not SetupTrackedFPCSourceRepo(InstallRoot, '3.2.2', SourceDir, SeedDir) then
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

  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    Check('update ff-only diverged returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('update ff-only diverged keeps version banner',
      StdOut.Contains(_Fmt(CMD_FPC_UPDATE_VERSION, ['3.2.2'])));
    Check('update ff-only diverged emits normalized pull failure',
      StdErr.Contains(_Fmt(CMD_FPC_GIT_PULL_FAILED, [_(MSG_GIT_UPDATE_DIVERGED_HISTORY)])));
    Check('update ff-only diverged does not emit success',
      not StdOut.Contains(_(CMD_FPC_UPDATE_DONE)));
    Check('update ff-only diverged keeps local-only file',
      FileExists(SourceDir + PathDelim + 'local.txt'));
    Check('update ff-only diverged does not materialize remote file',
      not FileExists(SourceDir + PathDelim + 'remote.txt'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateUnexpectedArgReturnsUsageError;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('update unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('update unexpected arg shows usage', StdErr.Contains('[version]'));
    Check('update unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateUnknownOptionReturnsUsageError;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('update unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('update unknown option shows usage', StdErr.Contains('[version]'));
    Check('update unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: fpc update - Registration ===== }

procedure TestUpdateRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'update' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc update is registered in command registry', Found);
end;

{ ===== Group 5: fpc test - Command Basics ===== }

procedure TestTestCommandName;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: name is "test"', Cmd.Name = 'test');
  finally
    Cmd.Free;
  end;
end;

procedure TestTestAliasesNil;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestTestFindSubNil;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: FindSub returns nil', Cmd.FindSub('abc') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: fpc test - Help ===== }

procedure TestTestHelpFlag;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('test --help returns EXIT_OK', Ret = EXIT_OK);
    Check('test --help shows usage', StdOut.Contains('test'));
  finally
    Cmd.Free;
  end;
end;

procedure TestTestHelpShortFlag;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('test -h returns EXIT_OK', Ret = EXIT_OK);
    Check('test -h shows usage', StdOut.Contains('test'));
  finally
    Cmd.Free;
  end;
end;

procedure TestTestHelpUnexpectedArgReturnsUsageError;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('test help unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('test help unexpected arg shows usage', StdErr.Contains('[version]'));
    Check('test help unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 7: fpc test - No Args (System FPC Fallback) ===== }

procedure TestTestMissingVersion;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // No args, no default toolchain -> should fall back to system FPC in PATH
    Check('test no args returns EXIT_OK', Ret = EXIT_OK);
    Check('test no args uses system fallback', Pos('Testing system FPC', AllOutput) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestTestUnexpectedArgReturnsUsageError;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('test unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('test unexpected arg shows usage', StdErr.Contains('[version]'));
    Check('test unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestTestUnknownOptionReturnsUsageError;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('test unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('test unknown option shows usage', StdErr.Contains('[version]'));
    Check('test unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 8: fpc test - Execution with version ===== }

procedure TestTestWithVersion;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // Non-existent version -> will fail but should produce output
    Check('test with version produces output', Length(AllOutput) > 0);
    Check('test with version returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 9: fpc test - Registration ===== }

procedure TestTestRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'test' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc test is registered in command registry', Found);
end;

{ ===== Group 10: fpc update-manifest - Command Basics ===== }

procedure TestUpdateManifestCommandName;
var
  Cmd: TFPCUpdateManifestCommand;
begin
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Check('update-manifest: name is "update-manifest"', Cmd.Name = 'update-manifest');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestAliasesNil;
var
  Cmd: TFPCUpdateManifestCommand;
begin
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Check('update-manifest: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc update-manifest - Help ===== }

procedure TestUpdateManifestHelpFlag;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update-manifest --help returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest --help shows usage', StdOut.Contains('update-manifest'));
    Check('update-manifest --help shows --force option', StdOut.Contains('force'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestHelpShortFlag;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('update-manifest -h returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest -h shows usage', StdOut.Contains('update-manifest'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestUnexpectedArg;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('update-manifest unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestUnknownOption;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('update-manifest unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestForceWithExtraArg;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--force', 'extra'], Ctx);
    Check('update-manifest --force with extra arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 12: fpc update-manifest - Registration ===== }

procedure TestUpdateManifestUsesContextScopedCache;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ExpectedCacheDir: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  ExpectedCacheDir := IncludeTrailingPathDelimiter(GTempDir) + 'cache' + PathDelim + 'manifests';
  WriteCachedFPCManifest(ExpectedCacheDir);
  try
    Ret := Cmd.Execute([], Ctx);
    Check('update-manifest cached run returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest uses context-scoped cache dir',
      StdOut.Contains('  Cache: ' + ExpectedCacheDir));
    Check('update-manifest cached run lists available version',
      StdOut.Contains('3.2.2'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'update-manifest' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc update-manifest is registered in command registry', Found);
end;

{ ===== Group 13: fpc auto-install - Error routing ===== }

procedure TestAutoInstallMissingConfigWritesStderr;
var
  Cmd: TFPCAutoInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  OldDir: string;
  TempNoConfigDir: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCAutoInstallCommand.Create;
  OldDir := GetCurrentDir;
  TempNoConfigDir := GTempDir + PathDelim + 'autoinstall_no_config';
  ForceDirectories(TempNoConfigDir);
  try
    SetCurrentDir(TempNoConfigDir);
    Ret := Cmd.Execute([], Ctx);
    Check('auto-install missing config returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('auto-install missing config error goes to stderr',
      StdErr.Contains('No .fpdev.toml found'));
    Check('auto-install missing config does not write error to stdout',
      not StdOut.Contains('No .fpdev.toml found'));
  finally
    SetCurrentDir(OldDir);
    Cmd.Free;
  end;
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Lifecycle Commands CLI Tests (update/test/update-manifest/auto-install) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_fpc_life');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    // Group 1: fpc update basics
    WriteLn('--- fpc update: Command Basics ---');
    TestUpdateCommandName;
    TestUpdateAliasesNil;
    TestUpdateFindSubNil;

    // Group 2: fpc update help
    WriteLn('');
    WriteLn('--- fpc update: Help Output ---');
    TestUpdateHelpFlag;
    TestUpdateHelpShortFlag;

    // Group 3: fpc update execution
    WriteLn('');
    WriteLn('--- fpc update: Execution ---');
    TestUpdateNoArgs;
    TestUpdateMissingSourceDoesNotAppendGenericFailure;
    TestUpdateLocalOnlyDoesNotAppendGenericSuccess;
    TestUpdateDirtyWorktreeShowsNormalizedPullFailure;
    TestUpdateDetachedHeadShowsNormalizedPullFailure;
    TestUpdateDivergedConflictShowsNormalizedPullFailure;
    TestUpdateNonConflictingDivergedHistoryFailsFastForwardOnly;
    TestUpdateUnexpectedArgReturnsUsageError;
    TestUpdateUnknownOptionReturnsUsageError;

    // Group 4: fpc update registration
    WriteLn('');
    WriteLn('--- fpc update: Registration ---');
    TestUpdateRegistration;

    // Group 5: fpc test basics
    WriteLn('');
    WriteLn('--- fpc test: Command Basics ---');
    TestTestCommandName;
    TestTestAliasesNil;
    TestTestFindSubNil;

    // Group 6: fpc test help
    WriteLn('');
    WriteLn('--- fpc test: Help Output ---');
    TestTestHelpFlag;
    TestTestHelpShortFlag;
    TestTestHelpUnexpectedArgReturnsUsageError;

    // Group 7: fpc test missing version
    WriteLn('');
    WriteLn('--- fpc test: Argument Validation ---');
    TestTestMissingVersion;
    TestTestUnexpectedArgReturnsUsageError;
    TestTestUnknownOptionReturnsUsageError;

    // Group 8: fpc test with version
    WriteLn('');
    WriteLn('--- fpc test: Execution ---');
    TestTestWithVersion;

    // Group 9: fpc test registration
    WriteLn('');
    WriteLn('--- fpc test: Registration ---');
    TestTestRegistration;

    // Group 10: fpc update-manifest basics
    WriteLn('');
    WriteLn('--- fpc update-manifest: Command Basics ---');
    TestUpdateManifestCommandName;
    TestUpdateManifestAliasesNil;

    // Group 11: fpc update-manifest help
    WriteLn('');
    WriteLn('--- fpc update-manifest: Help Output ---');
    TestUpdateManifestHelpFlag;
    TestUpdateManifestHelpShortFlag;
    TestUpdateManifestUnexpectedArg;
    TestUpdateManifestUnknownOption;
    TestUpdateManifestForceWithExtraArg;

    // Group 12: fpc update-manifest registration
    WriteLn('');
    WriteLn('--- fpc update-manifest: Registration ---');
    TestUpdateManifestRegistration;
    TestUpdateManifestUsesContextScopedCache;

    // Group 13: fpc auto-install error routing
    WriteLn('');
    WriteLn('--- fpc auto-install: Error Routing ---');
    TestAutoInstallMissingConfigWritesStderr;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
