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
  fpdev.cmd.repo.default,
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
  Check(HasSubcommand([], 'repo'), 'repo: root registered');
end;

{ --- Repo Subcommand Tests --- }

procedure TestRepoAddRegistered;
begin
  Check(HasSubcommand(['repo'], 'add'), 'repo add: registered');
end;

procedure TestRepoListRegistered;
begin
  Check(HasSubcommand(['repo'], 'list'), 'repo list: registered');
end;

procedure TestRepoLsAliasRegistered;
begin
  Check(HasSubcommand(['repo'], 'ls'), 'repo ls: alias registered');
end;

procedure TestRepoRemoveRegistered;
begin
  Check(HasSubcommand(['repo'], 'remove'), 'repo remove: registered');
end;

procedure TestRepoRmAliasRegistered;
begin
  Check(HasSubcommand(['repo'], 'rm'), 'repo rm: alias registered');
end;

procedure TestRepoDefaultRegistered;
begin
  Check(HasSubcommand(['repo'], 'default'), 'repo default: registered');
end;

procedure TestRepoShowRegistered;
begin
  Check(HasSubcommand(['repo'], 'show'), 'repo show: registered');
end;

procedure TestRepoVersionsRegistered;
begin
  Check(HasSubcommand(['repo'], 'versions'), 'repo versions: registered');
end;

procedure TestRepoHelpRegistered;
begin
  Check(HasSubcommand(['repo'], 'help'), 'repo help: registered');
end;

{ --- Count Tests --- }

procedure TestRepoSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['repo']);
  Check(Length(Children) >= 9, 'repo: at least 9 subcommands');
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
  TestRepoDefaultRegistered;
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
