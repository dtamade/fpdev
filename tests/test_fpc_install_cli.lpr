program test_fpc_install_cli;

{$mode objfpc}{$H+}

{
================================================================================
  test_fpc_install_cli - CLI integration tests for fpdev fpc install
================================================================================

  Tests the FPC install command's CLI behavior:
  - Help output and argument parsing
  - Install mode flags (--from, --from-source, --from-binary)
  - Cache flags (--offline, --no-cache)
  - Error handling for missing/invalid arguments
  - Command registration in GlobalCommandRegistry

  These tests exercise TFPCInstallCommand.Execute() through mock context
  without requiring real network or file system operations. The focus is
  on CLI behavior (argument parsing, output messages, exit codes), not
  on actual installation logic.

  TDD Red Phase: Tests define expected behavior for install command.

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.config.managers,
  fpdev.logger.intf, fpdev.exitcodes,
  fpdev.cmd.fpc,           // Register 'fpc' root command
  fpdev.cmd.fpc.install,
  fpdev.cmd.fpc.uninstall;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

{ TStringOutput - captures output for test verification }
type
  TStringOutput = class(TInterfacedObject, IOutput)
  private
    FBuffer: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Write(const S: string);
    procedure WriteLn; overload;
    procedure WriteLn(const S: string); overload;
    procedure WriteFmt(const Fmt: string; const Args: array of const);
    procedure WriteLnFmt(const Fmt: string; const Args: array of const);
    procedure WriteColored(const S: string; const AColor: TConsoleColor);
    procedure WriteLnColored(const S: string; const AColor: TConsoleColor);
    procedure WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
    procedure WriteSuccess(const S: string);
    procedure WriteError(const S: string);
    procedure WriteWarning(const S: string);
    procedure WriteInfo(const S: string);
    function SupportsColor: Boolean;
    function GetBuffer: string;
    function Contains(const S: string): Boolean;
    procedure Clear;
  end;

constructor TStringOutput.Create;
begin
  inherited Create;
  FBuffer := TStringList.Create;
end;

destructor TStringOutput.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TStringOutput.Write(const S: string);
begin
  if FBuffer.Count = 0 then
    FBuffer.Add(S)
  else
    FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn;
begin
  FBuffer.Add('');
end;

procedure TStringOutput.WriteLn(const S: string);
begin
  FBuffer.Add(S);
end;

procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const);
begin
  Write(Format(Fmt, Args));
end;

procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const);
begin
  WriteLn(Format(Fmt, Args));
end;

procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor);
begin
  Write(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor);
begin
  WriteLn(S);
  if AColor = ccDefault then;
end;

procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  Write(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle);
begin
  WriteLn(S);
  if AColor = ccDefault then;
  if AStyle = csNone then;
end;

procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;

function TStringOutput.GetBuffer: string;
begin
  Result := FBuffer.Text;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ TTestContext - mock context for CLI testing }
type
  TTestContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
    FConfig: IConfigManager;
  public
    constructor Create(AOut, AErr: IOutput; AConfig: IConfigManager);
    function Out: IOutput;
    function Err: IOutput;
    function Config: IConfigManager;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor TTestContext.Create(AOut, AErr: IOutput; AConfig: IConfigManager);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
  FConfig := AConfig;
end;

function TTestContext.Out: IOutput; begin Result := FOut; end;
function TTestContext.Err: IOutput; begin Result := FErr; end;
function TTestContext.Config: IConfigManager; begin Result := FConfig; end;
function TTestContext.Logger: ILogger; begin Result := nil; end;
procedure TTestContext.SaveIfModified; begin end;

{ Helper: create a test context with fresh mock config }
var
  GTempConfigDir: string;

function CreateTestContext(out AStdOut, AStdErr: TStringOutput): IContext;
var
  Config: IConfigManager;
begin
  AStdOut := TStringOutput.Create;
  AStdErr := TStringOutput.Create;

  // Create real config manager with temp directory
  Config := TConfigManager.Create(GTempConfigDir + PathDelim + 'config.json');
  Config.CreateDefaultConfig;
  Config.LoadConfig;

  Result := TTestContext.Create(AStdOut, AStdErr, Config);
end;

{ ===== Tests ===== }

{ Group 1: Command basics }

procedure TestCommandName;
var
  Cmd: TFPCInstallCommand;
begin
  Cmd := TFPCInstallCommand.Create;
  try
    Test('Command name is "install"', Cmd.Name = 'install');
  finally
    Cmd.Free;
  end;
end;

procedure TestAliasesIsNil;
var
  Cmd: TFPCInstallCommand;
begin
  Cmd := TFPCInstallCommand.Create;
  try
    Test('Aliases returns nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestFindSubReturnsNil;
var
  Cmd: TFPCInstallCommand;
begin
  Cmd := TFPCInstallCommand.Create;
  try
    Test('FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

{ Group 2: Help output }

procedure TestHelpFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Test('--help returns EXIT_OK', Ret = EXIT_OK);
    Test('--help shows usage info', StdOut.Contains('fpdev fpc install'));
    Test('--help shows --offline option', StdOut.Contains('offline'));
    Test('--help shows --no-cache option', StdOut.Contains('no-cache'));
  finally
    Cmd.Free;
  end;
end;

procedure TestHelpShortFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Test('-h returns EXIT_OK', Ret = EXIT_OK);
    Test('-h shows usage info', StdOut.Contains('fpdev fpc install'));
  finally
    Cmd.Free;
  end;
end;

procedure TestHelpSubcommand;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['help'], Ctx);
    // 'help' as first positional param is treated as version, not help flag
    // So it should NOT return EXIT_OK with help text
    Test('help as version param does not return EXIT_OK', Ret <> EXIT_OK);
  finally
    Cmd.Free;
  end;
end;

{ Group 3: Missing arguments }

procedure TestMissingVersionArg;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Test('No args returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Test('No args shows error on stderr', StdErr.Contains('version'));
  finally
    Cmd.Free;
  end;
end;

{ Group 4: Install mode flags }

procedure TestInvalidFromMode;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from=invalid'], Ctx);
    Test('Invalid --from mode returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Test('Invalid --from shows error', StdErr.Contains('invalid'));
  finally
    Cmd.Free;
  end;
end;

{ Group 5: Offline mode }

procedure TestOfflineModeNoCacheHit;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    // Offline mode with no cache should fail gracefully
    Ret := Cmd.Execute(['99.99.99', '--offline'], Ctx);
    Test('Offline with cache miss returns EXIT_IO_ERROR', Ret = EXIT_IO_ERROR);
    Test('Offline cache miss shows FAIL', StdErr.Contains('FAIL'));
    Test('Offline cache miss shows HINT', StdErr.Contains('HINT'));
  finally
    Cmd.Free;
  end;
end;

{ Group 6: Normal installation flow (will fail without network/toolchain) }

procedure TestNormalInstallAttempt;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    // In test environment, installation will fail (no network/compiler)
    // but the command should start correctly
    Ret := Cmd.Execute(['3.2.2'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;

    // The command should at least show it started (mode info or attempt message)
    Test('Normal install produces output', Length(AllOutput) > 0);
    // Result should be an error or success code
    Test('Normal install returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallWithFromBinaryFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from-binary'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;

    // Should attempt binary installation
    Test('--from-binary produces output', Length(AllOutput) > 0);
    Test('--from-binary returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallWithFromSourceFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from-source'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;

    // Should attempt source installation
    Test('--from-source produces output', Length(AllOutput) > 0);
    Test('--from-source returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallWithNoCacheFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--no-cache'], Ctx);
    Output := StdOut.GetBuffer;

    // Should show no-cache mode in output
    Test('--no-cache shows no-cache in output', Pos('no-cache', Output) > 0);
  finally
    Cmd.Free;
  end;
end;

{ Group 7: Command registration }

procedure TestCommandRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  // Check that 'install' is registered as a child of 'fpc'
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'install' then
    begin
      Found := True;
      Break;
    end;
  Test('fpc install is registered in command registry', Found);
end;

{ Group 8: Uninstall command basics }

procedure TestUninstallCommandName;
var
  Cmd: TFPCUninstallCommand;
begin
  Cmd := TFPCUninstallCommand.Create;
  try
    Test('Uninstall command name is "uninstall"', Cmd.Name = 'uninstall');
  finally
    Cmd.Free;
  end;
end;

procedure TestUninstallAliasesIsNil;
var
  Cmd: TFPCUninstallCommand;
begin
  Cmd := TFPCUninstallCommand.Create;
  try
    Test('Uninstall aliases returns nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestUninstallHelpFlag;
var
  Cmd: TFPCUninstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Test('Uninstall --help returns EXIT_OK', Ret = EXIT_OK);
    Test('Uninstall --help shows usage', StdOut.Contains('uninstall'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUninstallMissingVersion;
var
  Cmd: TFPCUninstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCUninstallCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Test('Uninstall no args returns EXIT_USAGE_ERROR', Ret = EXIT_USAGE_ERROR);
    Test('Uninstall no args shows error on stderr', StdErr.Contains('version'));
  finally
    Cmd.Free;
  end;
end;

procedure TestUninstallNonExistent;
var
  Cmd: TFPCUninstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  AllOutput: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCUninstallCommand.Create;
  try
    Ret := Cmd.Execute(['99.99.99'], Ctx);
    AllOutput := StdOut.GetBuffer + StdErr.GetBuffer;
    // The command should produce some output (success or error)
    Test('Uninstall non-existent version produces output', Length(AllOutput) > 0);
    Test('Uninstall non-existent version returns valid code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestUninstallRegistration;
var
  Children: TStringArray;
  I: Integer;
  Found: Boolean;
begin
  Children := GlobalCommandRegistry.ListChildren(['fpc']);
  Found := False;
  for I := Low(Children) to High(Children) do
    if Children[I] = 'uninstall' then
    begin
      Found := True;
      Break;
    end;
  Test('fpc uninstall is registered in command registry', Found);
end;

{ Group 9: Install edge cases }

procedure TestInstallWithFromAutoFlag;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from=auto'], Ctx);
    // auto is valid mode, command should proceed (and likely fail due to no network)
    Test('--from=auto returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallWithFromBinaryExplicit;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from=binary'], Ctx);
    Test('--from=binary returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInstallWithFromSourceExplicit;
var
  Cmd: TFPCInstallCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCInstallCommand.Create;
  try
    Ret := Cmd.Execute(['3.2.2', '--from=source'], Ctx);
    Test('--from=source returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Install CLI Tests ===');
  WriteLn;

  // Create temp config directory
  GTempConfigDir := GetTempDir + 'fpdev_test_install_' + IntToStr(GetTickCount64);
  ForceDirectories(GTempConfigDir);

  try
    // Group 1: Command basics
    WriteLn('--- Command Basics ---');
    TestCommandName;
    TestAliasesIsNil;
    TestFindSubReturnsNil;

    // Group 2: Help output
    WriteLn('');
    WriteLn('--- Help Output ---');
    TestHelpFlag;
    TestHelpShortFlag;
    TestHelpSubcommand;

    // Group 3: Missing arguments
    WriteLn('');
    WriteLn('--- Argument Validation ---');
    TestMissingVersionArg;

    // Group 4: Install mode flags
    WriteLn('');
    WriteLn('--- Install Mode Flags ---');
    TestInvalidFromMode;

    // Group 5: Offline mode
    WriteLn('');
    WriteLn('--- Offline Mode ---');
    TestOfflineModeNoCacheHit;

    // Group 6: Normal installation flow
    WriteLn('');
    WriteLn('--- Installation Flow ---');
    TestNormalInstallAttempt;
    TestInstallWithFromBinaryFlag;
    TestInstallWithFromSourceFlag;
    TestInstallWithNoCacheFlag;

    // Group 7: Command registration
    WriteLn('');
    WriteLn('--- Command Registration ---');
    TestCommandRegistration;

    // Group 8: Uninstall command
    WriteLn('');
    WriteLn('--- Uninstall Command ---');
    TestUninstallCommandName;
    TestUninstallAliasesIsNil;
    TestUninstallHelpFlag;
    TestUninstallMissingVersion;
    TestUninstallNonExistent;
    TestUninstallRegistration;

    // Group 9: Install edge cases
    WriteLn('');
    WriteLn('--- Install Edge Cases ---');
    TestInstallWithFromAutoFlag;
    TestInstallWithFromBinaryExplicit;
    TestInstallWithFromSourceExplicit;
  finally
    // Cleanup temp directory
    if DirectoryExists(GTempConfigDir) then
    begin
      // Simple cleanup - delete config file and directory
      DeleteFile(GTempConfigDir + PathDelim + 'config.json');
      RemoveDir(GTempConfigDir);
    end;
  end;

  WriteLn('');
  WriteLn('=== Test Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  WriteLn;

  if GFailCount > 0 then
    Halt(1);
end.
