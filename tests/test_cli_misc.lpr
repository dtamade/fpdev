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
  fpdev.exitcodes,
  fpdev.cmd.config,
  fpdev.cmd.config.list,
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.default,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help,
  fpdev.cmd.env,
  fpdev.cmd.version,
  fpdev.cmd.help.root,
  fpdev.cmd.doctor,
  fpdev.cmd.index,
  fpdev.cmd.cache,
  fpdev.cmd.perf,
  test_cli_helpers;

var
  GTempDir: string;

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
    // Note: TConfigCommand uses internal FOut, not Ctx.Out
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
    Check('config list: has ls alias', (A <> nil) and (Length(A) > 0) and (A[0] = 'ls'));
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
    Check('repo remove: has rm alias', (A <> nil) and (Length(A) > 0) and (A[0] = 'rm'));
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

{ ===== repo default ===== }

procedure TestRepoDefaultName;
var Cmd: TRepoDefaultCommand;
begin
  Cmd := TRepoDefaultCommand.Create;
  try Check('repo default: name', Cmd.Name = 'default'); finally Cmd.Free; end;
end;

procedure TestRepoDefaultHelp;
var Cmd: TRepoDefaultCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoDefaultCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo default --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoDefaultMissing;
var Cmd: TRepoDefaultCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TRepoDefaultCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo default no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
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

{ ===== version ===== }

procedure TestVersionName;
var Cmd: TVersionCommand;
begin
  Cmd := TVersionCommand.Create;
  try Check('version: name', Cmd.Name = 'version'); finally Cmd.Free; end;
end;

procedure TestVersionNoArgs;
var Cmd: TVersionCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TVersionCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('version no args EXIT_OK', Ret = EXIT_OK);
    Check('version shows fpdev', StdOut.Contains('fpdev'));
  finally Cmd.Free; end;
end;

{ ===== help ===== }

procedure TestHelpName;
var Cmd: THelpCommand;
begin
  Cmd := THelpCommand.Create;
  try Check('help: name', Cmd.Name = 'help'); finally Cmd.Free; end;
end;

procedure TestHelpNoArgs;
var Cmd: THelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := THelpCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('help no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
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
    Check('perf save no args returns error', Ret > 0);
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestTopLevelRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundConfig, FoundRepo, FoundEnv, FoundVersion: Boolean;
  FoundHelp, FoundDoctor, FoundIndex, FoundCache, FoundPerf: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren([]);
  FoundConfig := False; FoundRepo := False; FoundEnv := False;
  FoundVersion := False; FoundHelp := False; FoundDoctor := False;
  FoundIndex := False; FoundCache := False; FoundPerf := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'config' then FoundConfig := True;
    if Children[I] = 'repo' then FoundRepo := True;
    if Children[I] = 'env' then FoundEnv := True;
    if Children[I] = 'version' then FoundVersion := True;
    if Children[I] = 'help' then FoundHelp := True;
    if Children[I] = 'doctor' then FoundDoctor := True;
    if Children[I] = 'index' then FoundIndex := True;
    if Children[I] = 'cache' then FoundCache := True;
    if Children[I] = 'perf' then FoundPerf := True;
  end;

  Check('config registered at top level', FoundConfig);
  Check('repo registered at top level', FoundRepo);
  Check('env registered at top level', FoundEnv);
  Check('version registered at top level', FoundVersion);
  Check('help registered at top level', FoundHelp);
  Check('doctor registered at top level', FoundDoctor);
  Check('index registered at top level', FoundIndex);
  Check('cache registered at top level', FoundCache);
  Check('perf registered at top level', FoundPerf);
end;

procedure TestRepoRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundAdd, FoundRemove, FoundShow: Boolean;
  FoundDefault, FoundVersions, FoundHelp: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['repo']);
  FoundList := False; FoundAdd := False; FoundRemove := False;
  FoundShow := False; FoundDefault := False; FoundVersions := False;
  FoundHelp := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'add' then FoundAdd := True;
    if Children[I] = 'remove' then FoundRemove := True;
    if Children[I] = 'show' then FoundShow := True;
    if Children[I] = 'default' then FoundDefault := True;
    if Children[I] = 'versions' then FoundVersions := True;
    if Children[I] = 'help' then FoundHelp := True;
  end;

  Check('repo list registered', FoundList);
  Check('repo add registered', FoundAdd);
  Check('repo remove registered', FoundRemove);
  Check('repo show registered', FoundShow);
  Check('repo default registered', FoundDefault);
  Check('repo versions registered', FoundVersions);
  Check('repo help registered', FoundHelp);
end;

procedure TestPerfRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundReport, FoundSummary, FoundClear, FoundSave: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['perf']);
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

  GTempDir := GetTempDir + 'fpdev_test_misc_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    WriteLn('--- config ---');
    TestConfigName;
    TestConfigHelp;
    TestConfigNoArgs;

    WriteLn('');
    WriteLn('--- config list ---');
    TestConfigListName;
    TestConfigListAlias;
    TestConfigListHelp;
    TestConfigListNoArgs;

    WriteLn('');
    WriteLn('--- repo list ---');
    TestRepoListName;
    TestRepoListHelp;
    TestRepoListNoArgs;

    WriteLn('');
    WriteLn('--- repo add ---');
    TestRepoAddName;
    TestRepoAddHelp;
    TestRepoAddMissingArgs;

    WriteLn('');
    WriteLn('--- repo remove ---');
    TestRepoRemoveName;
    TestRepoRemoveAlias;
    TestRepoRemoveHelp;
    TestRepoRemoveMissing;

    WriteLn('');
    WriteLn('--- repo show ---');
    TestRepoShowName;
    TestRepoShowHelp;
    TestRepoShowMissing;

    WriteLn('');
    WriteLn('--- repo default ---');
    TestRepoDefaultName;
    TestRepoDefaultHelp;
    TestRepoDefaultMissing;

    WriteLn('');
    WriteLn('--- repo versions ---');
    TestRepoVersionsName;
    TestRepoVersionsHelp;
    TestRepoVersionsNoArgs;

    WriteLn('');
    WriteLn('--- repo help ---');
    TestRepoHelpName;
    TestRepoHelpNoArgs;

    WriteLn('');
    WriteLn('--- env ---');
    TestEnvName;
    TestEnvHelp;
    TestEnvNoArgs;

    WriteLn('');
    WriteLn('--- version ---');
    TestVersionName;
    TestVersionNoArgs;

    WriteLn('');
    WriteLn('--- help ---');
    TestHelpName;
    TestHelpNoArgs;

    WriteLn('');
    WriteLn('--- doctor ---');
    TestDoctorName;
    TestDoctorHelp;
    TestDoctorNoArgs;

    WriteLn('');
    WriteLn('--- index ---');
    TestIndexName;
    TestIndexHelp;
    TestIndexNoArgs;

    WriteLn('');
    WriteLn('--- cache ---');
    TestCacheName;
    TestCacheHelp;
    TestCacheNoArgs;

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
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'config.json');
      RemoveDir(GTempDir);
    end;
  end;

  Halt(PrintTestSummary);
end.
