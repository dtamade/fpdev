program test_cross_installsupportflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.config.interfaces,
  fpdev.cross.query,
  fpdev.cross.installsupportflow;

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

  TInstallSupportProbe = class
  public
    BinutilsDownloadResult: Boolean;
    LibrariesDownloadResult: Boolean;
    SaveResult: Boolean;
    InstallPath: string;
    LastErrorText: string;
    DownloadBinutilsCalls: Integer;
    DownloadLibrariesCalls: Integer;
    GetInstallPathCalls: Integer;
    SaveCalls: Integer;
    LastTarget: string;
    SavedTarget: TCrossTarget;
    function DownloadBinutils(const ATarget: string): Boolean;
    function DownloadLibraries(const ATarget: string): Boolean;
    function GetDownloaderLastError: string;
    function GetInstallPath(const ATarget: string): string;
    function SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
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

function TInstallSupportProbe.DownloadBinutils(const ATarget: string): Boolean;
begin
  Inc(DownloadBinutilsCalls);
  LastTarget := ATarget;
  Result := BinutilsDownloadResult;
end;

function TInstallSupportProbe.DownloadLibraries(const ATarget: string): Boolean;
begin
  Inc(DownloadLibrariesCalls);
  LastTarget := ATarget;
  Result := LibrariesDownloadResult;
end;

function TInstallSupportProbe.GetDownloaderLastError: string;
begin
  Result := LastErrorText;
end;

function TInstallSupportProbe.GetInstallPath(const ATarget: string): string;
begin
  Inc(GetInstallPathCalls);
  LastTarget := ATarget;
  Result := InstallPath;
end;

function TInstallSupportProbe.SaveCrossTargetConfig(const ATarget: string; const AInfo: TCrossTarget): Boolean;
begin
  Inc(SaveCalls);
  LastTarget := ATarget;
  SavedTarget := AInfo;
  Result := SaveResult;
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

procedure TestDownloadBinutilsFailsWithoutDownloader;
var
  OutBuf: TStringOutput;
  OutRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  TargetInfo := Default(TCrossTargetQueryInfo);
  OK := ExecuteCrossDownloadBinutilsSurfaceCore(
    'win64',
    TargetInfo,
    nil,
    nil,
    OutRef
  );
  Check('binutils downloader required', not OK, 'expected missing downloader to fail');
  Check('binutils downloader error output',
    OutBuf.Contains('Toolchain downloader not initialized'),
    OutBuf.Text);
end;

procedure TestDownloadBinutilsFailureShowsManualFallback;
var
  Probe: TInstallSupportProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  Probe := TInstallSupportProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Probe.BinutilsDownloadResult := False;
    Probe.LastErrorText := 'manifest missing';
    TargetInfo := Default(TCrossTargetQueryInfo);
    OK := ExecuteCrossDownloadBinutilsSurfaceCore(
      'win64',
      TargetInfo,
      @Probe.DownloadBinutils,
      @Probe.GetDownloaderLastError,
      OutRef
    );
    Check('binutils download failure returns false', not OK, 'expected false on failed download');
    Check('binutils download called once', Probe.DownloadBinutilsCalls = 1,
      'calls=' + IntToStr(Probe.DownloadBinutilsCalls));
    Check('binutils failure prints last error',
      OutBuf.Contains('manifest missing'),
      OutBuf.Text);
    Check('binutils failure prints manual fallback hint',
      OutBuf.Contains('manifest'),
      OutBuf.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestDownloadLibrariesFailureAllowsManualConfiguration;
var
  Probe: TInstallSupportProbe;
  OutBuf: TStringOutput;
  OutRef: IOutput;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  Probe := TInstallSupportProbe.Create;
  OutBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  try
    Probe.LibrariesDownloadResult := False;
    TargetInfo := Default(TCrossTargetQueryInfo);
    OK := ExecuteCrossDownloadLibrariesSurfaceCore(
      'win64',
      TargetInfo,
      @Probe.DownloadLibraries,
      OutRef
    );
    Check('libraries download failure tolerated', OK, 'expected manual configuration fallback');
    Check('libraries download called once', Probe.DownloadLibrariesCalls = 1,
      'calls=' + IntToStr(Probe.DownloadLibrariesCalls));
    Check('libraries manual install hint emitted',
      OutBuf.Contains('Please install libraries manually'),
      OutBuf.Text);
  finally
    Probe.Free;
  end;
end;

procedure TestSetupEnvironmentBuildsPathsAndSavesConfig;
var
  Probe: TInstallSupportProbe;
  TargetInfo: TCrossTargetQueryInfo;
  OK: Boolean;
begin
  Probe := TInstallSupportProbe.Create;
  try
    Probe.InstallPath := '/tmp/cross/win64';
    Probe.SaveResult := True;
    TargetInfo := Default(TCrossTargetQueryInfo);
    OK := ExecuteCrossSetupEnvironmentSurfaceCore(
      'win64',
      TargetInfo,
      @Probe.GetInstallPath,
      @Probe.SaveCrossTargetConfig
    );
    Check('setup environment succeeds', OK, 'expected setup to succeed');
    Check('setup requested install path once', Probe.GetInstallPathCalls = 1,
      'calls=' + IntToStr(Probe.GetInstallPathCalls));
    Check('setup saved config once', Probe.SaveCalls = 1,
      'calls=' + IntToStr(Probe.SaveCalls));
    Check('setup enables target', Probe.SavedTarget.Enabled, 'expected enabled');
    Check('setup binutils path derived from install root',
      Probe.SavedTarget.BinutilsPath = '/tmp/cross/win64/bin',
      Probe.SavedTarget.BinutilsPath);
    Check('setup libraries path derived from install root',
      Probe.SavedTarget.LibrariesPath = '/tmp/cross/win64/lib',
      Probe.SavedTarget.LibrariesPath);
  finally
    Probe.Free;
  end;
end;

begin
  TestDownloadBinutilsFailsWithoutDownloader;
  TestDownloadBinutilsFailureShowsManualFallback;
  TestDownloadLibrariesFailureAllowsManualConfiguration;
  TestSetupEnvironmentBuildsPathsAndSavesConfig;

  WriteLn('Pass: ', PassCount);
  WriteLn('Fail: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
