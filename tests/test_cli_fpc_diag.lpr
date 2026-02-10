program test_cli_fpc_diag;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_fpc_diag - CLI tests for fpdev fpc doctor/verify/cache commands
================================================================================

  Tests the FPC diagnostic/cache commands' CLI behavior:
  - doctor: environment check with help, execution
  - verify: installation verification with help, missing args
  - cache list/clean/stats/path: cache management commands

  Uses shared test_cli_helpers unit for TStringOutput/TTestContext.

  B189: FPC diagnostic commands CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.fpc,                // Register 'fpc' root command
  fpdev.cmd.fpc.doctor,
  fpdev.cmd.fpc.verify,
  fpdev.cmd.fpc.cache,          // Register 'fpc cache' root node
  fpdev.cmd.fpc.cache.list,
  fpdev.cmd.fpc.cache.clean,
  fpdev.cmd.fpc.cache.stats,
  fpdev.cmd.fpc.cache.path,
  test_cli_helpers;

var
  GTempDir: string;

{ ===== Group 1: fpc doctor - Command Basics ===== }

procedure TestDoctorCommandName;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: name is "doctor"', Cmd.Name = 'doctor');
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorAliasesNil;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorFindSubNil;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Check('doctor: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: fpc doctor - Help ===== }

procedure TestDoctorHelpFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('doctor --help returns EXIT_OK', Ret = EXIT_OK);
    Check('doctor --help shows usage', StdOut.Contains('doctor'));
  finally
    Cmd.Free;
  end;
end;

procedure TestDoctorHelpShortFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('doctor -h returns EXIT_OK', Ret = EXIT_OK);
    Check('doctor -h shows usage', StdOut.Contains('doctor'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: fpc doctor - Execution ===== }

procedure TestDoctorExecution;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    Check('doctor produces output', Length(AllOutput) > 0);
    Check('doctor returns valid exit code', Ret >= 0);
    // Doctor runs 11 checks
    Check('doctor shows check numbers', StdOut.Contains('[1/11]'));
    Check('doctor shows final check', StdOut.Contains('[11/11]'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: fpc doctor - Registration ===== }

procedure TestDoctorRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'doctor' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc doctor is registered in command registry', Found);
end;

{ ===== Group 5: fpc verify - Command Basics ===== }

procedure TestVerifyCommandName;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: name is "verify"', Cmd.Name = 'verify');
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyAliasesNil;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyFindSubNil;
var
  Cmd: TFPCVerifyCommand;
begin
  Cmd := TFPCVerifyCommand.Create;
  try
    Check('verify: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: fpc verify - Help ===== }

procedure TestVerifyHelpFlag;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('verify --help returns EXIT_OK', Ret = EXIT_OK);
    Check('verify --help shows usage', StdOut.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

procedure TestVerifyHelpShortFlag;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('verify -h returns EXIT_OK', Ret = EXIT_OK);
    Check('verify -h shows usage', StdOut.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 7: fpc verify - Missing Arguments ===== }

procedure TestVerifyMissingVersion;
var
  Cmd: TFPCVerifyCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCVerifyCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    // verify with no args exits with EXIT_ERROR (not EXIT_OK)
    Check('verify no args returns error', Ret <> EXIT_OK);
    // Usage hint on stderr
    Check('verify no args shows usage hint', StdErr.Contains('verify'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 8: fpc verify - Registration ===== }

procedure TestVerifyRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'verify' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc verify is registered in command registry', Found);
end;

{ ===== Group 9: fpc cache list - Command Basics ===== }

procedure TestCacheListCommandName;
var
  Cmd: TFPCCacheListCommand;
begin
  Cmd := TFPCCacheListCommand.Create;
  try
    Check('cache list: name is "list"', Cmd.Name = 'list');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListHelpFlag;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache list --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache list --help shows usage', StdOut.Contains('cache list'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheListExecution;
var
  Cmd: TFPCCacheListCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheListCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    Check('cache list produces output', Length(AllOutput) > 0);
    Check('cache list returns EXIT_OK', Ret = EXIT_OK);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 10: fpc cache clean - Command Basics ===== }

procedure TestCacheCleanCommandName;
var
  Cmd: TFPCCacheCleanCommand;
begin
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Check('cache clean: name is "clean"', Cmd.Name = 'clean');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanHelpFlag;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache clean --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache clean --help shows usage', StdOut.Contains('cache clean'));
    Check('cache clean --help shows --all option', StdOut.Contains('all'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanNoArgs;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache clean no args returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('cache clean no args shows error', StdErr.Contains('version') or StdErr.Contains('all'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheCleanNonExistent;
var
  Cmd: TFPCCacheCleanCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheCleanCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    Check('cache clean non-existent returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('cache clean non-existent shows error', StdErr.Contains('not cached'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc cache stats - Command Basics ===== }

procedure TestCacheStatsCommandName;
var
  Cmd: TFPCCacheStatsCommand;
begin
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Check('cache stats: name is "stats"', Cmd.Name = 'stats');
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsHelpFlag;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache stats --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache stats --help shows usage', StdOut.Contains('cache stats'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCacheStatsExecution;
var
  Cmd: TFPCCacheStatsCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCacheStatsCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache stats returns EXIT_OK', Ret = EXIT_OK);
    Check('cache stats shows statistics', StdOut.Contains('Statistics') or StdOut.Contains('Cached'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 12: fpc cache path - Command Basics ===== }

procedure TestCachePathCommandName;
var
  Cmd: TFPCCachePathCommand;
begin
  Cmd := TFPCCachePathCommand.Create;
  try
    Check('cache path: name is "path"', Cmd.Name = 'path');
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathHelpFlag;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('cache path --help returns EXIT_OK', Ret = EXIT_OK);
    Check('cache path --help shows usage', StdOut.Contains('cache path'));
  finally
    Cmd.Free;
  end;
end;

procedure TestCachePathExecution;
var
  Cmd: TFPCCachePathCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCachePathCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('cache path returns EXIT_OK', Ret = EXIT_OK);
    Check('cache path shows cache directory', StdOut.Contains('cache'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 13: fpc cache - Registration ===== }

procedure TestCacheRegistration;
var
  Children: TStringArray;
  I: Integer;
  FoundCache, FoundList, FoundClean, FoundStats, FoundPath: Boolean;
begin
  // Check 'cache' is a child of 'fpc'
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  FoundCache := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'cache' then
    begin
      FoundCache := True;
      Break;
    end;
  Check('fpc cache is registered', FoundCache);

  // Check sub-commands of 'fpc cache'
  Children := GlobalCommandRegistry.ListChildren(['fpc', 'cache']);
  FoundList := False;
  FoundClean := False;
  FoundStats := False;
  FoundPath := False;
  for I := Low(Children) to High(Children) do
  begin
    if Children[I] = 'list' then FoundList := True;
    if Children[I] = 'clean' then FoundClean := True;
    if Children[I] = 'stats' then FoundStats := True;
    if Children[I] = 'path' then FoundPath := True;
  end;
  Check('fpc cache list is registered', FoundList);
  Check('fpc cache clean is registered', FoundClean);
  Check('fpc cache stats is registered', FoundStats);
  Check('fpc cache path is registered', FoundPath);
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Diagnostic Commands CLI Tests (doctor/verify/cache) ===');
  WriteLn;

  GTempDir := GetTempDir + 'fpdev_test_fpc_diag_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempDir);

  try
    // Group 1: fpc doctor basics
    WriteLn('--- fpc doctor: Command Basics ---');
    TestDoctorCommandName;
    TestDoctorAliasesNil;
    TestDoctorFindSubNil;

    // Group 2: fpc doctor help
    WriteLn('');
    WriteLn('--- fpc doctor: Help Output ---');
    TestDoctorHelpFlag;
    TestDoctorHelpShortFlag;

    // Group 3: fpc doctor execution
    WriteLn('');
    WriteLn('--- fpc doctor: Execution ---');
    TestDoctorExecution;

    // Group 4: fpc doctor registration
    WriteLn('');
    WriteLn('--- fpc doctor: Registration ---');
    TestDoctorRegistration;

    // Group 5: fpc verify basics
    WriteLn('');
    WriteLn('--- fpc verify: Command Basics ---');
    TestVerifyCommandName;
    TestVerifyAliasesNil;
    TestVerifyFindSubNil;

    // Group 6: fpc verify help
    WriteLn('');
    WriteLn('--- fpc verify: Help Output ---');
    TestVerifyHelpFlag;
    TestVerifyHelpShortFlag;

    // Group 7: fpc verify missing args
    WriteLn('');
    WriteLn('--- fpc verify: Argument Validation ---');
    TestVerifyMissingVersion;

    // Group 8: fpc verify registration
    WriteLn('');
    WriteLn('--- fpc verify: Registration ---');
    TestVerifyRegistration;

    // Group 9: fpc cache list
    WriteLn('');
    WriteLn('--- fpc cache list ---');
    TestCacheListCommandName;
    TestCacheListHelpFlag;
    TestCacheListExecution;

    // Group 10: fpc cache clean
    WriteLn('');
    WriteLn('--- fpc cache clean ---');
    TestCacheCleanCommandName;
    TestCacheCleanHelpFlag;
    TestCacheCleanNoArgs;
    TestCacheCleanNonExistent;

    // Group 11: fpc cache stats
    WriteLn('');
    WriteLn('--- fpc cache stats ---');
    TestCacheStatsCommandName;
    TestCacheStatsHelpFlag;
    TestCacheStatsExecution;

    // Group 12: fpc cache path
    WriteLn('');
    WriteLn('--- fpc cache path ---');
    TestCachePathCommandName;
    TestCachePathHelpFlag;
    TestCachePathExecution;

    // Group 13: fpc cache registration
    WriteLn('');
    WriteLn('--- fpc cache: Registration ---');
    TestCacheRegistration;
  finally
    if DirectoryExists(GTempDir) then
    begin
      DeleteFile(GTempDir + PathDelim + 'config.json');
      RemoveDir(GTempDir);
    end;
  end;

  Halt(PrintTestSummary);
end.
