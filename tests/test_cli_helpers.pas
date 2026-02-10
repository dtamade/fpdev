unit test_cli_helpers;

{$mode objfpc}{$H+}

(*
  Shared test helpers for CLI integration tests.

  Provides:
  - TStringOutput: captures output to a string buffer
  - TTestContext: mock IContext for command testing
  - CreateTestContext: factory function for creating test contexts
  - Test assertion procedure with counter

  B186: CLI test infrastructure
*)

interface

uses
  SysUtils, Classes,
  fpdev.output.intf, fpdev.command.intf, fpdev.config.interfaces,
  fpdev.config.managers, fpdev.logger.intf;

type
  { TStringOutput - Captures output to a string buffer for testing }
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
    function LineCount: Integer;
    procedure Clear;
  end;

  { TTestContext - Mock IContext for command testing }
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

{ Global test counters }
var
  GTestCount: Integer;
  GPassCount: Integer;
  GFailCount: Integer;

{ Test assertion }
procedure Check(const AName: string; ACondition: Boolean);

{ Create a test context with captured output }
function CreateTestContext(const AConfigDir: string;
  out AStdOut, AStdErr: TStringOutput): IContext;

{ Print test summary and return exit code }
function PrintTestSummary: Integer;

implementation

{ Global test assertion }

procedure Check(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  if ACondition then
  begin
    Inc(GPassCount);
    System.WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailCount);
    System.WriteLn('[FAIL] ', AName);
  end;
end;

function CreateTestContext(const AConfigDir: string;
  out AStdOut, AStdErr: TStringOutput): IContext;
var
  Config: IConfigManager;
begin
  AStdOut := TStringOutput.Create;
  AStdErr := TStringOutput.Create;
  Config := TConfigManager.Create(AConfigDir + PathDelim + 'config.json');
  Config.CreateDefaultConfig;
  Config.LoadConfig;
  Result := TTestContext.Create(AStdOut, AStdErr, Config);
end;

function PrintTestSummary: Integer;
begin
  System.WriteLn('');
  System.WriteLn('=== Test Summary ===');
  System.WriteLn('Total:  ', GTestCount);
  System.WriteLn('Passed: ', GPassCount);
  System.WriteLn('Failed: ', GFailCount);
  System.WriteLn;
  if GFailCount > 0 then
    Result := 1
  else
    Result := 0;
end;

{ TStringOutput }

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
  if AColor = ccDefault then; // suppress unused hint
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

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TStringOutput.LineCount: Integer;
begin
  Result := FBuffer.Count;
end;

procedure TStringOutput.Clear;
begin
  FBuffer.Clear;
end;

{ TTestContext }

constructor TTestContext.Create(AOut, AErr: IOutput; AConfig: IConfigManager);
begin
  inherited Create;
  FOut := AOut;
  FErr := AErr;
  FConfig := AConfig;
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
  Result := FConfig;
end;

function TTestContext.Logger: ILogger;
begin
  Result := nil;
end;

procedure TTestContext.SaveIfModified;
begin
  // No-op for testing
end;

initialization
  GTestCount := 0;
  GPassCount := 0;
  GFailCount := 0;

end.
