program test_cli_package;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_package - CLI tests for all package sub-commands
================================================================================

  Covers: install, uninstall, update, list, search, info, publish, clean,
          install-local, help, deps, why, repo list/add/remove/update

  B196-B198: Package command CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.help,
  fpdev.cmd.package.deps,
  fpdev.cmd.package.why,
  fpdev.cmd.package.repo.root,
  fpdev.cmd.package.repo.list,
  fpdev.cmd.package.repo.add,
  fpdev.cmd.package.repo.remove,
  fpdev.cmd.package.repo.update,
  test_cli_helpers;

var
  GTempDir: string;

{ ===== install ===== }

procedure TestInstallName;
var Cmd: TPackageInstallCommand;
begin
  Cmd := TPackageInstallCommand.Create;
  try Check('install: name', Cmd.Name = 'install'); finally Cmd.Free; end;
end;

procedure TestInstallHelp;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install --help EXIT_OK', Ret = EXIT_OK);
    Check('install --help shows usage', StdOut.Contains('install'));
    Check('install --help shows --dry-run', StdOut.Contains('dry-run'));
  finally Cmd.Free; end;
end;

procedure TestInstallMissingPackage;
var Cmd: TPackageInstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== uninstall ===== }

procedure TestUninstallName;
var Cmd: TPackageUninstallCommand;
begin
  Cmd := TPackageUninstallCommand.Create;
  try Check('uninstall: name', Cmd.Name = 'uninstall'); finally Cmd.Free; end;
end;

procedure TestUninstallHelp;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('uninstall --help EXIT_OK', Ret = EXIT_OK);
    Check('uninstall --help shows usage', StdOut.Contains('uninstall'));
  finally Cmd.Free; end;
end;

procedure TestUninstallMissingPackage;
var Cmd: TPackageUninstallCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUninstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('uninstall no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== update ===== }

procedure TestUpdateName;
var Cmd: TPackageUpdateCommand;
begin
  Cmd := TPackageUpdateCommand.Create;
  try Check('update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestUpdateHelp;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
  finally Cmd.Free; end;
end;

procedure TestUpdateMissingPackage;
var Cmd: TPackageUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('update no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== list ===== }

procedure TestListName;
var Cmd: TPackageListCommand;
begin
  Cmd := TPackageListCommand.Create;
  try Check('list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestListAlias;
var Cmd: TPackageListCommand; A: TStringArray;
begin
  Cmd := TPackageListCommand.Create;
  try
    A := Cmd.Aliases;
    Check('list: has ls alias', (A <> nil) and (Length(A) > 0) and (A[0] = 'ls'));
  finally Cmd.Free; end;
end;

procedure TestListHelp;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows --all', StdOut.Contains('all'));
    Check('list --help shows --json', StdOut.Contains('json'));
  finally Cmd.Free; end;
end;

procedure TestListNoArgs;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestListJsonOutput;
var Cmd: TPackageListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

{ ===== search ===== }

procedure TestSearchName;
var Cmd: TPackageSearchCmd;
begin
  Cmd := TPackageSearchCmd.Create;
  try Check('search: name', Cmd.Name = 'search'); finally Cmd.Free; end;
end;

procedure TestSearchHelp;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('search --help EXIT_OK', Ret = EXIT_OK);
    Check('search --help shows usage', StdOut.Contains('search'));
  finally Cmd.Free; end;
end;

procedure TestSearchMissingQuery;
var Cmd: TPackageSearchCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageSearchCmd.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('search no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== info ===== }

procedure TestInfoName;
var Cmd: TPackageInfoCommand;
begin
  Cmd := TPackageInfoCommand.Create;
  try Check('info: name', Cmd.Name = 'info'); finally Cmd.Free; end;
end;

procedure TestInfoHelp;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('info --help EXIT_OK', Ret = EXIT_OK);
    Check('info --help shows usage', StdOut.Contains('info'));
  finally Cmd.Free; end;
end;

procedure TestInfoMissingPackage;
var Cmd: TPackageInfoCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInfoCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('info no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== publish ===== }

procedure TestPublishName;
var Cmd: TPackagePublishCmd;
begin
  Cmd := TPackagePublishCmd.Create;
  try Check('publish: name', Cmd.Name = 'publish'); finally Cmd.Free; end;
end;

procedure TestPublishHelp;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('publish --help EXIT_OK', Ret = EXIT_OK);
    Check('publish --help shows usage', StdOut.Contains('publish'));
  finally Cmd.Free; end;
end;

procedure TestPublishMissingPackage;
var Cmd: TPackagePublishCmd; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackagePublishCmd.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('publish no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== clean ===== }

procedure TestCleanName;
var Cmd: TPackageCleanCommand;
begin
  Cmd := TPackageCleanCommand.Create;
  try Check('clean: name', Cmd.Name = 'clean'); finally Cmd.Free; end;
end;

procedure TestCleanHelp;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('clean --help EXIT_OK', Ret = EXIT_OK);
    Check('clean --help shows --dry-run', StdOut.Contains('dry-run'));
  finally Cmd.Free; end;
end;

procedure TestCleanMissingScope;
var Cmd: TPackageCleanCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('clean no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== install-local ===== }

procedure TestInstallLocalName;
var Cmd: TPackageInstallLocalCommand;
begin
  Cmd := TPackageInstallLocalCommand.Create;
  try Check('install-local: name', Cmd.Name = 'install-local'); finally Cmd.Free; end;
end;

procedure TestInstallLocalHelp;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('install-local --help EXIT_OK', Ret = EXIT_OK);
    Check('install-local --help shows usage', StdOut.Contains('install-local'));
  finally Cmd.Free; end;
end;

procedure TestInstallLocalMissingPath;
var Cmd: TPackageInstallLocalCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageInstallLocalCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('install-local no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== help ===== }

procedure TestHelpName;
var Cmd: TPackageHelpCommand;
begin
  Cmd := TPackageHelpCommand.Create;
  try Check('help: name', Cmd.Name = 'help'); finally Cmd.Free; end;
end;

procedure TestHelpNoArgs;
var Cmd: TPackageHelpCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageHelpCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('help no args EXIT_OK', Ret = EXIT_OK);
    Check('help shows available commands', StdOut.Contains('install'));
  finally Cmd.Free; end;
end;

{ ===== deps ===== }

procedure TestDepsName;
var Cmd: TPackageDepsCommand;
begin
  Cmd := TPackageDepsCommand.Create;
  try Check('deps: name', Cmd.Name = 'deps'); finally Cmd.Free; end;
end;

procedure TestDepsAlias;
var Cmd: TPackageDepsCommand; A: TStringArray;
begin
  Cmd := TPackageDepsCommand.Create;
  try
    A := Cmd.Aliases;
    Check('deps: has dependencies alias', (A <> nil) and (Length(A) > 0) and (A[0] = 'dependencies'));
  finally Cmd.Free; end;
end;

procedure TestDepsHelp;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('deps --help EXIT_OK', Ret = EXIT_OK);
    Check('deps --help shows --tree', StdOut.Contains('tree'));
    Check('deps --help shows --flat', StdOut.Contains('flat'));
  finally Cmd.Free; end;
end;

procedure TestDepsNoArgs;
var Cmd: TPackageDepsCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageDepsCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('deps no args EXIT_OK', Ret = EXIT_OK);
    Check('deps no args shows current project', StdOut.Contains('current project'));
  finally Cmd.Free; end;
end;

{ ===== why ===== }

procedure TestWhyName;
var Cmd: TPackageWhyCommand;
begin
  Cmd := TPackageWhyCommand.Create;
  try Check('why: name', Cmd.Name = 'why'); finally Cmd.Free; end;
end;

procedure TestWhyHelp;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('why --help EXIT_OK', Ret = EXIT_OK);
    Check('why --help shows usage', StdOut.Contains('why'));
  finally Cmd.Free; end;
end;

procedure TestWhyMissingPackage;
var Cmd: TPackageWhyCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageWhyCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('why no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo list ===== }

procedure TestRepoListName;
var Cmd: TPackageRepoListCommand;
begin
  Cmd := TPackageRepoListCommand.Create;
  try Check('repo list: name', Cmd.Name = 'list'); finally Cmd.Free; end;
end;

procedure TestRepoListAlias;
var Cmd: TPackageRepoListCommand; A: TStringArray;
begin
  Cmd := TPackageRepoListCommand.Create;
  try
    A := Cmd.Aliases;
    Check('repo list: has ls alias', (A <> nil) and (Length(A) > 0) and (A[0] = 'ls'));
  finally Cmd.Free; end;
end;

procedure TestRepoListHelp;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo list --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoListNoArgs;
var Cmd: TPackageRepoListCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo list no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

{ ===== repo add ===== }

procedure TestRepoAddName;
var Cmd: TPackageRepoAddCommand;
begin
  Cmd := TPackageRepoAddCommand.Create;
  try Check('repo add: name', Cmd.Name = 'add'); finally Cmd.Free; end;
end;

procedure TestRepoAddHelp;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo add --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoAddMissingArgs;
var Cmd: TPackageRepoAddCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoAddCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo add no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo remove ===== }

procedure TestRepoRemoveName;
var Cmd: TPackageRepoRemoveCommand;
begin
  Cmd := TPackageRepoRemoveCommand.Create;
  try Check('repo remove: name', Cmd.Name = 'remove'); finally Cmd.Free; end;
end;

procedure TestRepoRemoveAliases;
var Cmd: TPackageRepoRemoveCommand; A: TStringArray;
begin
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    A := Cmd.Aliases;
    Check('repo remove: has rm alias', (A <> nil) and (Length(A) >= 2) and (A[0] = 'rm'));
    Check('repo remove: has del alias', A[1] = 'del');
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveHelp;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo remove --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoRemoveMissingName;
var Cmd: TPackageRepoRemoveCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoRemoveCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo remove no args EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally Cmd.Free; end;
end;

{ ===== repo update ===== }

procedure TestRepoUpdateName;
var Cmd: TPackageRepoUpdateCommand;
begin
  Cmd := TPackageRepoUpdateCommand.Create;
  try Check('repo update: name', Cmd.Name = 'update'); finally Cmd.Free; end;
end;

procedure TestRepoUpdateHelp;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('repo update --help EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

procedure TestRepoUpdateNoArgs;
var Cmd: TPackageRepoUpdateCommand; StdOut, StdErr: TStringOutput; Ctx: IContext; Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TPackageRepoUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('repo update no args EXIT_OK', Ret = EXIT_OK);
  finally Cmd.Free; end;
end;

{ ===== Registration ===== }

procedure TestPackageRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundInstall, FoundUninstall, FoundUpdate, FoundList: Boolean;
  FoundSearch, FoundInfo, FoundPublish, FoundClean: Boolean;
  FoundInstallLocal, FoundHelp, FoundDeps, FoundWhy: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['package']);
  FoundInstall := False; FoundUninstall := False; FoundUpdate := False;
  FoundList := False; FoundSearch := False; FoundInfo := False;
  FoundPublish := False; FoundClean := False; FoundInstallLocal := False;
  FoundHelp := False; FoundDeps := False; FoundWhy := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'install' then FoundInstall := True;
    if Children[I] = 'uninstall' then FoundUninstall := True;
    if Children[I] = 'update' then FoundUpdate := True;
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'search' then FoundSearch := True;
    if Children[I] = 'info' then FoundInfo := True;
    if Children[I] = 'publish' then FoundPublish := True;
    if Children[I] = 'clean' then FoundClean := True;
    if Children[I] = 'install-local' then FoundInstallLocal := True;
    if Children[I] = 'help' then FoundHelp := True;
    if Children[I] = 'deps' then FoundDeps := True;
    if Children[I] = 'why' then FoundWhy := True;
  end;

  Check('package install registered', FoundInstall);
  Check('package uninstall registered', FoundUninstall);
  Check('package update registered', FoundUpdate);
  Check('package list registered', FoundList);
  Check('package search registered', FoundSearch);
  Check('package info registered', FoundInfo);
  Check('package publish registered', FoundPublish);
  Check('package clean registered', FoundClean);
  Check('package install-local registered', FoundInstallLocal);
  Check('package help registered', FoundHelp);
  Check('package deps registered', FoundDeps);
  Check('package why registered', FoundWhy);
end;

procedure TestPackageRepoRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundList, FoundAdd, FoundRemove, FoundUpdate: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['package', 'repo']);
  FoundList := False; FoundAdd := False; FoundRemove := False; FoundUpdate := False;

  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'add' then FoundAdd := True;
    if Children[I] = 'remove' then FoundRemove := True;
    if Children[I] = 'update' then FoundUpdate := True;
  end;

  Check('package repo list registered', FoundList);
  Check('package repo add registered', FoundAdd);
  Check('package repo remove registered', FoundRemove);
  Check('package repo update registered', FoundUpdate);
end;

{ ===== Main ===== }
begin
  WriteLn('=== Package Commands CLI Tests (B196-B198) ===');
  WriteLn;

  GTempDir := GetTempDir + 'fpdev_test_pkg_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    WriteLn('--- install ---');
    TestInstallName;
    TestInstallHelp;
    TestInstallMissingPackage;

    WriteLn('');
    WriteLn('--- uninstall ---');
    TestUninstallName;
    TestUninstallHelp;
    TestUninstallMissingPackage;

    WriteLn('');
    WriteLn('--- update ---');
    TestUpdateName;
    TestUpdateHelp;
    TestUpdateMissingPackage;

    WriteLn('');
    WriteLn('--- list ---');
    TestListName;
    TestListAlias;
    TestListHelp;
    TestListNoArgs;
    TestListJsonOutput;

    WriteLn('');
    WriteLn('--- search ---');
    TestSearchName;
    TestSearchHelp;
    TestSearchMissingQuery;

    WriteLn('');
    WriteLn('--- info ---');
    TestInfoName;
    TestInfoHelp;
    TestInfoMissingPackage;

    WriteLn('');
    WriteLn('--- publish ---');
    TestPublishName;
    TestPublishHelp;
    TestPublishMissingPackage;

    WriteLn('');
    WriteLn('--- clean ---');
    TestCleanName;
    TestCleanHelp;
    TestCleanMissingScope;

    WriteLn('');
    WriteLn('--- install-local ---');
    TestInstallLocalName;
    TestInstallLocalHelp;
    TestInstallLocalMissingPath;

    WriteLn('');
    WriteLn('--- help ---');
    TestHelpName;
    TestHelpNoArgs;

    WriteLn('');
    WriteLn('--- deps ---');
    TestDepsName;
    TestDepsAlias;
    TestDepsHelp;
    TestDepsNoArgs;

    WriteLn('');
    WriteLn('--- why ---');
    TestWhyName;
    TestWhyHelp;
    TestWhyMissingPackage;

    WriteLn('');
    WriteLn('--- repo list ---');
    TestRepoListName;
    TestRepoListAlias;
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
    TestRepoRemoveAliases;
    TestRepoRemoveHelp;
    TestRepoRemoveMissingName;

    WriteLn('');
    WriteLn('--- repo update ---');
    TestRepoUpdateName;
    TestRepoUpdateHelp;
    TestRepoUpdateNoArgs;

    WriteLn('');
    WriteLn('--- Registration ---');
    TestPackageRegistration;
    TestPackageRepoRegistration;
  finally
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'config.json');
      RemoveDir(GTempDir);
    end;
  end;

  Halt(PrintTestSummary);
end.
