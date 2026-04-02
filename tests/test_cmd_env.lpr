program test_cmd_env;

{$mode objfpc}{$H+}

{
================================================================================
  test_cmd_env - Tests for fpdev.cmd.env
================================================================================

  Tests the environment information command:
  - Command name and aliases
  - Help output
  - Overview subcommand
  - Vars subcommand
  - Path subcommand
  - Export subcommand
  - GlobalCommandRegistry registration

  Author: fafafaStudio
================================================================================
}

uses
  SysUtils, Classes, test_config_isolation, test_temp_paths,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.env, fpdev.cmd.env.vars, fpdev.cmd.env.path, fpdev.cmd.env.export,
  fpdev.cmd.env.hook,
  fpdev.utils;

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

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
end;

{ Test output capture }
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

procedure TStringOutput.WriteSuccess(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteError(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteWarning(const S: string);
begin
  WriteLn(S);
end;

procedure TStringOutput.WriteInfo(const S: string);
begin
  WriteLn(S);
end;

function TStringOutput.SupportsColor: Boolean;
begin
  Result := False;
end;

function TStringOutput.GetBuffer: string;
begin
  Result := FBuffer.Text;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ Test context }
type
  TTestContext = class(TInterfacedObject, IContext)
  private
    FOut: IOutput;
    FErr: IOutput;
  public
    constructor Create(AOut, AErr: IOutput);
    function Out: IOutput;
    function Err: IOutput;
    function Config: IConfigManager;
    function Logger: ILogger;
    procedure SaveIfModified;
  end;

constructor TTestContext.Create(AOut, AErr: IOutput);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
end;

function TTestContext.Out: IOutput;
begin
  Result := FOut;
end;

function TTestContext.Err: IOutput;
begin
  Result := FErr;
end;

function TTestContext.Config: IConfigManager;
begin
  Result := nil;
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TTestContext.SaveIfModified;
begin
end;

{ Tests }

procedure TestCommandName;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('Command name is "env"', Cmd.Name = 'env');
end;

procedure TestAliasesIsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('Aliases returns nil', Cmd.Aliases = nil);
end;

procedure TestFindSubReturnsNil;
var
  Cmd: ICommand;
begin
  Cmd := CreateEnvCommand;
  Test('FindSub returns nil', Cmd.FindSub('test') = nil);
end;

procedure TestHelpOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['help'], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Help returns exit code 0', Ret = 0);
  Test('Help contains Usage', Pos('Usage:', Output) > 0);
  Test('Help contains vars', Pos('vars', Output) > 0);
  Test('Help contains path', Pos('path', Output) > 0);
  Test('Help contains export', Pos('export', Output) > 0);
  Test('Help contains Examples', Pos('Examples:', Output) > 0);
end;

procedure TestOverviewOutput;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute([], Ctx);
  Output := OutBuf.GetBuffer;

  Test('Overview returns exit code 0', Ret = 0);
  Test('Overview shows Environment Overview', Pos('Environment Overview', Output) > 0);
  Test('Overview shows Platform', Pos('Platform:', Output) > 0);
  Test('Overview shows FPDev Paths', Pos('FPDev Paths:', Output) > 0);
  Test('Overview shows Data Root', Pos('Data Root:', Output) > 0);
  Test('Overview shows Key Environment Variables', Pos('Key Environment Variables', Output) > 0);
end;

procedure TestOverviewUsesSameProcessEnvOverride;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  SavedFPCDir: string;
  ProbeFPCDir: string;
begin
  SavedFPCDir := get_env('FPCDIR');
  ProbeFPCDir := '/tmp/fpdev-env-overview-probe';
  try
    Test('set FPCDIR for overview',
      set_env('FPCDIR', ProbeFPCDir));

    OutBuf := TStringOutput.Create;
    Ctx := TTestContext.Create(OutBuf, OutBuf);
    Cmd := CreateEnvCommand;

    Ret := Cmd.Execute([], Ctx);
    Output := OutBuf.GetBuffer;

    Test('Overview with same-process env override returns exit code 0', Ret = 0);
    Test('Overview reflects same-process FPCDIR override',
      Pos('FPCDIR:       ' + ProbeFPCDir, Output) > 0);
  finally
    RestoreEnv('FPCDIR', SavedFPCDir);
  end;
end;

procedure TestVarsOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 3);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'vars';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Vars returns exit code 0', Ret = 0);
  Test('Vars shows FPC/Lazarus Environment Variables', Pos('FPC/Lazarus Environment Variables', Output) > 0);
  Test('Vars shows FPC Variables', Pos('FPC Variables:', Output) > 0);
  Test('Vars shows FPCDIR', Pos('FPCDIR:', Output) > 0);
  Test('Vars shows Lazarus Variables', Pos('Lazarus Variables:', Output) > 0);
  Test('Vars shows Cross-Compilation Variables', Pos('Cross-Compilation Variables:', Output) > 0);
end;

procedure TestVarsUseSameProcessEnvOverride;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  SavedFPCOpt: string;
  ProbeFPCOpt: string;
begin
  SavedFPCOpt := get_env('FPCOPT');
  ProbeFPCOpt := '-Fu/tmp/fpdev-env-vars-probe';
  try
    Test('set FPCOPT for vars',
      set_env('FPCOPT', ProbeFPCOpt));

    OutBuf := TStringOutput.Create;
    Ctx := TTestContext.Create(OutBuf, OutBuf);
    Cmd := CreateEnvVarsCommand;

    Ret := Cmd.Execute([], Ctx);
    Output := OutBuf.GetBuffer;

    Test('Vars with same-process env override returns exit code 0', Ret = 0);
    Test('Vars reflects same-process FPCOPT override',
      Pos('FPCOPT:       ' + ProbeFPCOpt, Output) > 0);
  finally
    RestoreEnv('FPCOPT', SavedFPCOpt);
  end;
end;

procedure TestPathOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 3);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'path';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Path returns exit code 0', Ret = 0);
  Test('Path shows PATH Configuration', Pos('PATH Configuration', Output) > 0);
  Test('Path shows Total entries', Pos('Total entries:', Output) > 0);
end;

procedure TestPathUsesSameProcessEnvOverride;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  TempDir: string;
  FirstDir: string;
  SecondDir: string;
  SavedPath: string;
  ProbePath: string;
begin
  SavedPath := get_env('PATH');
  TempDir := CreateUniqueTempDir('test_cmd_env_path');
  FirstDir := TempDir + PathDelim + 'one';
  SecondDir := TempDir + PathDelim + 'two';
  ForceDirectories(FirstDir);
  ForceDirectories(SecondDir);
  ProbePath := FirstDir + PathSeparator + SecondDir;
  try
    Test('set PATH for path command',
      set_env('PATH', ProbePath));

    OutBuf := TStringOutput.Create;
    Ctx := TTestContext.Create(OutBuf, OutBuf);
    Cmd := CreateEnvPathCommand;

    Ret := Cmd.Execute([], Ctx);
    Output := OutBuf.GetBuffer;

    Test('Path with same-process env override returns exit code 0', Ret = 0);
    Test('Path reflects overridden entry count',
      Pos('Total entries: 2', Output) > 0);
    Test('Path reflects first overridden entry',
      Pos(FirstDir, Output) > 0);
    Test('Path reflects second overridden entry',
      Pos(SecondDir, Output) > 0);
  finally
    RestoreEnv('PATH', SavedPath);
    CleanupTempDir(TempDir);
  end;
end;

procedure TestExportBashOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 5);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'export';
  Args[3] := '--shell';
  Args[4] := 'bash';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export bash returns exit code 0', Ret = 0);
  Test('Export bash shows header', Pos('FPDev Environment Export', Output) > 0);
  Test('Export bash shows export', Pos('export FPDEV_ROOT=', Output) > 0);
  Test('Export bash shows FPDEV_TOOLCHAINS', Pos('FPDEV_TOOLCHAINS', Output) > 0);
end;

procedure TestExportCmdOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 5);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'export';
  Args[3] := '--shell';
  Args[4] := 'cmd';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export cmd returns exit code 0', Ret = 0);
  Test('Export cmd shows set', Pos('set FPDEV_ROOT=', Output) > 0);
end;

procedure TestExportPsOutput;
var
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
  Args: TStringArray;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  SetLength(Args, 5);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'export';
  Args[3] := '--shell';
  Args[4] := 'ps';
  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Output := OutBuf.GetBuffer;

  Test('Export ps returns exit code 0', Ret = 0);
  Test('Export ps shows $env:', Pos('$env:FPDEV_ROOT=', Output) > 0);
end;

procedure TestHookRejectsExtraArg;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := ShellHookCommandFactory;

  Ret := Cmd.Execute(['bash', 'extra'], Ctx);

  Test('Hook extra arg returns usage error', Ret = 2);
  Test('Hook extra arg keeps stdout empty', Trim(OutBuf.GetBuffer) = '');
  Test('Hook extra arg prints usage to stderr',
    Pos('Usage: fpdev system env hook <shell>', ErrBuf.GetBuffer) > 0);
end;

procedure TestHookRejectsUnknownOption;
var
  Cmd: ICommand;
  OutBuf: TStringOutput;
  ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := ShellHookCommandFactory;

  Ret := Cmd.Execute(['--unknown'], Ctx);

  Test('Hook unknown option returns usage error', Ret = 2);
  Test('Hook unknown option keeps stdout empty', Trim(OutBuf.GetBuffer) = '');
  Test('Hook unknown option prints usage to stderr',
    Pos('Usage: fpdev system env hook <shell>', ErrBuf.GetBuffer) > 0);
end;

procedure TestUnknownSubcommand;
var
  Cmd: ICommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ErrOutput: string;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := CreateEnvCommand;

  Ret := Cmd.Execute(['invalid'], Ctx);
  ErrOutput := ErrBuf.GetBuffer;

  Test('Unknown subcommand returns non-zero', Ret <> 0);
  Test('Error mentions unknown', Pos('Unknown', ErrOutput) > 0);
end;

procedure TestDefaultContextUsesExplicitConfigPath;
var
  Ctx: IContext;
  TempDir: string;
  ConfigPath: string;
begin
  TempDir := CreateUniqueTempDir('test_cmd_env_ctx');
  try
    ConfigPath := TempDir + PathDelim + 'config.json';
    Ctx := TDefaultCommandContext.Create(ConfigPath);
    Test('Default context accepts explicit config path',
      ExpandFileName(Ctx.Config.GetConfigPath) = ExpandFileName(ConfigPath));
  finally
    CleanupTempDir(TempDir);
  end;
end;

procedure TestDefaultContextUsesIsolatedDefaultConfigPath;
var
  Ctx: IContext;
  ConfigPath: string;
begin
  Ctx := TDefaultCommandContext.Create;
  ConfigPath := ExpandFileName(Ctx.Config.GetConfigPath);

  Test('Default context uses system temp root',
    PathUsesSystemTempRoot(ConfigPath));
  Test('Default context uses isolated default config path',
    ConfigPath = ExpandFileName(GetIsolatedDefaultConfigPath));
end;

procedure TestRegisteredInGlobalRegistry;
var
  Ctx: IContext;
  Args: TStringArray;
  Ret: Integer;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 3);
  Args[0] := 'system';
  Args[1] := 'env';
  Args[2] := 'help';

  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Test('system env command registered in GlobalCommandRegistry', Ret = 0);
end;

begin
  WriteLn('=== fpdev.cmd.env Tests ===');
  WriteLn;

  TestCommandName;
  TestAliasesIsNil;
  TestFindSubReturnsNil;
  TestHelpOutput;
  TestOverviewOutput;
  TestOverviewUsesSameProcessEnvOverride;
  TestVarsOutput;
  TestVarsUseSameProcessEnvOverride;
  TestPathOutput;
  TestPathUsesSameProcessEnvOverride;
  TestExportBashOutput;
  TestExportCmdOutput;
  TestExportPsOutput;
  TestHookRejectsExtraArg;
  TestHookRejectsUnknownOption;
  TestUnknownSubcommand;
  TestDefaultContextUsesExplicitConfigPath;
  TestDefaultContextUsesIsolatedDefaultConfigPath;
  TestRegisteredInGlobalRegistry;

  WriteLn;
  WriteLn('=== Summary ===');
  WriteLn('Total:  ', GTestCount);
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);

  if GFailCount > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
