program test_repo_commands;

{$mode objfpc}{$H+}

{
  B099: Tests for repo command group registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
  fpdev.cmd.repo.root,
  fpdev.cmd.repo.add,
  fpdev.cmd.repo.list,
  fpdev.cmd.repo.remove,
  fpdev.cmd.repo.use,
  fpdev.cmd.repo.show,
  fpdev.cmd.repo.versions,
  fpdev.cmd.repo.help;

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

procedure TestRepoRootRegistered;
begin
  Check(HasSubcommand(['system'], 'repo'), 'system repo: root registered');
end;

{ --- Repo Subcommand Tests --- }

procedure TestRepoAddRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'add'), 'system repo add: registered');
end;

procedure TestRepoListRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'list'), 'system repo list: registered');
end;

procedure TestRepoLsAliasRegistered;
begin
  Check(not HasSubcommand(['system', 'repo'], 'ls'), 'system repo ls alias removed');
end;

procedure TestRepoRemoveRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'remove'), 'system repo remove: registered');
end;

procedure TestRepoRmAliasRegistered;
begin
  Check(not HasSubcommand(['system', 'repo'], 'rm'), 'system repo rm alias removed');
end;

procedure TestRepoUseRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'use'), 'system repo use: registered');
end;

procedure TestRepoShowRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'show'), 'system repo show: registered');
end;

procedure TestRepoVersionsRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'versions'), 'system repo versions: registered');
end;

procedure TestRepoHelpRegistered;
begin
  Check(HasSubcommand(['system', 'repo'], 'help'), 'system repo help: registered');
end;

{ --- Count Tests --- }

procedure TestRepoSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['system', 'repo']);
  Check(Length(Children) >= 7, 'system repo: at least 7 subcommands');
end;

begin
  WriteLn('=== Repo Commands Unit Tests ===');
  WriteLn;

  // Root
  TestRepoRootRegistered;

  // Repo subcommands
  TestRepoAddRegistered;
  TestRepoListRegistered;
  TestRepoLsAliasRegistered;
  TestRepoRemoveRegistered;
  TestRepoRmAliasRegistered;
  TestRepoUseRegistered;
  TestRepoShowRegistered;
  TestRepoVersionsRegistered;
  TestRepoHelpRegistered;

  // Count test
  TestRepoSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
