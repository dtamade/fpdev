program test_fpc_commands;

{$mode objfpc}{$H+}

{
  B095: Tests for fpc command group registration
}

uses
  SysUtils, Classes,
  fpdev.command.registry,
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
  fpdev.cmd.fpc.cache.path;

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

procedure TestFpcRootRegistered;
begin
  Check(HasSubcommand([], 'fpc'), 'fpc: root registered');
end;

{ --- FPC Subcommand Tests --- }

procedure TestFpcInstallRegistered;
begin
  Check(HasSubcommand(['fpc'], 'install'), 'fpc install: registered');
end;

procedure TestFpcAutoInstallRegistered;
begin
  Check(HasSubcommand(['fpc'], 'auto-install'), 'fpc auto-install: registered');
end;

procedure TestFpcListRegistered;
begin
  Check(HasSubcommand(['fpc'], 'list'), 'fpc list: registered');
end;

procedure TestFpcUseRegistered;
begin
  Check(HasSubcommand(['fpc'], 'use'), 'fpc use: registered');
end;

procedure TestFpcDefaultAliasRegistered;
begin
  Check(not HasSubcommand(['fpc'], 'default'), 'fpc default alias removed');
end;

procedure TestFpcDoctorRegistered;
begin
  Check(HasSubcommand(['fpc'], 'doctor'), 'fpc doctor: registered');
end;

procedure TestFpcCurrentRegistered;
begin
  Check(HasSubcommand(['fpc'], 'current'), 'fpc current: registered');
end;

procedure TestFpcShowRegistered;
begin
  Check(HasSubcommand(['fpc'], 'show'), 'fpc show: registered');
end;

procedure TestFpcTestRegistered;
begin
  Check(HasSubcommand(['fpc'], 'test'), 'fpc test: registered');
end;

procedure TestFpcVerifyRegistered;
begin
  Check(HasSubcommand(['fpc'], 'verify'), 'fpc verify: registered');
end;

procedure TestFpcUpdateRegistered;
begin
  Check(HasSubcommand(['fpc'], 'update'), 'fpc update: registered');
end;

procedure TestFpcUpdateManifestRegistered;
begin
  Check(HasSubcommand(['fpc'], 'update-manifest'), 'fpc update-manifest: registered');
end;

procedure TestFpcUninstallRegistered;
begin
  Check(HasSubcommand(['fpc'], 'uninstall'), 'fpc uninstall: registered');
end;

procedure TestFpcHelpRegistered;
begin
  Check(HasSubcommand(['fpc'], 'help'), 'fpc help: registered');
end;

procedure TestFpcCacheRegistered;
begin
  Check(HasSubcommand(['fpc'], 'cache'), 'fpc cache: registered');
end;

{ --- FPC Cache Subcommand Tests --- }

procedure TestFpcCacheListRegistered;
begin
  Check(HasSubcommand(['fpc', 'cache'], 'list'), 'fpc cache list: registered');
end;

procedure TestFpcCacheCleanRegistered;
begin
  Check(HasSubcommand(['fpc', 'cache'], 'clean'), 'fpc cache clean: registered');
end;

procedure TestFpcCacheStatsRegistered;
begin
  Check(HasSubcommand(['fpc', 'cache'], 'stats'), 'fpc cache stats: registered');
end;

procedure TestFpcCachePathRegistered;
begin
  Check(HasSubcommand(['fpc', 'cache'], 'path'), 'fpc cache path: registered');
end;

{ --- Count Tests --- }

procedure TestFpcSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Check(Length(Children) >= 14, 'fpc: at least 14 subcommands');
end;

procedure TestFpcCacheSubcommandCount;
var
  Children: TStringArray;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc', 'cache']);
  Check(Length(Children) >= 4, 'fpc cache: at least 4 subcommands');
end;

begin
  WriteLn('=== FPC Commands Unit Tests ===');
  WriteLn;

  // Root
  TestFpcRootRegistered;

  // FPC subcommands
  TestFpcInstallRegistered;
  TestFpcAutoInstallRegistered;
  TestFpcListRegistered;
  TestFpcUseRegistered;
  TestFpcDefaultAliasRegistered;
  TestFpcDoctorRegistered;
  TestFpcCurrentRegistered;
  TestFpcShowRegistered;
  TestFpcTestRegistered;
  TestFpcVerifyRegistered;
  TestFpcUpdateRegistered;
  TestFpcUpdateManifestRegistered;
  TestFpcUninstallRegistered;
  TestFpcHelpRegistered;
  TestFpcCacheRegistered;

  // FPC cache subcommands
  TestFpcCacheListRegistered;
  TestFpcCacheCleanRegistered;
  TestFpcCacheStatsRegistered;
  TestFpcCachePathRegistered;

  // Count tests
  TestFpcSubcommandCount;
  TestFpcCacheSubcommandCount;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Passed: ', TestsPassed);
  WriteLn('Failed: ', TestsFailed);
  WriteLn('Total:  ', TestsPassed + TestsFailed);

  if TestsFailed > 0 then
    Halt(1);
end.
