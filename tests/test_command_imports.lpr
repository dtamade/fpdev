program test_command_imports;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.command.registry,
  fpdev.command.imports;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function Contains(const Items: TStringArray; const Value: string): Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to High(Items) do
    if SameText(Items[Index], Value) then
      Exit(True);
end;

procedure AssertTrue(Condition: Boolean; const Message: string);
begin
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', Message);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', Message);
  end;
end;

procedure TestRootCommandsAreRegistered;
var
  RootCommands: TStringArray;
begin
  RootCommands := GlobalCommandRegistry.ListChildren([]);
  AssertTrue(not Contains(RootCommands, 'help'), 'help root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'version'), 'version root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'cache'), 'cache root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'default'), 'default root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'doctor'), 'doctor root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'show'), 'show root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'shell-hook'), 'shell-hook root command no longer registered');
  AssertTrue(not Contains(RootCommands, 'resolve-version'), 'resolve-version root command no longer registered');
  AssertTrue(Contains(RootCommands, 'fpc'), 'fpc root command registered');
  AssertTrue(Contains(RootCommands, 'package'), 'package root command registered');
  AssertTrue(Contains(RootCommands, 'project'), 'project root command registered');
  AssertTrue(Contains(RootCommands, 'lazarus'), 'lazarus root command registered');
  AssertTrue(Contains(RootCommands, 'cross'), 'cross root command registered');
  AssertTrue(Contains(RootCommands, 'system'), 'system root command registered');
end;

procedure TestNestedCommandsAreRegistered;
var
  PackageCommands: TStringArray;
  SystemCommands: TStringArray;
  RepoCommands: TStringArray;
  FpcCommands: TStringArray;
begin
  PackageCommands := GlobalCommandRegistry.ListChildren(['package']);
  AssertTrue(Contains(PackageCommands, 'install'), 'package install command registered');
  AssertTrue(Contains(PackageCommands, 'repo'), 'package repo namespace registered');

  SystemCommands := GlobalCommandRegistry.ListChildren(['system']);
  AssertTrue(Contains(SystemCommands, 'config'), 'system config command registered');
  AssertTrue(Contains(SystemCommands, 'help'), 'system help command registered');
  AssertTrue(Contains(SystemCommands, 'version'), 'system version command registered');
  AssertTrue(Contains(SystemCommands, 'toolchain'), 'system toolchain namespace registered');
  SystemCommands := GlobalCommandRegistry.ListChildren(['system', 'config']);
  AssertTrue(Contains(SystemCommands, 'show'), 'system config show command registered');
  AssertTrue(Contains(SystemCommands, 'get'), 'system config get command registered');
  AssertTrue(Contains(SystemCommands, 'set'), 'system config set command registered');
  AssertTrue(Contains(SystemCommands, 'export'), 'system config export command registered');
  AssertTrue(Contains(SystemCommands, 'import'), 'system config import command registered');
  AssertTrue(Contains(SystemCommands, 'list'), 'system config list command registered');

  SystemCommands := GlobalCommandRegistry.ListChildren(['system']);
  AssertTrue(Contains(SystemCommands, 'env'), 'system env command registered');
  AssertTrue(Contains(SystemCommands, 'index'), 'system index command registered');
  AssertTrue(Contains(SystemCommands, 'perf'), 'system perf command registered');
  AssertTrue(Contains(SystemCommands, 'cache'), 'system cache command registered');
  AssertTrue(Contains(SystemCommands, 'doctor'), 'system doctor command registered');
  SystemCommands := GlobalCommandRegistry.ListChildren(['system', 'cache']);
  AssertTrue(Contains(SystemCommands, 'status'), 'system cache status command registered');
  AssertTrue(Contains(SystemCommands, 'stats'), 'system cache stats command registered');
  AssertTrue(Contains(SystemCommands, 'path'), 'system cache path command registered');

  SystemCommands := GlobalCommandRegistry.ListChildren(['system', 'index']);
  AssertTrue(Contains(SystemCommands, 'status'), 'system index status command registered');
  AssertTrue(Contains(SystemCommands, 'show'), 'system index show command registered');
  AssertTrue(Contains(SystemCommands, 'update'), 'system index update command registered');

  SystemCommands := GlobalCommandRegistry.ListChildren(['system', 'env']);
  AssertTrue(Contains(SystemCommands, 'data-root'), 'system env data-root command registered');
  AssertTrue(Contains(SystemCommands, 'vars'), 'system env vars command registered');
  AssertTrue(Contains(SystemCommands, 'path'), 'system env path command registered');
  AssertTrue(Contains(SystemCommands, 'export'), 'system env export command registered');
  AssertTrue(Contains(SystemCommands, 'hook'), 'system env hook command registered');
  AssertTrue(Contains(SystemCommands, 'resolve'), 'system env resolve command registered');

  SystemCommands := GlobalCommandRegistry.ListChildren(['system', 'toolchain']);
  AssertTrue(Contains(SystemCommands, 'check'), 'system toolchain check command registered');
  AssertTrue(Contains(SystemCommands, 'self-test'), 'system toolchain self-test command registered');
  AssertTrue(Contains(SystemCommands, 'fetch'), 'system toolchain fetch command registered');
  AssertTrue(Contains(SystemCommands, 'extract'), 'system toolchain extract command registered');
  AssertTrue(Contains(SystemCommands, 'ensure-source'), 'system toolchain ensure-source command registered');
  AssertTrue(Contains(SystemCommands, 'import-bundle'), 'system toolchain import-bundle command registered');

  RepoCommands := GlobalCommandRegistry.ListChildren(['package', 'repo']);
  AssertTrue(Contains(RepoCommands, 'add'), 'package repo add command registered');
  AssertTrue(Contains(RepoCommands, 'list'), 'package repo list command registered');

  FpcCommands := GlobalCommandRegistry.ListChildren(['fpc']);
  AssertTrue(Contains(FpcCommands, 'install'), 'fpc install command registered');
  AssertTrue(Contains(FpcCommands, 'status'), 'fpc status command registered');
  AssertTrue(Contains(FpcCommands, 'cache'), 'fpc cache namespace registered');
  AssertTrue(Contains(FpcCommands, 'policy'), 'fpc policy namespace registered');

  FpcCommands := GlobalCommandRegistry.ListChildren(['fpc', 'policy']);
  AssertTrue(Contains(FpcCommands, 'check'), 'fpc policy check command registered');
end;

begin
  TestRootCommandsAreRegistered;
  TestNestedCommandsAreRegistered;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' / ', TestsPassed + TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
