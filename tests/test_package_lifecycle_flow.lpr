program test_package_lifecycle_flow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.package.types,
  fpdev.utils.fs,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.package.lifecycle, test_temp_paths;

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

  TLifecycleProbe = class
  public
    DeleteResult: Boolean;
    InstallResult: Boolean;
    UninstallResult: Boolean;
    DeleteCalls: Integer;
    InstallCalls: Integer;
    UninstallCalls: Integer;
    LastDeletePath: string;
    LastInstallPackage: string;
    LastInstallVersion: string;
    LastUninstallPackage: string;
    LastInstallOutWasNil: Boolean;
    LastInstallErrWasNil: Boolean;
    LastUninstallOutWasNil: Boolean;
    LastUninstallErrWasNil: Boolean;
    function Install(const APackageName, AVersion: string; Outp, Errp: IOutput): Boolean;
    function Uninstall(const APackageName: string; Outp, Errp: IOutput): Boolean;
  end;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;
  GProbe: TLifecycleProbe = nil;

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

function MakeTempDir(const APrefix: string): string;
begin
  Result := CreateUniqueTempDir(APrefix);
end;

function DeleteDirBridge(const APath: string): Boolean;
begin
  if GProbe = nil then
    Exit(False);
  Inc(GProbe.DeleteCalls);
  GProbe.LastDeletePath := APath;
  Result := GProbe.DeleteResult;
end;

function TLifecycleProbe.Install(const APackageName, AVersion: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(InstallCalls);
  LastInstallPackage := APackageName;
  LastInstallVersion := AVersion;
  LastInstallOutWasNil := Outp = nil;
  LastInstallErrWasNil := Errp = nil;
  Result := InstallResult;
end;

function TLifecycleProbe.Uninstall(const APackageName: string; Outp, Errp: IOutput): Boolean;
begin
  Inc(UninstallCalls);
  LastUninstallPackage := APackageName;
  LastUninstallOutWasNil := Outp = nil;
  LastUninstallErrWasNil := Errp = nil;
  Result := UninstallResult;
end;

procedure TestUninstallPackageCoreDeletesInstallPathAndReportsSuccess;
var
  InstallPath: string;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  InstallPath := MakeTempDir('package-lifecycle-uninstall');
  try
    GProbe.DeleteResult := True;

    OK := UninstallPackageCore('alpha', InstallPath, True, @DeleteDirBridge, OutRef, ErrRef);

    Check('uninstall success returns true', OK, 'expected success');
    Check('uninstall delete callback invoked once', GProbe.DeleteCalls = 1,
      'delete calls=' + IntToStr(GProbe.DeleteCalls));
    Check('uninstall passes install path', GProbe.LastDeletePath = InstallPath,
      'path=' + GProbe.LastDeletePath);
    Check('uninstall writes start message',
      OutBuf.Contains(_Fmt(MSG_PKG_UNINSTALLING, ['alpha'])), 'missing uninstall start');
    Check('uninstall writes complete message',
      OutBuf.Contains(_Fmt(MSG_PKG_UNINSTALL_COMPLETE, ['alpha'])), 'missing uninstall complete');
    Check('uninstall keeps stderr clean on success', not ErrBuf.Contains(_(MSG_ERROR)), 'unexpected stderr');
  finally
    CleanupTempDir(InstallPath);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

procedure TestUninstallPackageCoreWarnsWhenDeleteFails;
var
  InstallPath: string;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  InstallPath := MakeTempDir('package-lifecycle-uninstall-warn');
  try
    GProbe.DeleteResult := False;

    OK := UninstallPackageCore('alpha', InstallPath, True, @DeleteDirBridge, OutRef, ErrRef);

    Check('uninstall warning still returns true', OK, 'expected success with warning');
    Check('uninstall warning message emitted',
      ErrBuf.Contains(_Fmt(MSG_PKG_REMOVE_WARNING, [InstallPath])), 'warning missing');
  finally
    CleanupTempDir(InstallPath);
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

procedure TestUpdatePackageCoreUsesLatestVersionAndDelegatesLifecycle;
var
  Available: TPackageArray;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    GProbe.UninstallResult := True;
    GProbe.InstallResult := True;

    SetLength(Available, 2);
    Available[0].Name := 'alpha';
    Available[0].Version := '1.0.0';
    Available[1].Name := 'alpha';
    Available[1].Version := '1.2.0';

    OK := UpdatePackageCore('alpha', '1.0.0', Available,
      @GProbe.Uninstall, @GProbe.Install, OutRef, ErrRef);

    Check('update success returns true', OK, 'expected success');
    Check('update calls uninstall once', GProbe.UninstallCalls = 1,
      'uninstall calls=' + IntToStr(GProbe.UninstallCalls));
    Check('update calls install once', GProbe.InstallCalls = 1,
      'install calls=' + IntToStr(GProbe.InstallCalls));
    Check('update installs latest version', GProbe.LastInstallVersion = '1.2.0',
      'version=' + GProbe.LastInstallVersion);
    Check('update uses nil stdout for uninstall delegate', GProbe.LastUninstallOutWasNil,
      'expected nil stdout for uninstall delegate');
    Check('update preserves stderr for uninstall delegate', not GProbe.LastUninstallErrWasNil,
      'expected stderr for uninstall delegate');
    Check('update uses nil stdout for install delegate', GProbe.LastInstallOutWasNil,
      'expected nil stdout for install delegate');
    Check('update reports latest version',
      OutBuf.Contains(_Fmt(MSG_PKG_LATEST_VERSION, ['1.2.0'])), 'latest version missing');
    Check('update reports success message',
      OutBuf.Contains(_Fmt(MSG_PKG_UPDATE_SUCCESS, ['alpha', '1.2.0'])), 'success message missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

procedure TestUpdatePackageCoreSkipsLifecycleWhenAlreadyCurrent;
var
  Available: TPackageArray;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    SetLength(Available, 1);
    Available[0].Name := 'alpha';
    Available[0].Version := '1.2.0';

    OK := UpdatePackageCore('alpha', '1.2.0', Available,
      @GProbe.Uninstall, @GProbe.Install, OutRef, ErrRef);

    Check('up-to-date package returns true', OK, 'expected success');
    Check('up-to-date skips uninstall', GProbe.UninstallCalls = 0,
      'uninstall calls=' + IntToStr(GProbe.UninstallCalls));
    Check('up-to-date skips install', GProbe.InstallCalls = 0,
      'install calls=' + IntToStr(GProbe.InstallCalls));
    Check('up-to-date message emitted',
      OutBuf.Contains(_Fmt(MSG_PKG_UP_TO_DATE, ['alpha'])), 'up-to-date missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

procedure TestUpdatePackageCoreReportsMissingIndexEntry;
var
  Available: TPackageArray;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    SetLength(Available, 1);
    Available[0].Name := 'beta';
    Available[0].Version := '9.0.0';

    OK := UpdatePackageCore('alpha', '1.0.0', Available,
      @GProbe.Uninstall, @GProbe.Install, OutRef, ErrRef);

    Check('missing index entry returns false', not OK, 'expected failure');
    Check('missing index entry skips uninstall', GProbe.UninstallCalls = 0,
      'uninstall calls=' + IntToStr(GProbe.UninstallCalls));
    Check('missing index entry reports error',
      ErrBuf.Contains(_Fmt(CMD_PKG_NOT_IN_INDEX, ['alpha'])), 'index error missing');
    Check('missing index entry prints repo hint',
      ErrBuf.Contains(_(MSG_PKG_REPO_UPDATE_HINT)), 'repo hint missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

procedure TestUpdatePackageCoreReportsInstallFailure;
var
  Available: TPackageArray;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  OK: Boolean;
begin
  GProbe := TLifecycleProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    GProbe.UninstallResult := True;
    GProbe.InstallResult := False;

    SetLength(Available, 1);
    Available[0].Name := 'alpha';
    Available[0].Version := '1.2.0';

    OK := UpdatePackageCore('alpha', '1.0.0', Available,
      @GProbe.Uninstall, @GProbe.Install, OutRef, ErrRef);

    Check('install failure returns false', not OK, 'expected failure');
    Check('install failure still uninstalls once', GProbe.UninstallCalls = 1,
      'uninstall calls=' + IntToStr(GProbe.UninstallCalls));
    Check('install failure attempts install once', GProbe.InstallCalls = 1,
      'install calls=' + IntToStr(GProbe.InstallCalls));
    Check('install failure reports error',
      ErrBuf.Contains(_(CMD_PKG_INSTALL_NEW_FAILED)), 'install error missing');
    Check('install failure prints reinstall hint',
      ErrBuf.Contains(_(MSG_PKG_REINSTALL_HINT)), 'reinstall hint missing');
  finally
    OutRef := nil;
    ErrRef := nil;
    OutBuf := nil;
    ErrBuf := nil;
    GProbe.Free;
    GProbe := nil;
  end;
end;

begin
  TestUninstallPackageCoreDeletesInstallPathAndReportsSuccess;
  TestUninstallPackageCoreWarnsWhenDeleteFails;
  TestUpdatePackageCoreUsesLatestVersionAndDelegatesLifecycle;
  TestUpdatePackageCoreSkipsLifecycleWhenAlreadyCurrent;
  TestUpdatePackageCoreReportsMissingIndexEntry;
  TestUpdatePackageCoreReportsInstallFailure;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);
  if FailCount > 0 then
    Halt(1);
end.
