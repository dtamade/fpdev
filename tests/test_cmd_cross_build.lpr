program test_cmd_cross_build;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_config_isolation,
  fpdev.command.intf, fpdev.command.registry, fpdev.command.context,
  fpdev.output.intf, fpdev.config.interfaces, fpdev.logger.intf,
  fpdev.cmd.cross.build, test_temp_paths;

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

{ Test output capture - full IOutput implementation }
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

{ Test context with custom output }
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
  Cmd: TCrossBuildCommand;
begin
  Cmd := TCrossBuildCommand.Create;
  try
    Test('Command name is "build"', Cmd.Name = 'build');
  finally
    Cmd.Free;
  end;
end;

procedure TestAliasesIsNil;
var
  Cmd: TCrossBuildCommand;
begin
  Cmd := TCrossBuildCommand.Create;
  try
    Test('Aliases returns nil', Cmd.Aliases = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestFindSubReturnsNil;
var
  Cmd: TCrossBuildCommand;
begin
  Cmd := TCrossBuildCommand.Create;
  try
    Test('FindSub returns nil', Cmd.FindSub('test') = nil);
  finally
    Cmd.Free;
  end;
end;

procedure TestHelpOutput;
var
  Cmd: TCrossBuildCommand;
  OutBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, OutBuf);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute(['help'], Ctx);
    Output := OutBuf.GetBuffer;

    Test('Help returns exit code 0', Ret = 0);
    Test('Help contains Usage', Pos('Usage:', Output) > 0);
    Test('Help contains --dry-run', Pos('--dry-run', Output) > 0);
    Test('Help contains --source', Pos('--source', Output) > 0);
    Test('Help contains --sandbox', Pos('--sandbox', Output) > 0);
    Test('Help contains examples', Pos('Examples:', Output) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestMissingTarget;
var
  Cmd: TCrossBuildCommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ErrOutput: string;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute([], Ctx);
    ErrOutput := ErrBuf.GetBuffer;

    Test('Missing target returns non-zero exit code', Ret <> 0);
    Test('Error mentions target not specified',
         Pos('target not specified', LowerCase(ErrOutput)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestInvalidTargetFormat;
var
  Cmd: TCrossBuildCommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ErrOutput: string;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute(['invalid'], Ctx);
    ErrOutput := ErrBuf.GetBuffer;

    Test('Invalid target format returns non-zero exit code', Ret <> 0);
    Test('Error mentions invalid target format',
         Pos('invalid target format', LowerCase(ErrOutput)) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestDryRunShowsBuildPlan;
var
  Cmd: TCrossBuildCommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Output: string;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := TCrossBuildCommand.Create;
  try
    // Note: This will fail at build stage since no source exists,
    // but we can check the initial output
    Cmd.Execute(['x86_64-win64', '--dry-run'], Ctx);
    Output := OutBuf.GetBuffer;

    Test('Dry-run shows Build Plan', Pos('Build Plan:', Output) > 0);
    Test('Dry-run shows Step 1', Pos('Step 1:', Output) > 0);
    Test('Dry-run shows compiler_cycle', Pos('compiler_cycle', Output) > 0);
    Test('Dry-run shows rtl_all', Pos('rtl_all', Output) > 0);
    Test('Dry-run shows target CPU-OS', Pos('x86_64-win64', Output) > 0);
    Test('Dry-run shows Source path', Pos('Source:', Output) > 0);
    Test('Dry-run shows Sandbox path', Pos('Sandbox:', Output) > 0);
    Test('Dry-run shows Version', Pos('Version:', Output) > 0);
  finally
    Cmd.Free;
  end;
end;

procedure TestNonDryRunMissingMakefileIsHelpful;
var
  Cmd: TCrossBuildCommand;
  OutBuf, ErrBuf: TStringOutput;
  Ctx: IContext;
  Ret: Integer;
  ErrOutput, SrcRoot, SrcTree: string;
begin
  SrcRoot := CreateUniqueTempDir('fpdev_test_cross_build_src');
  SrcTree := SrcRoot + PathDelim + 'fpc-main';
  ForceDirectories(SrcTree);

  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  Ctx := TTestContext.Create(OutBuf, ErrBuf);
  Cmd := TCrossBuildCommand.Create;
  try
    Ret := Cmd.Execute(['x86_64-win64', '--source=' + SrcRoot, '--version=main'], Ctx);
    ErrOutput := ErrBuf.GetBuffer;

    Test('Non-dry-run missing Makefile returns non-zero exit code', Ret <> 0);
    Test('Non-dry-run missing Makefile mentions "Makefile"', Pos('makefile', LowerCase(ErrOutput)) > 0);
    Test('Non-dry-run missing Makefile mentions source tree path', Pos(SrcTree, ErrOutput) > 0);
  finally
    Cmd.Free;
    CleanupTempDir(SrcRoot);
  end;
end;

procedure TestRegisteredInGlobalRegistry;
var
  Ctx: IContext;
  Args: TStringArray;
  Ret: Integer;
begin
  Ctx := TDefaultCommandContext.Create;
  SetLength(Args, 3);
  Args[0] := 'cross';
  Args[1] := 'build';
  Args[2] := 'help';

  Ret := GlobalCommandRegistry.DispatchPath(Args, Ctx);
  Test('cross build command registered in GlobalCommandRegistry', Ret = 0);
end;

begin
  WriteLn('=== fpdev.cmd.cross.build Tests ===');
  WriteLn;

  TestCommandName;
  TestAliasesIsNil;
  TestFindSubReturnsNil;
  TestHelpOutput;
  TestMissingTarget;
  TestInvalidTargetFormat;
  TestDryRunShowsBuildPlan;
  TestNonDryRunMissingMakefileIsHelpful;
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
