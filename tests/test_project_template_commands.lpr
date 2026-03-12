program test_project_template_commands;

{$mode objfpc}{$H+}

{
  B243-B246: Tests for project template command registration and subcommands
}

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.cmd.project.root,
  fpdev.cmd.project.template.root,
  fpdev.cmd.project.template.list,
  fpdev.cmd.project.template.install,
  fpdev.cmd.project.template.remove,
  fpdev.cmd.project.template.update;

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

procedure TestTemplateRootRegistered;
begin
  Check(HasSubcommand(['project'], 'template'), 'project template: registered as subcommand');
end;

procedure TestTemplateAliasRegistered;
begin
  Check(not HasSubcommand(['project'], 'tpl'), 'project tpl alias removed');
end;

{ --- Subcommand Registration Tests --- }

procedure TestTemplateListRegistered;
begin
  Check(HasSubcommand(['project','template'], 'list'), 'project template list: registered');
end;

procedure TestTemplateListAliasRegistered;
begin
  Check(not HasSubcommand(['project','template'], 'ls'), 'project template ls alias removed');
end;

procedure TestTemplateInstallRegistered;
begin
  Check(HasSubcommand(['project','template'], 'install'), 'project template install: registered');
end;

procedure TestTemplateRemoveRegistered;
begin
  Check(HasSubcommand(['project','template'], 'remove'), 'project template remove: registered');
end;

procedure TestTemplateRemoveAliasRegistered;
begin
  Check(not HasSubcommand(['project','template'], 'rm'), 'project template rm alias removed');
end;

procedure TestTemplateUpdateRegistered;
begin
  Check(HasSubcommand(['project','template'], 'update'), 'project template update: registered');
end;

{ --- Count Tests --- }

procedure TestTemplateSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['project','template']);
  Check(Length(Children) >= 4, 'project template: at least 4 subcommands (list, install, remove, update)');
end;

{ --- Command Name Tests --- }

procedure TestListCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateListCommand.Create;
  Check(Cmd.Name = 'list', 'template list: Name returns "list"');
end;

procedure TestInstallCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateInstallCommand.Create;
  Check(Cmd.Name = 'install', 'template install: Name returns "install"');
end;

procedure TestRemoveCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateRemoveCommand.Create;
  Check(Cmd.Name = 'remove', 'template remove: Name returns "remove"');
end;

procedure TestUpdateCommandName;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateUpdateCommand.Create;
  Check(Cmd.Name = 'update', 'template update: Name returns "update"');
end;

{ --- FindSub Tests --- }

procedure TestListFindSubNil;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateListCommand.Create;
  Check(Cmd.FindSub('anything') = nil, 'template list: FindSub returns nil');
end;

procedure TestInstallFindSubNil;
var
  Cmd: ICommand;
begin
  Cmd := TProjectTemplateInstallCommand.Create;
  Check(Cmd.FindSub('anything') = nil, 'template install: FindSub returns nil');
end;

begin
  WriteLn('=== Project Template Commands Unit Tests ===');
  WriteLn;

  TestProjectRootRegistered;
  TestTemplateRootRegistered;
  TestTemplateAliasRegistered;
  TestTemplateListRegistered;
  TestTemplateListAliasRegistered;
  TestTemplateInstallRegistered;
  TestTemplateRemoveRegistered;
  TestTemplateRemoveAliasRegistered;
  TestTemplateUpdateRegistered;
  TestTemplateSubcommandCount;
  TestListCommandName;
  TestInstallCommandName;
  TestRemoveCommandName;
  TestUpdateCommandName;
  TestListFindSubNil;
  TestInstallFindSubNil;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
