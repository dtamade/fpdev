program test_project_commands;

{$mode objfpc}{$H+}

{
  B098: Tests for project command group registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
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

procedure TestProjectRootRegistered;
begin
  Check(HasSubcommand([], 'project'), 'project: root registered');
end;

procedure TestProjectProjAliasRegistered;
begin
  Check(HasSubcommand([], 'proj'), 'proj: alias registered');
end;

{ --- Project Subcommand Tests --- }

procedure TestProjectNewRegistered;
begin
  Check(HasSubcommand(['project'], 'new'), 'project new: registered');
end;

procedure TestProjectListRegistered;
begin
  Check(HasSubcommand(['project'], 'list'), 'project list: registered');
end;

procedure TestProjectInfoRegistered;
begin
  Check(HasSubcommand(['project'], 'info'), 'project info: registered');
end;

procedure TestProjectBuildRegistered;
begin
  Check(HasSubcommand(['project'], 'build'), 'project build: registered');
end;

procedure TestProjectCleanRegistered;
begin
  Check(HasSubcommand(['project'], 'clean'), 'project clean: registered');
end;

procedure TestProjectTestRegistered;
begin
  Check(HasSubcommand(['project'], 'test'), 'project test: registered');
end;

procedure TestProjectRunRegistered;
begin
  Check(HasSubcommand(['project'], 'run'), 'project run: registered');
end;

procedure TestProjectHelpRegistered;
begin
  Check(HasSubcommand(['project'], 'help'), 'project help: registered');
end;

{ --- Count Tests --- }

procedure TestProjectSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['project']);
  Check(Length(Children) >= 8, 'project: at least 8 subcommands');
end;

begin
  WriteLn('=== Project Commands Unit Tests ===');
  WriteLn;

  // Root
  TestProjectRootRegistered;
  TestProjectProjAliasRegistered;

  // Project subcommands
  TestProjectNewRegistered;
  TestProjectListRegistered;
  TestProjectInfoRegistered;
  TestProjectBuildRegistered;
  TestProjectCleanRegistered;
  TestProjectTestRegistered;
  TestProjectRunRegistered;
  TestProjectHelpRegistered;

  // Count test
  TestProjectSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
