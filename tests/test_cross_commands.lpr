program test_cross_commands;

{$mode objfpc}{$H+}

{
  B087: Basic tests for cross command registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
  fpdev.cmd.cross.root,
  fpdev.cmd.cross.list,
  fpdev.cmd.cross.show,
  fpdev.cmd.cross.install,
  fpdev.cmd.cross.uninstall,
  fpdev.cmd.cross.enable,
  fpdev.cmd.cross.disable,
  fpdev.cmd.cross.help;

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

{ --- Command Registration Tests --- }

procedure TestCrossListRegistered;
begin
  Check(HasSubcommand(['cross'], 'list'), 'cross list: registered');
end;

procedure TestCrossShowRegistered;
begin
  Check(HasSubcommand(['cross'], 'show'), 'cross show: registered');
end;

procedure TestCrossInstallRegistered;
begin
  Check(HasSubcommand(['cross'], 'install'), 'cross install: registered');
end;

procedure TestCrossUninstallRegistered;
begin
  Check(HasSubcommand(['cross'], 'uninstall'), 'cross uninstall: registered');
end;

procedure TestCrossEnableRegistered;
begin
  Check(HasSubcommand(['cross'], 'enable'), 'cross enable: registered');
end;

procedure TestCrossDisableRegistered;
begin
  Check(HasSubcommand(['cross'], 'disable'), 'cross disable: registered');
end;

procedure TestCrossHelpRegistered;
begin
  Check(HasSubcommand(['cross'], 'help'), 'cross help: registered');
end;

{ --- Root Registration Tests --- }

procedure TestCrossRootRegistered;
begin
  Check(HasSubcommand([], 'cross'), 'cross: root registered');
end;

procedure TestCrossAliasXRegistered;
begin
  Check(HasSubcommand([], 'x'), 'x: alias registered');
end;

{ --- Count Tests --- }

procedure TestCrossSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['cross']);
  Check(Length(Children) >= 7, 'cross: at least 7 subcommands');
end;

begin
  WriteLn('=== Cross Commands Unit Tests ===');
  WriteLn;

  TestCrossRootRegistered;
  TestCrossAliasXRegistered;
  TestCrossListRegistered;
  TestCrossShowRegistered;
  TestCrossInstallRegistered;
  TestCrossUninstallRegistered;
  TestCrossEnableRegistered;
  TestCrossDisableRegistered;
  TestCrossHelpRegistered;
  TestCrossSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
