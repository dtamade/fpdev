program test_cli_fpc_info;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_fpc_info - CLI integration tests for fpdev fpc list/use/current/show
================================================================================

  Tests the FPC informational commands' CLI behavior:
  - list: version listing with --all, --json flags
  - use: version switching with --ensure, aliases, error messages
  - current: display current version with --json
  - show: display version info with version argument

  Uses shared test_cli_helpers unit for TStringOutput/TTestContext.

  B188: FPC info commands CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.config.interfaces,
  fpdev.output.intf, fpdev.exitcodes,
  fpdev.cmd.fpc,             // Register 'fpc' root command
  fpdev.cmd.fpc.list,
  fpdev.cmd.fpc.use,
  fpdev.cmd.fpc.current,
  fpdev.cmd.fpc.show,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

{ ===== Group 1: fpc list - Command Basics ===== }

procedure TestListCommandName;
var
  Cmd: TFPCListCommand;
begin
  Cmd := TFPCListCommand.Create;
  try
    Check('list: name is "list"', Cmd.Name = 'list');
  finally
    Cmd.Free;
  end;
end;

procedure TestListAliasesNil;
var
  Cmd: TFPCListCommand;
begin
  Cmd := TFPCListCommand.Create;
  try
    Check('list: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestListFindSubNil;
var
  Cmd: TFPCListCommand;
begin
  Cmd := TFPCListCommand.Create;
  try
    Check('list: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: fpc list - Help ===== }

procedure TestListHelpFlag;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('list --help returns EXIT_OK', Ret = EXIT_OK);
    Check('list --help shows usage', StdOut.Contains('list'));
    Check('list --help usage advertises optional json flag',
      StdOut.Contains('Usage: fpdev fpc list [--all] [--json]'));
    Check('list --help shows --all option', StdOut.Contains('all'));
    Check('list --help shows --json option', StdOut.Contains('json'));
  finally
    Cmd.Free;
  end;
end;

procedure TestListHelpShortFlag;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('list -h returns EXIT_OK', Ret = EXIT_OK);
    Check('list -h shows usage', StdOut.Contains('list'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: fpc list - Execution ===== }

procedure TestListNoArgs;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    // No args = list installed versions (may be empty, but valid)
    Check('list no args returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestListJsonFlag;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json returns EXIT_OK', Ret = EXIT_OK);
    // JSON output should contain "versions" key
    Check('list --json contains versions key', StdOut.Contains('versions'));
  finally
    Cmd.Free;
  end;
end;

procedure TestListJsonOutputUsesNullWhenDefaultUnset;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('list --json default-unset returns EXIT_OK', Ret = EXIT_OK);
    Check('list --json default-unset uses has_default false',
      StdOut.Contains('"has_default" : false'));
    Check('list --json default-unset uses null default',
      StdOut.Contains('"default" : null'));
  finally
    Cmd.Free;
  end;
end;

procedure TestListUnexpectedArg;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('list unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('list unexpected arg shows usage', StdErr.Contains('list'));
    Check('list unexpected arg usage advertises optional json flag',
      StdErr.Contains('Usage: fpdev fpc list [--all] [--json]'));
    Check('list unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestListUnknownOption;
var
  Cmd: TFPCListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCListCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('list unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('list unknown option shows usage', StdErr.Contains('list'));
    Check('list unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: fpc list - Registration ===== }

procedure TestListRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'list' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc list is registered in command registry', Found);
end;

{ ===== Group 5: fpc use - Command Basics ===== }

procedure TestUseCommandName;
var
  Cmd: TFPCUseCommand;
begin
  Cmd := TFPCUseCommand.Create;
  try
    Check('use: name is "use"', Cmd.Name = 'use');
  finally
    Cmd.Free;
  end;
end;

procedure TestUseHasDefaultAlias;
var
  Cmd: TFPCUseCommand;
  A: TStringArray;
begin
  Cmd := TFPCUseCommand.Create;
  try
    A := Cmd.Aliases;
    Check('use: aliases is nil', A = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestUseFindSubNil;
var
  Cmd: TFPCUseCommand;
begin
  Cmd := TFPCUseCommand.Create;
  try
    Check('use: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: fpc use - Help ===== }

procedure TestUseHelpFlag;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('use --help returns EXIT_OK', Ret = EXIT_OK);
    Check('use --help shows usage', StdOut.Contains('use'));
    Check('use --help shows --ensure option', StdOut.Contains('ensure'));
    Check('use --help shows version aliases', StdOut.Contains('stable'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUseHelpShortFlag;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('use -h returns EXIT_OK', Ret = EXIT_OK);
    Check('use -h shows usage', StdOut.Contains('use'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUseHelpUnexpectedArg;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('use help unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('use help unexpected arg shows usage', StdErr.Contains('use'));
    Check('use help unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 7: fpc use - Missing Arguments ===== }

procedure TestUseMissingVersion;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    // No args, no default configured -> should show error
    Check('use no args returns error', Ret <> EXIT_OK);
    Check('use no args shows error message',
      StdErr.Contains('version') or StdErr.Contains('Usage') or StdErr.Contains('Error'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUseUnexpectedArg;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('use unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('use unexpected arg shows usage', StdErr.Contains('use'));
    Check('use unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestUseUnknownOption;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--unknown'], Ctx);
    Check('use unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('use unknown option shows usage', StdErr.Contains('use'));
    Check('use unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 8: fpc use - Not-installed version ===== }

procedure TestUseNotInstalledVersion;
var
  Cmd: TFPCUseCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUseCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    // Version not installed, no --ensure -> should fail
    Check('use non-existent version returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('use non-existent shows install hint', StdErr.Contains('install'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 9: fpc use - Registration ===== }

procedure TestUseRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'use' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc use is registered in command registry', Found);
end;

{ ===== Group 10: fpc current - Command Basics ===== }

procedure TestCurrentCommandName;
var
  Cmd: TFPCCurrentCommand;
begin
  Cmd := TFPCCurrentCommand.Create;
  try
    Check('current: name is "current"', Cmd.Name = 'current');
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentAliasesNil;
var
  Cmd: TFPCCurrentCommand;
begin
  Cmd := TFPCCurrentCommand.Create;
  try
    Check('current: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentFindSubNil;
var
  Cmd: TFPCCurrentCommand;
begin
  Cmd := TFPCCurrentCommand.Create;
  try
    Check('current: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc current - Help ===== }

procedure TestCurrentHelpFlag;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('current --help returns EXIT_OK', Ret = EXIT_OK);
    Check('current --help shows usage', StdOut.Contains('current'));
    Check('current --help shows --json option', StdOut.Contains('json'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentHelpShortFlag;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('current -h returns EXIT_OK', Ret = EXIT_OK);
    Check('current -h shows usage', StdOut.Contains('current'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentHelpAdvertisesJsonUsage;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('current --help usage advertises optional json flag', Ret = EXIT_OK);
    Check('current --help usage advertises optional json flag',
      StdOut.Contains('Usage: fpdev fpc current [--json]'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 12: fpc current - Execution ===== }

procedure TestCurrentNoArgs;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // No default configured -> should show "no version" or empty
    Check('current no args returns EXIT_OK', Ret = EXIT_OK);
    Check('current no args produces output', Length(AllOutput) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentJsonFlag;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('current --json returns EXIT_OK', Ret = EXIT_OK);
    Check('current --json contains has_default key', StdOut.Contains('has_default'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentJsonOutputUsesNullWhenDefaultUnset;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--json'], Ctx);
    Check('current --json default-unset returns EXIT_OK', Ret = EXIT_OK);
    Check('current --json default-unset uses has_default false',
      StdOut.Contains('"has_default" : false'));
    Check('current --json default-unset uses null version',
      StdOut.Contains('"version" : null'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentUnexpectedArg;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('current unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('current unexpected arg usage advertises optional json flag',
      StdErr.Contains('Usage: fpdev fpc current [--json]'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCurrentUnknownOption;
var
  Cmd: TFPCCurrentCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCurrentCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('current unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 13: fpc current - Registration ===== }

procedure TestCurrentRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'current' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc current is registered in command registry', Found);
end;

{ ===== Group 14: fpc show - Command Basics ===== }

procedure TestShowCommandName;
var
  Cmd: TFPCShowCommand;
begin
  Cmd := TFPCShowCommand.Create;
  try
    Check('show: name is "show"', Cmd.Name = 'show');
  finally
    Cmd.Free;
  end;
end;

procedure TestShowAliasesNil;
var
  Cmd: TFPCShowCommand;
begin
  Cmd := TFPCShowCommand.Create;
  try
    Check('show: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestShowFindSubNil;
var
  Cmd: TFPCShowCommand;
begin
  Cmd := TFPCShowCommand.Create;
  try
    Check('show: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 15: fpc show - Help ===== }

procedure TestShowHelpFlag;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('show --help returns EXIT_OK', Ret = EXIT_OK);
    Check('show --help shows usage', StdOut.Contains('show'));
  finally
    Cmd.Free;
  end;
end;

procedure TestShowHelpShortFlag;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('show -h returns EXIT_OK', Ret = EXIT_OK);
    Check('show -h shows usage', StdOut.Contains('show'));
  finally
    Cmd.Free;
  end;
end;

procedure TestShowHelpUnexpectedArg;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['--help', 'extra'], Ctx);
    Check('show help unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('show help unexpected arg shows usage', StdErr.Contains('show'));
    Check('show help unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 16: fpc show - Missing Arguments ===== }

procedure TestShowMissingVersion;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('show no args returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('show no args shows error on stderr', StdErr.Contains('version'));
  finally
    Cmd.Free;
  end;
end;

procedure TestShowUnexpectedArg;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', 'extra'], Ctx);
    Check('show unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('show unexpected arg shows usage', StdErr.Contains('show'));
    Check('show unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestShowUnknownOption;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--unknown'], Ctx);
    Check('show unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('show unknown option shows usage', StdErr.Contains('show'));
    Check('show unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 17: fpc show - Execution ===== }

procedure TestShowNonExistentVersion;
var
  Cmd: TFPCShowCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCShowCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    Check('show non-existent EXIT_NOT_FOUND', Ret = EXIT_NOT_FOUND);
    Check('show non-existent writes stderr', StdErr.Contains('Unsupported FPC version'));
    Check('show non-existent does not write error to stdout', not StdOut.Contains('Unsupported FPC version'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 18: fpc show - Registration ===== }

procedure TestShowRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'show' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc show is registered in command registry', Found);
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Info Commands CLI Tests (list/use/current/show) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_fpc_info');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    // Group 1: fpc list basics
    WriteLn('--- fpc list: Command Basics ---');
    TestListCommandName;
    TestListAliasesNil;
    TestListFindSubNil;

    // Group 2: fpc list help
    WriteLn('');
    WriteLn('--- fpc list: Help Output ---');
    TestListHelpFlag;
    TestListHelpShortFlag;

    // Group 3: fpc list execution
    WriteLn('');
    WriteLn('--- fpc list: Execution ---');
    TestListNoArgs;
    TestListJsonFlag;
    TestListJsonOutputUsesNullWhenDefaultUnset;
    TestListUnexpectedArg;
    TestListUnknownOption;

    // Group 4: fpc list registration
    WriteLn('');
    WriteLn('--- fpc list: Registration ---');
    TestListRegistration;

    // Group 5: fpc use basics
    WriteLn('');
    WriteLn('--- fpc use: Command Basics ---');
    TestUseCommandName;
    TestUseHasDefaultAlias;
    TestUseFindSubNil;

    // Group 6: fpc use help
    WriteLn('');
    WriteLn('--- fpc use: Help Output ---');
    TestUseHelpFlag;
    TestUseHelpShortFlag;
    TestUseHelpUnexpectedArg;

    // Group 7: fpc use missing args
    WriteLn('');
    WriteLn('--- fpc use: Argument Validation ---');
    TestUseMissingVersion;
    TestUseUnexpectedArg;
    TestUseUnknownOption;

    // Group 8: fpc use not-installed version
    WriteLn('');
    WriteLn('--- fpc use: Not-installed Version ---');
    TestUseNotInstalledVersion;

    // Group 9: fpc use registration
    WriteLn('');
    WriteLn('--- fpc use: Registration ---');
    TestUseRegistration;

    // Group 10: fpc current basics
    WriteLn('');
    WriteLn('--- fpc current: Command Basics ---');
    TestCurrentCommandName;
    TestCurrentAliasesNil;
    TestCurrentFindSubNil;

    // Group 11: fpc current help
    WriteLn('');
    WriteLn('--- fpc current: Help Output ---');
    TestCurrentHelpFlag;
    TestCurrentHelpShortFlag;
    TestCurrentHelpAdvertisesJsonUsage;

    // Group 12: fpc current execution
    WriteLn('');
    WriteLn('--- fpc current: Execution ---');
    TestCurrentNoArgs;
    TestCurrentJsonFlag;
    TestCurrentJsonOutputUsesNullWhenDefaultUnset;
    TestCurrentUnexpectedArg;
    TestCurrentUnknownOption;

    // Group 13: fpc current registration
    WriteLn('');
    WriteLn('--- fpc current: Registration ---');
    TestCurrentRegistration;

    // Group 14: fpc show basics
    WriteLn('');
    WriteLn('--- fpc show: Command Basics ---');
    TestShowCommandName;
    TestShowAliasesNil;
    TestShowFindSubNil;

    // Group 15: fpc show help
    WriteLn('');
    WriteLn('--- fpc show: Help Output ---');
    TestShowHelpFlag;
    TestShowHelpShortFlag;
    TestShowHelpUnexpectedArg;

    // Group 16: fpc show missing args
    WriteLn('');
    WriteLn('--- fpc show: Argument Validation ---');
    TestShowMissingVersion;
    TestShowUnexpectedArg;
    TestShowUnknownOption;

    // Group 17: fpc show execution
    WriteLn('');
    WriteLn('--- fpc show: Execution ---');
    TestShowNonExistentVersion;

    // Group 18: fpc show registration
    WriteLn('');
    WriteLn('--- fpc show: Registration ---');
    TestShowRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
