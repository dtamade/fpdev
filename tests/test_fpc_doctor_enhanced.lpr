program test_fpc_doctor_enhanced;

{$mode objfpc}{$H+}

{
================================================================================
  test_fpc_doctor_enhanced - Enhanced tests for fpdev fpc doctor
================================================================================

  Tests the Doctor command through mock context:
  - Help flag output
  - Basic checks output (7 existing checks)
  - fpc.cfg validation check (new)
  - Library path completeness check (new)
  - Cache health check (new)
  - Disk space check (new)
  - Issue counting and summary

  B181: TDD Red Phase for Doctor enhancement

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, fpdev.utils.fs, test_temp_paths,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.config.managers,
  fpdev.logger.intf, fpdev.exitcodes,
  fpdev.cmd.fpc,
  fpdev.cmd.fpc.doctor;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

function BuildTempConfigDir: string;
begin
  Result := CreateUniqueTempDir('fpdev_test_doctor');
end;

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

{ TStringOutput }
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
  if FBuffer.Count = 0 then FBuffer.Add(S)
  else FBuffer[FBuffer.Count - 1] := FBuffer[FBuffer.Count - 1] + S;
end;

procedure TStringOutput.WriteLn; begin FBuffer.Add(''); end;
procedure TStringOutput.WriteLn(const S: string); begin FBuffer.Add(S); end;
procedure TStringOutput.WriteFmt(const Fmt: string; const Args: array of const); begin Write(Format(Fmt, Args)); end;
procedure TStringOutput.WriteLnFmt(const Fmt: string; const Args: array of const); begin WriteLn(Format(Fmt, Args)); end;
procedure TStringOutput.WriteColored(const S: string; const AColor: TConsoleColor); begin Write(S); if AColor = ccDefault then; end;
procedure TStringOutput.WriteLnColored(const S: string; const AColor: TConsoleColor); begin WriteLn(S); if AColor = ccDefault then; end;
procedure TStringOutput.WriteStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle); begin Write(S); if AColor = ccDefault then; if AStyle = csNone then; end;
procedure TStringOutput.WriteLnStyled(const S: string; const AColor: TConsoleColor; const AStyle: TConsoleStyle); begin WriteLn(S); if AColor = ccDefault then; if AStyle = csNone then; end;
procedure TStringOutput.WriteSuccess(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteError(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteWarning(const S: string); begin WriteLn(S); end;
procedure TStringOutput.WriteInfo(const S: string); begin WriteLn(S); end;
function TStringOutput.SupportsColor: Boolean; begin Result := False; end;
function TStringOutput.GetBuffer: string; begin Result := FBuffer.Text; end;
function TStringOutput.Contains(const S: string): Boolean; begin Result := Pos(S, FBuffer.Text) > 0; end;
procedure TStringOutput.Clear; begin FBuffer.Clear; end;

{ TTestContext }
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

{ Helper }
var
  GTempConfigDir: string;

function CreateTestContext(out AStdOut, AStdErr: TStringOutput): IContext;
var
  Config: IConfigManager;
begin
  AStdOut := TStringOutput.Create;
  AStdErr := TStringOutput.Create;
  Config := TConfigManager.Create(GTempConfigDir + PathDelim + 'config.json');
  Config.CreateDefaultConfig;
  Config.LoadConfig;
  Result := TTestContext.Create(AStdOut, AStdErr, Config);
end;

{ ===== Group 1: Command basics ===== }

procedure TestCommandName;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Test('Doctor command name is "doctor"', Cmd.Name = 'doctor');
  finally
    Cmd.Free;
  end;
end;

procedure TestAliasesIsNil;
var
  Cmd: TFPCDoctorCommand;
begin
  Cmd := TFPCDoctorCommand.Create;
  try
    Test('Doctor aliases returns nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 2: Help output ===== }

procedure TestHelpFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['--help'], Ctx);
    Test('--help returns EXIT_OK', Ret = EXIT_OK);
    Test('--help shows usage info', StdOut.Contains('doctor'));
  finally
    Cmd.Free;
  end;
end;

procedure TestHelpShortFlag;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute(['-h'], Ctx);
    Test('-h returns EXIT_OK', Ret = EXIT_OK);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 3: Execute output ===== }

procedure TestExecuteProducesOutput;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    Test('Execute produces output', Length(StdOut.GetBuffer) > 0);
    Test('Execute returns valid exit code', Ret >= 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteShowsHeader;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute shows Doctor header', StdOut.Contains('Doctor'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksWritePermission;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute checks write permissions', StdOut.Contains('write') or StdOut.Contains('Write') or StdOut.Contains('1/'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksGit;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute checks git', StdOut.Contains('git'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksMake;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute checks make', StdOut.Contains('make'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksSystemFPC;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute checks system FPC', StdOut.Contains('FPC') or StdOut.Contains('fpc'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksToolchains;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute checks toolchains', StdOut.Contains('toolchain'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteShowsSummary;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Test('Execute shows summary section',
      StdOut.Contains('===') or StdOut.Contains('check') or StdOut.Contains('passed'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 4: New checks (B181-B182 TDD) ===== }

procedure TestExecuteChecksFpcCfg;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    // New check: fpc.cfg validation
    Test('Execute checks fpc.cfg', StdOut.Contains('fpc.cfg'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksLibPaths;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    // New check: library path completeness
    Test('Execute checks library paths', StdOut.Contains('lib') or StdOut.Contains('library'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksCacheHealth;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    // New check: cache health
    Test('Execute checks cache', StdOut.Contains('cache') or StdOut.Contains('Cache'));
  finally
    Cmd.Free;
  end;
end;

procedure TestExecuteChecksDiskSpace;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    // New check: disk space
    Test('Execute checks disk space', StdOut.Contains('disk') or StdOut.Contains('Disk') or StdOut.Contains('space'));
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 5: Check count ===== }

procedure TestExecuteShowsCheckCount;
var
  Cmd: TFPCDoctorCommand;
  StdOut, StdErr: TStringOutput;
  Ctx: IContext;
  Output: string;
begin
  Ctx := CreateTestContext(StdOut, StdErr);
  Cmd := TFPCDoctorCommand.Create;
  try
    Cmd.Execute([], Ctx);
    Output := StdOut.GetBuffer;
    // After enhancement, should have 11 checks (up from 7)
    Test('Execute has at least 8 check steps',
      Pos('[8/', Output) > 0);
    Test('Execute has 11 check steps for full doctor',
      Pos('[11/', Output) > 0);
  finally
    Cmd.Free;
  end;
end;

{ ===== Group 6: Command registration ===== }

procedure TestCommandRegistration;
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
  Test('fpc doctor is registered in command registry', Found);
end;

{ ===== Main ===== }
begin
  WriteLn('=== FPC Doctor Enhanced Tests ===');
  WriteLn;

  GTempConfigDir := BuildTempConfigDir;

  try
    Test('Temp config dir uses system temp root',
      PathUsesSystemTempRoot(GTempConfigDir));

    // Group 1: Command basics
    WriteLn('--- Command Basics ---');
    TestCommandName;
    TestAliasesIsNil;

    // Group 2: Help
    WriteLn('');
    WriteLn('--- Help Output ---');
    TestHelpFlag;
    TestHelpShortFlag;

    // Group 3: Execute output
    WriteLn('');
    WriteLn('--- Execute Output ---');
    TestExecuteProducesOutput;
    TestExecuteShowsHeader;
    TestExecuteChecksWritePermission;
    TestExecuteChecksGit;
    TestExecuteChecksMake;
    TestExecuteChecksSystemFPC;
    TestExecuteChecksToolchains;
    TestExecuteShowsSummary;

    // Group 4: New checks (TDD Red Phase)
    WriteLn('');
    WriteLn('--- New Checks (B181 TDD) ---');
    TestExecuteChecksFpcCfg;
    TestExecuteChecksLibPaths;
    TestExecuteChecksCacheHealth;
    TestExecuteChecksDiskSpace;

    // Group 5: Check count
    WriteLn('');
    WriteLn('--- Check Count ---');
    TestExecuteShowsCheckCount;

    // Group 6: Registration
    WriteLn('');
    WriteLn('--- Command Registration ---');
    TestCommandRegistration;
  finally
    CleanupTempDir(GTempConfigDir);
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
