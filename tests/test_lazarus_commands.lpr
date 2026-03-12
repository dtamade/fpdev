program test_lazarus_commands;

{$mode objfpc}{$H+}

{
  B096: Tests for lazarus command group registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
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
  fpdev.cmd.lazarus.help;

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

procedure TestLazarusRootRegistered;
begin
  Check(HasSubcommand([], 'lazarus'), 'lazarus: root registered');
end;

{ --- Lazarus Subcommand Tests --- }

procedure TestLazarusListRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'list'), 'lazarus list: registered');
end;

procedure TestLazarusCurrentRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'current'), 'lazarus current: registered');
end;

procedure TestLazarusUseRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'use'), 'lazarus use: registered');
end;

procedure TestLazarusDefaultAliasRegistered;
begin
  Check(not HasSubcommand(['lazarus'], 'default'), 'lazarus default alias removed');
end;

procedure TestLazarusRunRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'run'), 'lazarus run: registered');
end;

procedure TestLazarusTestRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'test'), 'lazarus test: registered');
end;

procedure TestLazarusInstallRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'install'), 'lazarus install: registered');
end;

procedure TestLazarusUninstallRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'uninstall'), 'lazarus uninstall: registered');
end;

procedure TestLazarusShowRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'show'), 'lazarus show: registered');
end;

procedure TestLazarusConfigureRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'configure'), 'lazarus configure: registered');
end;

procedure TestLazarusDoctorRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'doctor'), 'lazarus doctor: registered');
end;

procedure TestLazarusUpdateRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'update'), 'lazarus update: registered');
end;

procedure TestLazarusHelpRegistered;
begin
  Check(HasSubcommand(['lazarus'], 'help'), 'lazarus help: registered');
end;

{ --- Count Tests --- }

procedure TestLazarusSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['lazarus']);
  Check(Length(Children) >= 12, 'lazarus: at least 12 subcommands');
end;

begin
  WriteLn('=== Lazarus Commands Unit Tests ===');
  WriteLn;

  // Root
  TestLazarusRootRegistered;

  // Lazarus subcommands
  TestLazarusListRegistered;
  TestLazarusCurrentRegistered;
  TestLazarusUseRegistered;
  TestLazarusDefaultAliasRegistered;
  TestLazarusRunRegistered;
  TestLazarusTestRegistered;
  TestLazarusInstallRegistered;
  TestLazarusUninstallRegistered;
  TestLazarusShowRegistered;
  TestLazarusConfigureRegistered;
  TestLazarusDoctorRegistered;
  TestLazarusUpdateRegistered;
  TestLazarusHelpRegistered;

  // Count test
  TestLazarusSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
