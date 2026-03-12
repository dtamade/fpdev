program test_cli_fpc_lifecycle;

{$mode objfpc}{$H+}

{
================================================================================
  test_cli_fpc_lifecycle - CLI tests for fpdev fpc update/test/update-manifest
================================================================================

  Tests the FPC lifecycle commands' CLI behavior:
  - update: source/index update with help, execution
  - test: installation testing with help, missing version
  - update-manifest: manifest cache management with help

  Uses shared test_cli_helpers unit for TStringOutput/TTestContext.

  B190: FPC lifecycle commands CLI test coverage
  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.fpc,                   // Register 'fpc' root command
  fpdev.cmd.fpc.update,
  fpdev.cmd.fpc.test,
  fpdev.cmd.fpc.update_manifest,
  fpdev.cmd.fpc.autoinstall,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

procedure WriteCachedFPCManifest(const ACacheDir: string);
var
  Manifest: TStringList;
  CachePath: string;
begin
  ForceDirectories(ACacheDir);
  CachePath := IncludeTrailingPathDelimiter(ACacheDir) + 'fpc.json';
  Manifest := TStringList.Create;
  try
    Manifest.Add('{');
    Manifest.Add('  "manifest-version": "1",');
    Manifest.Add('  "date": "2026-03-09",');
    Manifest.Add('  "channel": "stable",');
    Manifest.Add('  "pkg": {');
    Manifest.Add('    "fpc": {');
    Manifest.Add('      "version": "3.2.2",');
    Manifest.Add('      "targets": {');
    Manifest.Add('        "linux-x86_64": {');
    Manifest.Add('          "url": "https://example.com/fpc.tar.gz",');
    Manifest.Add('          "hash": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",');
    Manifest.Add('          "size": 123456789');
    Manifest.Add('        }');
    Manifest.Add('      }');
    Manifest.Add('    }');
    Manifest.Add('  }');
    Manifest.Add('}');
    Manifest.SaveToFile(CachePath);
  finally
    Manifest.Free;
  end;
end;

{ ===== Group 1: fpc update - Command Basics ===== }

procedure TestUpdateCommandName;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: name is "update"', Cmd.Name = 'update');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateAliasesNil;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateFindSubNil;
var
  Cmd: TFPCUpdateCommand;
begin
  Cmd := TFPCUpdateCommand.Create;
  try
    Check('update: FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: fpc update - Help ===== }

procedure TestUpdateHelpFlag;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update --help returns EXIT_OK', Ret = EXIT_OK);
    Check('update --help shows usage', StdOut.Contains('update'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateHelpShortFlag;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('update -h returns EXIT_OK', Ret = EXIT_OK);
    Check('update -h shows usage', StdOut.Contains('update'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: fpc update - Execution ===== }

procedure TestUpdateNoArgs;
var
  Cmd: TFPCUpdateCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // No args = update index only
    Check('update no args produces output', Length(AllOutput) > 0);
    Check('update no args returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: fpc update - Registration ===== }

procedure TestUpdateRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'update' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc update is registered in command registry', Found);
end;

{ ===== Group 5: fpc test - Command Basics ===== }

procedure TestTestCommandName;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: name is "test"', Cmd.Name = 'test');
  finally
    Cmd.Free;
  end;
end;

procedure TestTestAliasesNil;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestTestFindSubNil;
var
  Cmd: TFPCCTestCommand;
begin
  Cmd := TFPCCTestCommand.Create;
  try
    Check('test: FindSub returns nil', Cmd.FindSub('abc') = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: fpc test - Help ===== }

procedure TestTestHelpFlag;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('test --help returns EXIT_OK', Ret = EXIT_OK);
    Check('test --help shows usage', StdOut.Contains('test'));
  finally
    Cmd.Free;
  end;
end;

procedure TestTestHelpShortFlag;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('test -h returns EXIT_OK', Ret = EXIT_OK);
    Check('test -h shows usage', StdOut.Contains('test'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 7: fpc test - No Args (System FPC Fallback) ===== }

procedure TestTestMissingVersion;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // No args, no default toolchain -> should fall back to system FPC in PATH
    Check('test no args returns EXIT_OK', Ret = EXIT_OK);
    Check('test no args uses system fallback', Pos('Testing system FPC', AllOutput) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 8: fpc test - Execution with version ===== }

procedure TestTestWithVersion;
var
  Cmd: TFPCCTestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCCTestCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // Non-existent version -> will fail but should produce output
    Check('test with version produces output', Length(AllOutput) > 0);
    Check('test with version returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 9: fpc test - Registration ===== }

procedure TestTestRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'test' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc test is registered in command registry', Found);
end;

{ ===== Group 10: fpc update-manifest - Command Basics ===== }

procedure TestUpdateManifestCommandName;
var
  Cmd: TFPCUpdateManifestCommand;
begin
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Check('update-manifest: name is "update-manifest"', Cmd.Name = 'update-manifest');
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestAliasesNil;
var
  Cmd: TFPCUpdateManifestCommand;
begin
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Check('update-manifest: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 11: fpc update-manifest - Help ===== }

procedure TestUpdateManifestHelpFlag;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('update-manifest --help returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest --help shows usage', StdOut.Contains('update-manifest'));
    Check('update-manifest --help shows --force option', StdOut.Contains('force'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestHelpShortFlag;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Check('update-manifest -h returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest -h shows usage', StdOut.Contains('update-manifest'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestUnexpectedArg;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['extra'], Ctx);
    Check('update-manifest unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestUnknownOption;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('update-manifest unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestForceWithExtraArg;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  try
    Ret := Cmd.Execute(['--force', 'extra'], Ctx);
    Check('update-manifest --force with extra arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 12: fpc update-manifest - Registration ===== }

procedure TestUpdateManifestUsesContextScopedCache;
var
  Cmd: TFPCUpdateManifestCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ExpectedCacheDir: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCUpdateManifestCommand.Create;
  ExpectedCacheDir := IncludeTrailingPathDelimiter(GTempDir) + 'cache' + PathDelim + 'manifests';
  WriteCachedFPCManifest(ExpectedCacheDir);
  try
    Ret := Cmd.Execute([], Ctx);
    Check('update-manifest cached run returns EXIT_OK', Ret = EXIT_OK);
    Check('update-manifest uses context-scoped cache dir',
      StdOut.Contains('  Cache: ' + ExpectedCacheDir));
    Check('update-manifest cached run lists available version',
      StdOut.Contains('3.2.2'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUpdateManifestRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'update-manifest' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc update-manifest is registered in command registry', Found);
end;

{ ===== Group 13: fpc auto-install - Error routing ===== }

procedure TestAutoInstallMissingConfigWritesStderr;
var
  Cmd: TFPCAutoInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  OldDir: string;
  TempNoConfigDir: string;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCAutoInstallCommand.Create;
  OldDir := GetCurrentDir;
  TempNoConfigDir := GTempDir + PathDelim + 'autoinstall_no_config';
  ForceDirectories(TempNoConfigDir);
  try
    SetCurrentDir(TempNoConfigDir);
    Ret := Cmd.Execute([], Ctx);
    Check('auto-install missing config returns EXIT_ERROR', Ret = EXIT_ERROR);
    Check('auto-install missing config error goes to stderr',
      StdErr.Contains('No .fpdev.toml found'));
    Check('auto-install missing config does not write error to stdout',
      not StdOut.Contains('No .fpdev.toml found'));
  finally
    SetCurrentDir(OldDir);
    Cmd.Free;
  end;
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Lifecycle Commands CLI Tests (update/test/update-manifest/auto-install) ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_fpc_life');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    // Group 1: fpc update basics
    WriteLn('--- fpc update: Command Basics ---');
    TestUpdateCommandName;
    TestUpdateAliasesNil;
    TestUpdateFindSubNil;

    // Group 2: fpc update help
    WriteLn('');
    WriteLn('--- fpc update: Help Output ---');
    TestUpdateHelpFlag;
    TestUpdateHelpShortFlag;

    // Group 3: fpc update execution
    WriteLn('');
    WriteLn('--- fpc update: Execution ---');
    TestUpdateNoArgs;

    // Group 4: fpc update registration
    WriteLn('');
    WriteLn('--- fpc update: Registration ---');
    TestUpdateRegistration;

    // Group 5: fpc test basics
    WriteLn('');
    WriteLn('--- fpc test: Command Basics ---');
    TestTestCommandName;
    TestTestAliasesNil;
    TestTestFindSubNil;

    // Group 6: fpc test help
    WriteLn('');
    WriteLn('--- fpc test: Help Output ---');
    TestTestHelpFlag;
    TestTestHelpShortFlag;

    // Group 7: fpc test missing version
    WriteLn('');
    WriteLn('--- fpc test: Argument Validation ---');
    TestTestMissingVersion;

    // Group 8: fpc test with version
    WriteLn('');
    WriteLn('--- fpc test: Execution ---');
    TestTestWithVersion;

    // Group 9: fpc test registration
    WriteLn('');
    WriteLn('--- fpc test: Registration ---');
    TestTestRegistration;

    // Group 10: fpc update-manifest basics
    WriteLn('');
    WriteLn('--- fpc update-manifest: Command Basics ---');
    TestUpdateManifestCommandName;
    TestUpdateManifestAliasesNil;

    // Group 11: fpc update-manifest help
    WriteLn('');
    WriteLn('--- fpc update-manifest: Help Output ---');
    TestUpdateManifestHelpFlag;
    TestUpdateManifestHelpShortFlag;
    TestUpdateManifestUnexpectedArg;
    TestUpdateManifestUnknownOption;
    TestUpdateManifestForceWithExtraArg;

    // Group 12: fpc update-manifest registration
    WriteLn('');
    WriteLn('--- fpc update-manifest: Registration ---');
    TestUpdateManifestRegistration;
    TestUpdateManifestUsesContextScopedCache;

    // Group 13: fpc auto-install error routing
    WriteLn('');
    WriteLn('--- fpc auto-install: Error Routing ---');
    TestAutoInstallMissingConfigWritesStderr;
  finally
    CleanupTempDir(GTempDir);
  end;

  Halt(PrintTestSummary);
end.
