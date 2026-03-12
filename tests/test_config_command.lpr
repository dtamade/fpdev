program test_config_command;

{$mode objfpc}{$H+}

{
  B088: Basic tests for config command registration and structure
}

uses
  SysUtils, Classes,
  fpdev.command.intf,
  fpdev.command.registry,
  fpdev.cmd.config,
  fpdev.cmd.config.show,
  fpdev.cmd.config.get,
  fpdev.cmd.config.setvalue,
  fpdev.cmd.config.export,
  fpdev.cmd.config.import,
  fpdev.cmd.config.list;

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

function HasCommand(const APath: array of string; const AName: string): Boolean;
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

{ --- Command Registration Tests --- }

procedure TestConfigRegistered;
begin
  Check(HasCommand(['system'], 'config'), 'config: system root registered');
  Check(HasCommand(['system', 'config'], 'show'), 'config: show registered');
  Check(HasCommand(['system', 'config'], 'get'), 'config: get registered');
  Check(HasCommand(['system', 'config'], 'set'), 'config: set registered');
  Check(HasCommand(['system', 'config'], 'export'), 'config: export registered');
  Check(HasCommand(['system', 'config'], 'import'), 'config: import registered');
  Check(HasCommand(['system', 'config'], 'list'), 'config: list registered');
end;

{ --- Command Interface Tests --- }

procedure TestConfigCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreateConfigCommand;
  Check(Cmd.Name = 'config', 'config: Name() returns "config"');
end;

procedure TestConfigCommandAliases;
var
  Cmd: ICommand;
  Aliases: TStringArray;
begin
  Cmd := CreateConfigCommand;
  Aliases := Cmd.Aliases;
  Check(Aliases = nil, 'config: no aliases');
end;

procedure TestConfigCommandFindSubNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateConfigCommand;
  Check(Cmd.FindSub('show') = nil, 'config: FindSub returns nil (internal handling)');
end;

begin
  WriteLn('=== Config Command Unit Tests ===');
  WriteLn;

  TestConfigRegistered;
  TestConfigCommandName;
  TestConfigCommandAliases;
  TestConfigCommandFindSubNil;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
