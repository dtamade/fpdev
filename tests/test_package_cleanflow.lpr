program test_package_cleanflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.package.cleanflow;

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
    function Text: string;
  end;

  TCleanProbe = class
  public
    ExistingPaths: TStringList;
    DeletedPaths: TStringList;
    FailPath: string;
    constructor Create;
    destructor Destroy; override;
    function PathExists(const APath: string): Boolean;
    function DeleteDir(const APath: string): Boolean;
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

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

constructor TCleanProbe.Create;
begin
  inherited Create;
  ExistingPaths := TStringList.Create;
  DeletedPaths := TStringList.Create;
end;

destructor TCleanProbe.Destroy;
begin
  DeletedPaths.Free;
  ExistingPaths.Free;
  inherited Destroy;
end;

function TCleanProbe.PathExists(const APath: string): Boolean;
begin
  Result := ExistingPaths.IndexOf(APath) >= 0;
end;

function TCleanProbe.DeleteDir(const APath: string): Boolean;
begin
  DeletedPaths.Add(APath);
  Result := not SameText(APath, FailPath);
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

procedure TestExecutePackageCleanCoreCleansSandbox;
var
  Probe: TCleanProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  SandboxDir, CacheDir: string;
begin
  Probe := TCleanProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  SandboxDir := '/tmp/fpdev-sandbox';
  CacheDir := '/tmp/fpdev-cache/packages';
  try
    Probe.ExistingPaths.Add(SandboxDir);

    Check('clean core succeeds for sandbox scope',
      ExecutePackageCleanCore('sandbox', SandboxDir, CacheDir,
        @Probe.PathExists, @Probe.DeleteDir, OutRef, ErrRef));
    Check('clean core deletes sandbox path',
      (Probe.DeletedPaths.Count = 1) and (Probe.DeletedPaths[0] = SandboxDir),
      'deleted=' + Probe.DeletedPaths.Text);
    Check('clean core reports cleaned sandbox',
      OutBuf.Contains(_Fmt(MSG_CLEANED, [SandboxDir])), OutBuf.Text);
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageCleanCoreSkipsMissingCache;
var
  Probe: TCleanProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  Probe := TCleanProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Check('clean core succeeds for missing cache dir',
      ExecutePackageCleanCore('cache', '/tmp/fpdev-sandbox', '/tmp/fpdev-cache/packages',
        @Probe.PathExists, @Probe.DeleteDir, OutRef, ErrRef));
    Check('clean core skips delete for missing cache dir',
      Probe.DeletedPaths.Count = 0, 'delete count=' + IntToStr(Probe.DeletedPaths.Count));
    Check('clean core keeps stdout clean for missing cache dir',
      OutBuf.Text = '', OutBuf.Text);
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageCleanCoreReportsCacheDeleteFailure;
var
  Probe: TCleanProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  SandboxDir, CacheDir: string;
begin
  Probe := TCleanProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  SandboxDir := '/tmp/fpdev-sandbox';
  CacheDir := '/tmp/fpdev-cache/packages';
  try
    Probe.ExistingPaths.Add(SandboxDir);
    Probe.ExistingPaths.Add(CacheDir);
    Probe.FailPath := CacheDir;

    Check('clean core returns false when cache cleanup fails',
      not ExecutePackageCleanCore('all', SandboxDir, CacheDir,
        @Probe.PathExists, @Probe.DeleteDir, OutRef, ErrRef));
    Check('clean core still attempts both deletions',
      Probe.DeletedPaths.Count = 2, 'delete count=' + IntToStr(Probe.DeletedPaths.Count));
    Check('clean core reports cleaned sandbox before failure',
      OutBuf.Contains(_Fmt(MSG_CLEANED, [SandboxDir])), OutBuf.Text);
    Check('clean core reports failed cache cleanup',
      ErrBuf.Contains(_Fmt(MSG_CLEAN_FAILED, [CacheDir])), ErrBuf.Text);
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  Package Clean Flow');
  WriteLn('========================================');
  WriteLn;

  TestExecutePackageCleanCoreCleansSandbox;
  TestExecutePackageCleanCoreSkipsMissingCache;
  TestExecutePackageCleanCoreReportsCacheDeleteFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
