program test_project_cleanflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, test_temp_paths,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  fpdev.output.intf,
  fpdev.project.cleanflow,
  fpdev.i18n,
  fpdev.i18n.strings;

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
    function Contains(const S: string): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

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

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

procedure Pass(const AName: string);
begin
  WriteLn('[PASS] ', AName);
  Inc(PassCount);
end;

procedure Fail(const AName, AReason: string);
begin
  WriteLn('[FAIL] ', AName, ': ', AReason);
  Inc(FailCount);
end;

procedure Check(const AName: string; ACondition: Boolean; const AReason: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, AReason);
end;

procedure WriteFile(const APath, AContent: string);
var
  F: TextFile;
begin
  AssignFile(F, APath);
  Rewrite(F);
  try
    if AContent <> '' then
      Write(F, AContent);
  finally
    CloseFile(F);
  end;
end;

procedure TestExecuteProjectCleanCoreFailsForMissingDir;
var
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    OK := ExecuteProjectCleanCore('/tmp/fpdev-project-cleanflow-missing', OutRef, ErrRef);

    Check('cleanflow missing dir returns false', not OK, 'unexpected success');
    Check('cleanflow missing dir writes error',
      ErrBuf.Contains(_Fmt(CMD_PROJECT_DIR_NOT_FOUND, ['/tmp/fpdev-project-cleanflow-missing'])),
      'missing error output');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
  end;
end;

procedure TestExecuteProjectCleanCoreHandlesEmptyDir;
var
  Dir: string;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  Dir := CreateUniqueTempDir('project-cleanflow-empty');
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    OK := ExecuteProjectCleanCore(Dir, OutRef, ErrRef);

    Check('cleanflow empty dir returns true', OK, 'unexpected failure');
    Check('cleanflow empty dir keeps directory', DirectoryExists(Dir), 'directory removed');
    Check('cleanflow empty dir writes cleaned message',
      OutBuf.Contains(_Fmt(CMD_PROJECT_CLEANED, [0, Dir])),
      'missing cleaned message');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    CleanupTempDir(Dir);
  end;
end;

procedure TestExecuteProjectCleanCoreRemovesArtifactsAndKeepsSources;
var
  Dir: string;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
  ExecutablePath: string;
begin
  Dir := CreateUniqueTempDir('project-cleanflow-artifacts');
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    WriteFile(Dir + PathDelim + 'main.o', 'obj');
    WriteFile(Dir + PathDelim + 'unit1.ppu', 'ppu');
    WriteFile(Dir + PathDelim + 'demo.lpr', 'program demo; begin end.');
    WriteFile(Dir + PathDelim + 'demo.pas', 'unit demo; interface implementation end.');
    {$IFDEF MSWINDOWS}
    ExecutablePath := Dir + PathDelim + 'demo.exe';
    {$ELSE}
    ExecutablePath := Dir + PathDelim + 'demo';
    {$ENDIF}
    WriteFile(ExecutablePath, 'exe');
    {$IFDEF UNIX}
    FpChmod(ExecutablePath, &755);
    {$ENDIF}

    OK := ExecuteProjectCleanCore(Dir, OutRef, ErrRef);

    Check('cleanflow artifact dir returns true', OK, 'unexpected failure');
    Check('cleanflow removes .o', not FileExists(Dir + PathDelim + 'main.o'), '.o still exists');
    Check('cleanflow removes .ppu', not FileExists(Dir + PathDelim + 'unit1.ppu'), '.ppu still exists');
    Check('cleanflow removes executable', not FileExists(ExecutablePath), 'executable still exists');
    Check('cleanflow keeps .lpr', FileExists(Dir + PathDelim + 'demo.lpr'), '.lpr removed');
    Check('cleanflow keeps .pas', FileExists(Dir + PathDelim + 'demo.pas'), '.pas removed');
    Check('cleanflow writes cleaned message',
      OutBuf.Contains(_Fmt(CMD_PROJECT_CLEANED, [3, Dir])),
      'missing cleaned message');
    Check('cleanflow keeps stderr quiet', not ErrBuf.Contains(_(MSG_ERROR)),
      'unexpected stderr');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    CleanupTempDir(Dir);
  end;
end;

begin
  TestExecuteProjectCleanCoreFailsForMissingDir;
  TestExecuteProjectCleanCoreHandlesEmptyDir;
  TestExecuteProjectCleanCoreRemovesArtifactsAndKeepsSources;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
