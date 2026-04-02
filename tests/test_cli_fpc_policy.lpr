program test_cli_fpc_policy;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry,
  fpdev.exitcodes,
  fpdev.cmd.fpc,
  fpdev.cmd.fpc.policy.root,
  fpdev.cmd.fpc.policy.check,
  test_cli_helpers, test_temp_paths;

var
  GTempDir: string;

procedure TestPolicyCheckCommandName;
var
  Cmd: TFPCPolicyCheckCommand;
begin
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Check('policy check: name is "check"', Cmd.Name = 'check');
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckAliasesNil;
var
  Cmd: TFPCPolicyCheckCommand;
begin
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Check('policy check: aliases is nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckFindSubNil;
var
  Cmd: TFPCPolicyCheckCommand;
begin
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Check('policy check: FindSub returns nil', Cmd.FindSub('abc') = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckHelpFlag;
var
  Cmd: TFPCPolicyCheckCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Check('policy check --help returns EXIT_OK', Ret = EXIT_OK);
    Check('policy check --help shows usage', StdOut.Contains('fpdev fpc policy check'));
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckNoArgsUsesMainSourceVersion;
var
  Cmd: TFPCPolicyCheckCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Check('policy check no args returns valid exit code',
      (Ret = EXIT_OK) or (Ret = EXIT_USAGE_ERROR));
    Check('policy check no args uses main source version', StdOut.Contains('src=main'));
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckUnexpectedArgReturnsUsageError;
var
  Cmd: TFPCPolicyCheckCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Ret := Cmd.Execute(['main', 'extra'], Ctx);
    Check('policy check unexpected arg returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('policy check unexpected arg shows usage', StdErr.Contains('fpdev fpc policy check'));
    Check('policy check unexpected arg keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckUnknownOptionReturnsUsageError;
var
  Cmd: TFPCPolicyCheckCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(GTempDir, StdOut, StdErr);
  Cmd := TFPCPolicyCheckCommand.Create;
  try
    Ret := Cmd.Execute(['--unknown'], Ctx);
    Check('policy check unknown option returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Check('policy check unknown option shows usage', StdErr.Contains('fpdev fpc policy check'));
    Check('policy check unknown option keeps stdout empty', Trim(StdOut.GetBuffer) = '');
  finally
    Cmd.Free;
  end;
end;

procedure TestPolicyCheckRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc', 'policy']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'check' then
    begin
      Found := True;
      Break;
    end;
  Check('fpc policy check is registered in command registry', Found);
end;

begin
  WriteLn('=== FPC Policy CLI Tests ===');
  WriteLn;

  GTempDir := CreateUniqueTempDir('fpdev_test_fpc_policy');
  Check('temp dir uses system temp root', PathUsesSystemTempRoot(GTempDir));

  try
    WriteLn('--- fpc policy check: Command Basics ---');
    TestPolicyCheckCommandName;
    TestPolicyCheckAliasesNil;
    TestPolicyCheckFindSubNil;

    WriteLn('');
    WriteLn('--- fpc policy check: Help ---');
    TestPolicyCheckHelpFlag;

    WriteLn('');
    WriteLn('--- fpc policy check: Execution ---');
    TestPolicyCheckNoArgsUsesMainSourceVersion;
    TestPolicyCheckUnexpectedArgReturnsUsageError;
    TestPolicyCheckUnknownOptionReturnsUsageError;

    WriteLn('');
    WriteLn('--- fpc policy check: Registration ---');
    TestPolicyCheckRegistration;
  finally
    CleanupTempDir(GTempDir);
  end;

  ExitCode := PrintTestSummary;
end.
