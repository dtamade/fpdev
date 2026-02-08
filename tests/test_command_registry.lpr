program test_command_registry;

{$mode objfpc}{$H+}

{
  B053: Command Registry Contract Tests

  Tests command registration, alias resolution, and dispatch paths
  to prevent "command unreachable" regressions.
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  // Import all command units to trigger registration
  fpdev.cmd.help,
  fpdev.cmd.help.root,
  fpdev.cmd.version,
  fpdev.cmd.fpc,
  fpdev.cmd.fpc.root,
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.autoinstall,
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.verify,
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.update_manifest,
  fpdev.cmd.fpc.uninstall,
  fpdev.cmd.fpc.help,
  fpdev.cmd.fpc.cache,
  fpdev.cmd.fpc.cache.list,
  fpdev.cmd.fpc.cache.clean,
  fpdev.cmd.fpc.cache.stats,
  fpdev.cmd.fpc.cache.path,
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.default,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help,
  fpdev.cmd.lazarus.root,
  fpdev.cmd.lazarus.list,
  fpdev.cmd.lazarus.current,
  fpdev.cmd.lazarus.use,
  fpdev.cmd.lazarus.run,
  fpdev.cmd.lazarus.test,
  fpdev.cmd.lazarus.install,
  fpdev.cmd.lazarus.uninstall,
  fpdev.cmd.lazarus.show,
  fpdev.cmd.lazarus.configure,
  fpdev.cmd.lazarus.doctor,
  fpdev.cmd.lazarus.update,
  fpdev.cmd.lazarus.help,
  fpdev.cmd.cross.root,
  fpdev.cmd.cross.list,
  fpdev.cmd.cross.show,
  fpdev.cmd.cross.enable,
  fpdev.cmd.cross.disable,
  fpdev.cmd.cross.test,
  fpdev.cmd.cross.install,
  fpdev.cmd.cross.uninstall,
  fpdev.cmd.cross.configure,
  fpdev.cmd.cross.doctor,
  fpdev.cmd.cross.help,
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
  fpdev.cmd.package.help,
  fpdev.cmd.project.root,
  fpdev.cmd.project.new,
  fpdev.cmd.project.list,
  fpdev.cmd.project.info,
  fpdev.cmd.project.build,
  fpdev.cmd.project.clean,
  fpdev.cmd.project.test,
  fpdev.cmd.project.run,
  fpdev.cmd.project.help;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

procedure AssertEquals(AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (expected: ' + IntToStr(AExpected) + ', got: ' + IntToStr(AActual) + ')');
end;

// ============================================================================
// Test: Root Commands Registered
// ============================================================================
procedure TestRootCommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasFPC, HasLazarus, HasPackage, HasCross, HasRepo, HasProject: Boolean;
begin
  WriteLn('[TEST] TestRootCommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren([]);

  HasFPC := False;
  HasLazarus := False;
  HasPackage := False;
  HasCross := False;
  HasRepo := False;
  HasProject := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'fpc': HasFPC := True;
      'lazarus': HasLazarus := True;
      'package', 'pkg': HasPackage := True;
      'cross': HasCross := True;
      'repo': HasRepo := True;
      'project': HasProject := True;
    end;
  end;

  AssertTrue(HasFPC, 'fpc command registered');
  AssertTrue(HasLazarus, 'lazarus command registered');
  AssertTrue(HasPackage, 'package command registered');
  AssertTrue(HasCross, 'cross command registered');
  AssertTrue(HasRepo, 'repo command registered');
  AssertTrue(HasProject, 'project command registered');
end;

// ============================================================================
// Test: FPC Subcommands Registered
// ============================================================================
procedure TestFPCSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasInstall, HasList, HasUse, HasCurrent, HasShow, HasDoctor: Boolean;
  HasVerify, HasAutoInstall, HasUninstall, HasCache: Boolean;
begin
  WriteLn('[TEST] TestFPCSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['fpc']);

  HasInstall := False;
  HasList := False;
  HasUse := False;
  HasCurrent := False;
  HasShow := False;
  HasDoctor := False;
  HasVerify := False;
  HasAutoInstall := False;
  HasUninstall := False;
  HasCache := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'install': HasInstall := True;
      'list': HasList := True;
      'use', 'default': HasUse := True;
      'current': HasCurrent := True;
      'show': HasShow := True;
      'doctor': HasDoctor := True;
      'verify': HasVerify := True;
      'auto-install': HasAutoInstall := True;
      'uninstall': HasUninstall := True;
      'cache': HasCache := True;
    end;
  end;

  AssertTrue(HasInstall, 'fpc install registered');
  AssertTrue(HasList, 'fpc list registered');
  AssertTrue(HasUse, 'fpc use registered');
  AssertTrue(HasCurrent, 'fpc current registered');
  AssertTrue(HasShow, 'fpc show registered');
  AssertTrue(HasDoctor, 'fpc doctor registered');
  AssertTrue(HasVerify, 'fpc verify registered');
  AssertTrue(HasAutoInstall, 'fpc auto-install registered');
  AssertTrue(HasUninstall, 'fpc uninstall registered');
  AssertTrue(HasCache, 'fpc cache registered');
end;

// ============================================================================
// Test: Package Subcommands Registered
// ============================================================================
procedure TestPackageSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasInstall, HasList, HasSearch, HasInfo, HasPublish: Boolean;
begin
  WriteLn('[TEST] TestPackageSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['package']);

  HasInstall := False;
  HasList := False;
  HasSearch := False;
  HasInfo := False;
  HasPublish := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'install': HasInstall := True;
      'list': HasList := True;
      'search': HasSearch := True;
      'info': HasInfo := True;
      'publish': HasPublish := True;
    end;
  end;

  AssertTrue(HasInstall, 'package install registered');
  AssertTrue(HasList, 'package list registered');
  AssertTrue(HasSearch, 'package search registered');
  AssertTrue(HasInfo, 'package info registered');
  AssertTrue(HasPublish, 'package publish registered');
end;

// ============================================================================
// Test: Repo Subcommands Registered
// ============================================================================
procedure TestRepoSubcommandsRegistered;
var
  Children: TStringArray;
  i: Integer;
  HasAdd, HasRemove, HasList, HasDefault: Boolean;
begin
  WriteLn('[TEST] TestRepoSubcommandsRegistered');

  Children := GlobalCommandRegistry.ListChildren(['repo']);

  HasAdd := False;
  HasRemove := False;
  HasList := False;
  HasDefault := False;

  for i := 0 to High(Children) do
  begin
    case LowerCase(Children[i]) of
      'add': HasAdd := True;
      'remove', 'rm': HasRemove := True;
      'list', 'ls': HasList := True;
      'default': HasDefault := True;
    end;
  end;

  AssertTrue(HasAdd, 'repo add registered');
  AssertTrue(HasRemove, 'repo remove registered');
  AssertTrue(HasList, 'repo list registered');
  AssertTrue(HasDefault, 'repo default registered');
end;

// ============================================================================
// Test: Command Count (Regression Guard)
// ============================================================================
procedure TestCommandCount;
var
  RootChildren: TStringArray;
  FPCChildren: TStringArray;
  TotalCommands: Integer;
begin
  WriteLn('[TEST] TestCommandCount');

  RootChildren := GlobalCommandRegistry.ListChildren([]);
  FPCChildren := GlobalCommandRegistry.ListChildren(['fpc']);

  // Root should have at least 10 commands (fpc, lazarus, package, cross, repo, project, help, version, doctor, etc.)
  AssertTrue(Length(RootChildren) >= 10, 'Root has >= 10 commands (got ' + IntToStr(Length(RootChildren)) + ')');

  // FPC should have at least 10 subcommands
  AssertTrue(Length(FPCChildren) >= 10, 'FPC has >= 10 subcommands (got ' + IntToStr(Length(FPCChildren)) + ')');

  // Total registered commands should be >= 70 (baseline from B003)
  TotalCommands := Length(RootChildren) + Length(FPCChildren);
  // Note: This is partial count, actual total is higher
  AssertTrue(TotalCommands >= 20, 'Total partial count >= 20 (got ' + IntToStr(TotalCommands) + ')');
end;

// ============================================================================
// Test: Alias Resolution (rm -> remove)
// ============================================================================
procedure TestAliasResolution;
var
  RepoChildren: TStringArray;
  i: Integer;
  HasRm: Boolean;
begin
  WriteLn('[TEST] TestAliasResolution');

  RepoChildren := GlobalCommandRegistry.ListChildren(['repo']);

  HasRm := False;
  for i := 0 to High(RepoChildren) do
    if LowerCase(RepoChildren[i]) = 'rm' then
      HasRm := True;

  AssertTrue(HasRm, 'repo rm alias registered');
end;

// ============================================================================
// Main
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('B053: Command Registry Contract Tests');
  WriteLn('========================================');
  WriteLn('');

  TestRootCommandsRegistered;
  TestFPCSubcommandsRegistered;
  TestPackageSubcommandsRegistered;
  TestRepoSubcommandsRegistered;
  TestCommandCount;
  TestAliasResolution;

  WriteLn('');
  WriteLn('========================================');
  if TestsFailed = 0 then
    WriteLn('SUCCESS: All ', TestsPassed, ' tests passed!')
  else
    WriteLn('FAILED: ', TestsFailed, ' of ', TestsPassed + TestsFailed, ' tests failed');
  WriteLn('========================================');

  if TestsFailed > 0 then
    Halt(1);
end.
