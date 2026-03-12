program test_package_facadeflow;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.output.intf,
  fpdev.i18n,
  fpdev.i18n.strings,
  fpdev.exitcodes,
  fpdev.package.metadataio,
  fpdev.package.facadeflow;

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

  TPackageFacadeHarness = class
  public
    DirectoryExistsResult: Boolean;
    ValidatePackageResult: Boolean;
    InstallFromSourceResult: Boolean;
    InstallFromSourceRaises: Boolean;
    EnsureMetadataResult: Boolean;
    MetadataCreated: Boolean;
    EnsureMetadataError: string;
    IsInstalledResult: Boolean;
    InstallPathValue: string;
    ResolvePublishResult: Boolean;
    PublishVersion: string;
    PublishSourcePath: string;
    PublishSourceFromMeta: string;
    PublishStatus: TPackageMetadataLoadStatus;
    PublishError: string;
    HandleMetaFailureExitCode: Integer;
    CreateArchiveResult: Boolean;
    CreateArchiveExitCode: Integer;
    CreateArchivePath: string;
    ResolvedPackageName: string;
    LastPath: string;
    LastPackageName: string;
    LastSourceDir: string;
    LastMetaPath: string;
    LastInstallRoot: string;
    LastArchivePackageName: string;
    LastArchiveVersion: string;
    LastArchiveSourcePath: string;
    function DirectoryExistsAt(const APath: string): Boolean;
    function ResolvePackageName(const AMetaPath, ADefaultName: string): string;
    function InstallFromSource(const APackageName, ASourcePath: string): Boolean;
    function ValidatePackageName(const APackageName: string): Boolean;
    function EnsureMetadataFile(const APackageName, ASourceDir, AMetaPath: string;
      out ACreated: Boolean; out AError: string): Boolean;
    function IsInstalled(const APackageName: string): Boolean;
    function GetInstallPath(const APackageName: string): string;
    function ResolvePublishMetadata(const AInstallPath, ADefaultVersion: string;
      out AVersion, AArchiveSourcePath, ASourcePathFromMeta: string;
      out AStatus: TPackageMetadataLoadStatus; out AError: string): Boolean;
    function HandleMetadataFailure(AStatus: TPackageMetadataLoadStatus;
      const AError: string; Errp: IOutput): Integer;
    function CreateArchive(const APackageName, AVersion, AArchiveSourcePath,
      AInstallRoot: string; Outp, Errp: IOutput; out AArchivePath: string;
      out AExitCode: Integer): Boolean;
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

function TPackageFacadeHarness.DirectoryExistsAt(const APath: string): Boolean;
begin
  LastPath := APath;
  Result := DirectoryExistsResult;
end;

function TPackageFacadeHarness.ResolvePackageName(const AMetaPath, ADefaultName: string): string;
begin
  LastMetaPath := AMetaPath;
  LastPackageName := ADefaultName;
  if ResolvedPackageName <> '' then
    Result := ResolvedPackageName
  else
    Result := ADefaultName;
end;

function TPackageFacadeHarness.InstallFromSource(const APackageName, ASourcePath: string): Boolean;
begin
  LastPackageName := APackageName;
  LastSourceDir := ASourcePath;
  if InstallFromSourceRaises then
    raise Exception.Create('source install boom');
  Result := InstallFromSourceResult;
end;

function TPackageFacadeHarness.ValidatePackageName(const APackageName: string): Boolean;
begin
  LastPackageName := APackageName;
  Result := ValidatePackageResult;
end;

function TPackageFacadeHarness.EnsureMetadataFile(const APackageName, ASourceDir, AMetaPath: string;
  out ACreated: Boolean; out AError: string): Boolean;
begin
  LastPackageName := APackageName;
  LastSourceDir := ASourceDir;
  LastMetaPath := AMetaPath;
  ACreated := MetadataCreated;
  AError := EnsureMetadataError;
  Result := EnsureMetadataResult;
end;

function TPackageFacadeHarness.IsInstalled(const APackageName: string): Boolean;
begin
  LastPackageName := APackageName;
  Result := IsInstalledResult;
end;

function TPackageFacadeHarness.GetInstallPath(const APackageName: string): string;
begin
  LastPackageName := APackageName;
  Result := InstallPathValue;
end;

function TPackageFacadeHarness.ResolvePublishMetadata(const AInstallPath, ADefaultVersion: string;
  out AVersion, AArchiveSourcePath, ASourcePathFromMeta: string;
  out AStatus: TPackageMetadataLoadStatus; out AError: string): Boolean;
begin
  LastPath := AInstallPath;
  AVersion := PublishVersion;
  AArchiveSourcePath := PublishSourcePath;
  ASourcePathFromMeta := PublishSourceFromMeta;
  AStatus := PublishStatus;
  AError := PublishError;
  if PublishVersion = '' then
    PublishVersion := ADefaultVersion;
  Result := ResolvePublishResult;
end;

function TPackageFacadeHarness.HandleMetadataFailure(AStatus: TPackageMetadataLoadStatus;
  const AError: string; Errp: IOutput): Integer;
begin
  if Errp <> nil then
    Errp.WriteLn('handled metadata failure: ' + AError);
  PublishStatus := AStatus;
  PublishError := AError;
  Result := HandleMetaFailureExitCode;
end;

function TPackageFacadeHarness.CreateArchive(const APackageName, AVersion, AArchiveSourcePath,
  AInstallRoot: string; Outp, Errp: IOutput; out AArchivePath: string;
  out AExitCode: Integer): Boolean;
begin
  LastArchivePackageName := APackageName;
  LastArchiveVersion := AVersion;
  LastArchiveSourcePath := AArchiveSourcePath;
  LastInstallRoot := AInstallRoot;
  AArchivePath := CreateArchivePath;
  AExitCode := CreateArchiveExitCode;
  if Outp <> nil then
    Outp.WriteLn('create archive called');
  if Errp = nil then;
  Result := CreateArchiveResult;
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

procedure TestInstallFromLocalFailsWhenPathMissing;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.DirectoryExistsResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackageInstallFromLocalCore('/tmp/pkg', Outp, Errp,
      @Harness.DirectoryExistsAt, @Harness.ResolvePackageName, @Harness.InstallFromSource);
    Check('install-local fails when directory missing', not OK, 'unexpected success');
    Check('install-local emits missing path error', Errp.Contains(_Fmt(CMD_PKG_PATH_NOT_FOUND, ['/tmp/pkg'])), Errp.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestInstallFromLocalResolvesMetadataNameAndReportsSuccess;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.DirectoryExistsResult := True;
  Harness.ResolvedPackageName := 'meta-name';
  Harness.InstallFromSourceResult := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackageInstallFromLocalCore('/tmp/pkg', Outp, Errp,
      @Harness.DirectoryExistsAt, @Harness.ResolvePackageName, @Harness.InstallFromSource);
    Check('install-local succeeds when source install succeeds', OK, 'unexpected failure');
    Check('install-local passes metadata-resolved name', Harness.LastPackageName = 'meta-name', Harness.LastPackageName);
    Check('install-local prints local install message', Outp.Contains(_Fmt(MSG_PKG_INSTALL_LOCAL, ['/tmp/pkg'])), Outp.Text);
    Check('install-local prints completion message', Outp.Contains(_Fmt(MSG_PKG_INSTALL_COMPLETE, ['meta-name'])), Outp.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestCreatePackageRejectsInvalidName;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.ValidatePackageResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackageCreateCore('bad!', '/tmp/src', '/tmp/cwd', Outp, Errp,
      @Harness.ValidatePackageName, @Harness.DirectoryExistsAt, @Harness.EnsureMetadataFile);
    Check('create rejects invalid name', not OK, 'unexpected success');
    Check('create emits invalid name error', Errp.Contains(_Fmt(CMD_PKG_INVALID_NAME, ['bad!'])), Errp.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestCreatePackageWritesCreatedMetadataAndNextSteps;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.ValidatePackageResult := True;
  Harness.DirectoryExistsResult := True;
  Harness.EnsureMetadataResult := True;
  Harness.MetadataCreated := True;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackageCreateCore('demo', '/tmp/src', '/tmp/cwd', Outp, Errp,
      @Harness.ValidatePackageName, @Harness.DirectoryExistsAt, @Harness.EnsureMetadataFile);
    Check('create succeeds when metadata helper succeeds', OK, 'unexpected failure');
    Check('create passes source dir', Harness.LastSourceDir = ExpandFileName('/tmp/src'), Harness.LastSourceDir);
    Check('create writes created json message', Outp.Contains(_Fmt(MSG_PKG_CREATED_JSON, [IncludeTrailingPathDelimiter(ExpandFileName('/tmp/src')) + 'package.json'])), Outp.Text);
    Check('create writes success message', Outp.Contains(_Fmt(MSG_PKG_CREATE_SUCCESS, ['demo'])), Outp.Text);
    Check('create writes next steps', Outp.Contains(_(MSG_PKG_NEXT_STEPS)), Outp.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestPublishPackageFailsWhenNotInstalled;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  ExitCode: Integer;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.IsInstalledResult := False;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackagePublishCore('demo', '1.0.0', '/tmp/install-root', Outp, Errp,
      @Harness.IsInstalled, @Harness.GetInstallPath, @Harness.ResolvePublishMetadata,
      @Harness.HandleMetadataFailure, @Harness.CreateArchive, ExitCode);
    Check('publish fails when package not installed', not OK, 'unexpected success');
    Check('publish returns not found exit code', ExitCode = EXIT_NOT_FOUND, 'exit=' + IntToStr(ExitCode));
    Check('publish emits not found error', Errp.Contains(_Fmt(CMD_PKG_NOT_FOUND, ['demo'])), Errp.Text);
  finally
    Harness.Free;
  end;
end;

procedure TestPublishPackageUsesMetadataFailureHandler;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  ExitCode: Integer;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.IsInstalledResult := True;
  Harness.InstallPathValue := '/tmp/install-root/demo';
  Harness.ResolvePublishResult := False;
  Harness.PublishStatus := pmlsMissing;
  Harness.PublishError := 'meta missing';
  Harness.HandleMetaFailureExitCode := EXIT_IO_ERROR;
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackagePublishCore('demo', '1.0.0', '/tmp/install-root', Outp, Errp,
      @Harness.IsInstalled, @Harness.GetInstallPath, @Harness.ResolvePublishMetadata,
      @Harness.HandleMetadataFailure, @Harness.CreateArchive, ExitCode);
    Check('publish fails when metadata resolve fails', not OK, 'unexpected success');
    Check('publish uses metadata failure exit code', ExitCode = EXIT_IO_ERROR, 'exit=' + IntToStr(ExitCode));
    Check('publish records install path for metadata resolution', Harness.LastPath = '/tmp/install-root/demo', Harness.LastPath);
  finally
    Harness.Free;
  end;
end;

procedure TestPublishPackageDelegatesArchiveCreation;
var
  Harness: TPackageFacadeHarness;
  Outp, Errp: TStringOutput;
  ExitCode: Integer;
  OK: Boolean;
begin
  Harness := TPackageFacadeHarness.Create;
  Harness.IsInstalledResult := True;
  Harness.InstallPathValue := '/tmp/install-root/demo';
  Harness.ResolvePublishResult := True;
  Harness.PublishVersion := '2.0.0';
  Harness.PublishSourcePath := '/tmp/install-root/demo/src';
  Harness.CreateArchiveResult := True;
  Harness.CreateArchiveExitCode := EXIT_OK;
  Harness.CreateArchivePath := '/tmp/install-root/publish/demo-2.0.0.tar.gz';
  Outp := TStringOutput.Create;
  Errp := TStringOutput.Create;
  try
    OK := ExecutePackagePublishCore('demo', '1.0.0', '/tmp/install-root', Outp, Errp,
      @Harness.IsInstalled, @Harness.GetInstallPath, @Harness.ResolvePublishMetadata,
      @Harness.HandleMetadataFailure, @Harness.CreateArchive, ExitCode);
    Check('publish succeeds when archive creation succeeds', OK, 'unexpected failure');
    Check('publish keeps archive exit code', ExitCode = EXIT_OK, 'exit=' + IntToStr(ExitCode));
    Check('publish passes package name to archive creator', Harness.LastArchivePackageName = 'demo', Harness.LastArchivePackageName);
    Check('publish passes version to archive creator', Harness.LastArchiveVersion = '2.0.0', Harness.LastArchiveVersion);
    Check('publish passes source path to archive creator', Harness.LastArchiveSourcePath = '/tmp/install-root/demo/src', Harness.LastArchiveSourcePath);
    Check('publish passes install root to archive creator', Harness.LastInstallRoot = '/tmp/install-root', Harness.LastInstallRoot);
  finally
    Harness.Free;
  end;
end;

begin
  TestInstallFromLocalFailsWhenPathMissing;
  TestInstallFromLocalResolvesMetadataNameAndReportsSuccess;
  TestCreatePackageRejectsInvalidName;
  TestCreatePackageWritesCreatedMetadataAndNextSteps;
  TestPublishPackageFailsWhenNotInstalled;
  TestPublishPackageUsesMetadataFailureHandler;
  TestPublishPackageDelegatesArchiveCreation;

  WriteLn;
  WriteLn('Passed: ', PassCount);
  WriteLn('Failed: ', FailCount);

  if FailCount > 0 then
    Halt(1);
end.
