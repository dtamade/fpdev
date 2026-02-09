program test_package_commands;

{$mode objfpc}{$H+}

{
  B097: Tests for package command group registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
  fpdev.cmd.package.root,
  fpdev.cmd.package.install,
  fpdev.cmd.package.list,
  fpdev.cmd.package.search,
  fpdev.cmd.package.info,
  fpdev.cmd.package.uninstall,
  fpdev.cmd.package.update,
  fpdev.cmd.package.clean,
  fpdev.cmd.package.install_local,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.deps,
  fpdev.cmd.package.why,
  fpdev.cmd.package.help,
  fpdev.cmd.package.repo.root,
  fpdev.cmd.package.repo.add,
  fpdev.cmd.package.repo.remove,
  fpdev.cmd.package.repo.update,
  fpdev.cmd.package.repo.list;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure Check(const ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    WriteLn('[PASS] ', ATestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', ATestName);
    Inc(TestsFailed);
  end;
end;

function HasSubcommand(const APath: array of string; const AName: string): Boolean;
var
  Children: TStringArray;
  i: Integer;
begin
  Result := False;
  Children := GlobalCommandRegistry.ListChildren(APath);
  for i := Low(Children) to High(Children) do
    if LowerCase(Children[i]) = LowerCase(AName) then
      Exit(True);
end;

{ --- Root Registration Tests --- }

procedure TestPackageRootRegistered;
begin
  Check(HasSubcommand([], 'package'), 'package: root registered');
end;

procedure TestPackagePkgAliasRegistered;
begin
  Check(HasSubcommand([], 'pkg'), 'pkg: alias registered');
end;

{ --- Package Subcommand Tests --- }

procedure TestPackageInstallRegistered;
begin
  Check(HasSubcommand(['package'], 'install'), 'package install: registered');
end;

procedure TestPackageListRegistered;
begin
  Check(HasSubcommand(['package'], 'list'), 'package list: registered');
end;

procedure TestPackageSearchRegistered;
begin
  Check(HasSubcommand(['package'], 'search'), 'package search: registered');
end;

procedure TestPackageInfoRegistered;
begin
  Check(HasSubcommand(['package'], 'info'), 'package info: registered');
end;

procedure TestPackageUninstallRegistered;
begin
  Check(HasSubcommand(['package'], 'uninstall'), 'package uninstall: registered');
end;

procedure TestPackageUpdateRegistered;
begin
  Check(HasSubcommand(['package'], 'update'), 'package update: registered');
end;

procedure TestPackageCleanRegistered;
begin
  Check(HasSubcommand(['package'], 'clean'), 'package clean: registered');
end;

procedure TestPackageInstallLocalRegistered;
begin
  Check(HasSubcommand(['package'], 'install-local'), 'package install-local: registered');
end;

procedure TestPackagePublishRegistered;
begin
  Check(HasSubcommand(['package'], 'publish'), 'package publish: registered');
end;

procedure TestPackageDepsRegistered;
begin
  Check(HasSubcommand(['package'], 'deps'), 'package deps: registered');
end;

procedure TestPackageWhyRegistered;
begin
  Check(HasSubcommand(['package'], 'why'), 'package why: registered');
end;

procedure TestPackageHelpRegistered;
begin
  Check(HasSubcommand(['package'], 'help'), 'package help: registered');
end;

procedure TestPackageRepoRegistered;
begin
  Check(HasSubcommand(['package'], 'repo'), 'package repo: registered');
end;

{ --- Package Repo Subcommand Tests --- }

procedure TestPackageRepoAddRegistered;
begin
  Check(HasSubcommand(['package', 'repo'], 'add'), 'package repo add: registered');
end;

procedure TestPackageRepoRemoveRegistered;
begin
  Check(HasSubcommand(['package', 'repo'], 'remove'), 'package repo remove: registered');
end;

procedure TestPackageRepoUpdateRegistered;
begin
  Check(HasSubcommand(['package', 'repo'], 'update'), 'package repo update: registered');
end;

procedure TestPackageRepoListRegistered;
begin
  Check(HasSubcommand(['package', 'repo'], 'list'), 'package repo list: registered');
end;

{ --- Count Tests --- }

procedure TestPackageSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['package']);
  Check(Length(Children) >= 14, 'package: at least 14 subcommands');
end;

procedure TestPackageRepoSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['package', 'repo']);
  Check(Length(Children) >= 4, 'package repo: at least 4 subcommands');
end;

begin
  WriteLn('=== Package Commands Unit Tests ===');
  WriteLn;

  // Root
  TestPackageRootRegistered;
  TestPackagePkgAliasRegistered;

  // Package subcommands
  TestPackageInstallRegistered;
  TestPackageListRegistered;
  TestPackageSearchRegistered;
  TestPackageInfoRegistered;
  TestPackageUninstallRegistered;
  TestPackageUpdateRegistered;
  TestPackageCleanRegistered;
  TestPackageInstallLocalRegistered;
  TestPackagePublishRegistered;
  TestPackageDepsRegistered;
  TestPackageWhyRegistered;
  TestPackageHelpRegistered;
  TestPackageRepoRegistered;

  // Package repo subcommands
  TestPackageRepoAddRegistered;
  TestPackageRepoRemoveRegistered;
  TestPackageRepoUpdateRegistered;
  TestPackageRepoListRegistered;

  // Count tests
  TestPackageSubcommandCount;
  TestPackageRepoSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
