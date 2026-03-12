program test_package_verify;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.output.intf, fpdev.i18n, fpdev.i18n.strings,
  fpdev.package.verification, fpdev.hash, fpdev.utils.fs;

var
  Passed, Failed: Integer;
  TempRoot: string;
  TempRootSeq: Integer = 0;

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
    function Text: string;
    function Contains(const S: string): Boolean;
  end;

  TVerifyProbe = class
  public
    InstalledResult: Boolean;
    InstallPath: string;
    LastPackageName: string;
    function IsInstalled(const APackageName: string): Boolean;
    function GetInstallPath(const APackageName: string): string;
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

function TStringOutput.Text: string;
begin
  Result := FBuffer.Text;
end;

function TStringOutput.Contains(const S: string): Boolean;
begin
  Result := Pos(S, FBuffer.Text) > 0;
end;

function TVerifyProbe.IsInstalled(const APackageName: string): Boolean;
begin
  LastPackageName := APackageName;
  Result := InstalledResult;
end;

function TVerifyProbe.GetInstallPath(const APackageName: string): string;
begin
  LastPackageName := APackageName;
  Result := InstallPath;
end;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('PASS: ', AMsg);
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL: ', AMsg);
  end;
end;

procedure WriteFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

function BuildTempRoot: string;
begin
  Inc(TempRootSeq);
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fpdev_test_pkg_verify-' + IntToStr(GetTickCount64) + '-' + IntToStr(TempRootSeq) + PathDelim;
end;

function MakeTempPkgDir(const AName: string): string;
begin
  Result := TempRoot + AName + PathDelim;
  ForceDirectories(Result);
end;

procedure TestTempRootUsesSystemTempAndUniqueSuffix;
var
  OtherTempRoot: string;
begin
  WriteLn('-- TestTempRootUsesSystemTempAndUniqueSuffix --');
  Check(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(TempRoot)) = 1,
    'Temp root lives under system temp'
  );

  OtherTempRoot := BuildTempRoot;
  Check(
    ExpandFileName(TempRoot) <> ExpandFileName(OtherTempRoot),
    'Temp root is unique per run'
  );
end;

// ---- VerifyInstalledPackageCore tests ----

procedure TestVerify_ValidPackage;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_ValidPackage --');
  Dir := MakeTempPkgDir('valid_pkg');
  WriteFile(Dir + 'package.json',
    '{"name":"mylib","version":"1.0.0","files":["src/main.pas"]}');
  ForceDirectories(Dir + 'src');
  WriteFile(Dir + 'src' + PathDelim + 'main.pas', 'unit main; end.');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'Valid package status');
  Check(R.PackageName = 'mylib', 'Package name extracted');
  Check(R.Version = '1.0.0', 'Version extracted');
  Check(Length(R.MissingFiles) = 0, 'No missing files');
end;

procedure TestVerify_NoPackageJson;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NoPackageJson --');
  Dir := MakeTempPkgDir('no_json');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing package.json = MetadataError');
end;

procedure TestVerify_InvalidJson;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_InvalidJson --');
  Dir := MakeTempPkgDir('invalid_json');
  WriteFile(Dir + 'package.json', 'not valid json {{{');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Invalid JSON = MetadataError');
end;

procedure TestVerify_MissingName;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingName --');
  Dir := MakeTempPkgDir('no_name');
  WriteFile(Dir + 'package.json', '{"version":"1.0.0"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing name = MetadataError');
end;

procedure TestVerify_MissingVersion;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingVersion --');
  Dir := MakeTempPkgDir('no_ver');
  WriteFile(Dir + 'package.json', '{"name":"mylib"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'Missing version = MetadataError');
end;

procedure TestVerify_MissingFiles;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_MissingFiles --');
  Dir := MakeTempPkgDir('missing_files');
  WriteFile(Dir + 'package.json',
    '{"name":"mylib","version":"1.0.0","files":["src/a.pas","src/b.pas"]}');
  // Only create a.pas, not b.pas
  ForceDirectories(Dir + 'src');
  WriteFile(Dir + 'src' + PathDelim + 'a.pas', 'unit a; end.');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMissingFiles, 'Missing files status');
  Check(Length(R.MissingFiles) = 1, 'One missing file');
  Check(R.MissingFiles[0] = 'src/b.pas', 'Missing file is src/b.pas');
end;

procedure TestVerify_NoFilesArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NoFilesArray --');
  Dir := MakeTempPkgDir('no_files_array');
  WriteFile(Dir + 'package.json', '{"name":"mylib","version":"1.0.0"}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'No files array = valid (nothing to check)');
end;

procedure TestVerify_EmptyFilesArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_EmptyFilesArray --');
  Dir := MakeTempPkgDir('empty_files');
  WriteFile(Dir + 'package.json', '{"name":"mylib","version":"1.0.0","files":[]}');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsValid, 'Empty files array = valid');
end;

procedure TestVerify_JsonArray;
var
  Dir: string;
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_JsonArray --');
  Dir := MakeTempPkgDir('json_array');
  WriteFile(Dir + 'package.json', '[1,2,3]');

  R := VerifyInstalledPackageCore(Dir);
  Check(R.Status = pvsMetadataError, 'JSON array (not object) = MetadataError');
end;

procedure TestVerify_NonexistentDir;
var
  R: TPackageVerifyResult;
begin
  WriteLn('-- TestVerify_NonexistentDir --');
  R := VerifyInstalledPackageCore(TempRoot + 'nonexistent_dir_xyz');
  Check(R.Status = pvsMetadataError, 'Nonexistent dir = MetadataError');
end;

// ---- VerifyPackageChecksumCore tests ----

procedure TestChecksum_Valid;
var
  FilePath, Hash: string;
begin
  WriteLn('-- TestChecksum_Valid --');
  FilePath := TempRoot + 'checksum_test.txt';
  WriteFile(FilePath, 'hello world');
  Hash := SHA256FileHex(FilePath);
  Check(VerifyPackageChecksumCore(FilePath, Hash), 'Valid checksum matches');
end;

procedure TestChecksum_Invalid;
var
  FilePath: string;
begin
  WriteLn('-- TestChecksum_Invalid --');
  FilePath := TempRoot + 'checksum_test2.txt';
  WriteFile(FilePath, 'hello world');
  Check(not VerifyPackageChecksumCore(FilePath, 'badhash'), 'Invalid checksum does not match');
end;

procedure TestChecksum_CaseInsensitive;
var
  FilePath, Hash: string;
begin
  WriteLn('-- TestChecksum_CaseInsensitive --');
  FilePath := TempRoot + 'checksum_case.txt';
  WriteFile(FilePath, 'test data');
  Hash := SHA256FileHex(FilePath);
  Check(VerifyPackageChecksumCore(FilePath, UpperCase(Hash)), 'Upper case hash matches');
  Check(VerifyPackageChecksumCore(FilePath, LowerCase(Hash)), 'Lower case hash matches');
end;

procedure TestChecksum_NonexistentFile;
begin
  WriteLn('-- TestChecksum_NonexistentFile --');
  Check(not VerifyPackageChecksumCore(TempRoot + 'no_such_file.bin', 'anyhash'),
    'Nonexistent file returns false');
end;

procedure TestLoadVerifyMetadata_ValidObject;
var
  Dir: string;
  MetaPath: string;
  Metadata: TPackageVerifyMetadata;
  Status: TPackageVerifyMetadataLoadStatus;
  ErrorText: string;
begin
  WriteLn('-- TestLoadVerifyMetadata_ValidObject --');
  Dir := MakeTempPkgDir('verify_meta_valid');
  MetaPath := Dir + 'package.json';
  WriteFile(
    MetaPath,
    '{"name":"verify-demo","version":"2.3.4","sha256":"abc123","source_path":"/tmp/source-demo"}'
  );

  Check(
    TryLoadPackageVerifyMetadataCore(MetaPath, Metadata, Status, ErrorText),
    'Verify metadata helper loads valid metadata'
  );
  Check(Status = pvmlsOk, 'Verify metadata helper reports ok status');
  Check(Metadata.Name = 'verify-demo', 'Verify metadata helper extracts name');
  Check(Metadata.Version = '2.3.4', 'Verify metadata helper extracts version');
  Check(Metadata.ExpectedSha256 = 'abc123', 'Verify metadata helper extracts checksum');
  Check(Metadata.SourcePath = '/tmp/source-demo', 'Verify metadata helper extracts source path');
  Check(ErrorText = '', 'Verify metadata helper clears error text on success');
end;

procedure TestLoadVerifyMetadata_MissingName;
var
  Dir: string;
  MetaPath: string;
  Metadata: TPackageVerifyMetadata;
  Status: TPackageVerifyMetadataLoadStatus;
  ErrorText: string;
begin
  WriteLn('-- TestLoadVerifyMetadata_MissingName --');
  Dir := MakeTempPkgDir('verify_meta_missing_name');
  MetaPath := Dir + 'package.json';
  WriteFile(MetaPath, '{"version":"9.9.9"}');

  Check(
    not TryLoadPackageVerifyMetadataCore(MetaPath, Metadata, Status, ErrorText),
    'Verify metadata helper rejects metadata without name'
  );
  Check(Status = pvmlsMissingName, 'Verify metadata helper reports missing-name status');
end;

procedure TestVerifyMetadataChecksum_MismatchReturnsActualHash;
var
  FilePath: string;
  ActualHash: string;
  Metadata: TPackageVerifyMetadata;
  Status: TPackageVerifyChecksumStatus;
begin
  WriteLn('-- TestVerifyMetadataChecksum_MismatchReturnsActualHash --');
  FilePath := TempRoot + 'verify_meta_checksum.txt';
  WriteFile(FilePath, 'checksum source content');

  Metadata.Name := 'checksum-demo';
  Metadata.Version := '1.0.0';
  Metadata.ExpectedSha256 := 'deadbeef';
  Metadata.SourcePath := FilePath;

  Status := VerifyPackageMetadataChecksumCore(Metadata, ActualHash);
  Check(Status = pvcsMismatch, 'Verify metadata checksum helper reports mismatch');
  Check(ActualHash = SHA256FileHex(FilePath), 'Verify metadata checksum helper returns actual hash');
end;

procedure TestExecutePackageVerifyCore_RejectsMissingInstall;
var
  Probe: TVerifyProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
begin
  WriteLn('-- TestExecutePackageVerifyCore_RejectsMissingInstall --');
  Probe := TVerifyProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    Probe.InstalledResult := False;
    Check(
      not ExecutePackageVerifyCore('alpha', @Probe.IsInstalled, @Probe.GetInstallPath, OutRef, ErrRef),
      'Verify flow rejects non-installed package'
    );
    Check(
      ErrBuf.Contains(_Fmt(CMD_PKG_NOT_INSTALLED, ['alpha'])),
      'Verify flow reports not-installed package'
    );
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageVerifyCore_SuccessWithVersionWarningAndChecksum;
var
  Probe: TVerifyProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  InstallDir: string;
  SourceFile: string;
  Hash: string;
begin
  WriteLn('-- TestExecutePackageVerifyCore_SuccessWithVersionWarningAndChecksum --');
  Probe := TVerifyProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    InstallDir := MakeTempPkgDir('verify_flow_success');
    SourceFile := InstallDir + 'source.tar.gz';
    WriteFile(SourceFile, 'archive content');
    Hash := SHA256FileHex(SourceFile);
    WriteFile(
      InstallDir + 'package.json',
      '{"name":"alpha","version":"","sha256":"' + Hash + '","source_path":"' + SourceFile + '"}'
    );

    Probe.InstalledResult := True;
    Probe.InstallPath := ExcludeTrailingPathDelimiter(InstallDir);
    Check(
      ExecutePackageVerifyCore('alpha', @Probe.IsInstalled, @Probe.GetInstallPath, OutRef, ErrRef),
      'Verify flow succeeds for installed package with matching checksum'
    );
    Check(OutBuf.Contains(_(MSG_PKG_VERSION_MISSING)), 'Verify flow emits version missing warning');
    Check(OutBuf.Contains(_(MSG_PKG_CHECKSUM_OK)), 'Verify flow emits checksum ok');
    Check(OutBuf.Contains(_Fmt(MSG_PKG_VERIFY_SUCCESS, ['alpha'])), 'Verify flow emits success message');
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

procedure TestExecutePackageVerifyCore_ReportsChecksumMismatch;
var
  Probe: TVerifyProbe;
  OutBuf, ErrBuf: TStringOutput;
  OutRef, ErrRef: IOutput;
  InstallDir: string;
  SourceFile: string;
  ActualHash: string;
begin
  WriteLn('-- TestExecutePackageVerifyCore_ReportsChecksumMismatch --');
  Probe := TVerifyProbe.Create;
  OutBuf := TStringOutput.Create;
  ErrBuf := TStringOutput.Create;
  OutRef := OutBuf as IOutput;
  ErrRef := ErrBuf as IOutput;
  try
    InstallDir := MakeTempPkgDir('verify_flow_mismatch');
    SourceFile := InstallDir + 'source.tar.gz';
    WriteFile(SourceFile, 'archive content');
    ActualHash := SHA256FileHex(SourceFile);
    WriteFile(
      InstallDir + 'package.json',
      '{"name":"alpha","version":"1.0.0","sha256":"deadbeef","source_path":"' + SourceFile + '"}'
    );

    Probe.InstalledResult := True;
    Probe.InstallPath := ExcludeTrailingPathDelimiter(InstallDir);
    Check(
      not ExecutePackageVerifyCore('alpha', @Probe.IsInstalled, @Probe.GetInstallPath, OutRef, ErrRef),
      'Verify flow fails on checksum mismatch'
    );
    Check(ErrBuf.Contains(_(CMD_PKG_CHECKSUM_MISMATCH)), 'Verify flow emits checksum mismatch');
    Check(ErrBuf.Contains(_Fmt(MSG_PKG_CHECKSUM_EXPECTED, ['deadbeef'])),
      'Verify flow emits expected checksum line');
    Check(ErrBuf.Contains(_Fmt(MSG_PKG_CHECKSUM_ACTUAL, [ActualHash])),
      'Verify flow emits actual checksum line');
  finally
    ErrRef := nil;
    OutRef := nil;
    ErrBuf := nil;
    OutBuf := nil;
    Probe.Free;
  end;
end;

// ---- Cleanup ----
procedure Cleanup;
begin
  if (TempRoot <> '') and DirectoryExists(TempRoot) then
    DeleteDirRecursive(TempRoot);
end;

begin
  Passed := 0;
  Failed := 0;
  TempRoot := BuildTempRoot;
  ForceDirectories(TempRoot);

  WriteLn('');
  WriteLn('=== fpdev.package.verification Test Suite ===');
  WriteLn('');

  TestTempRootUsesSystemTempAndUniqueSuffix;
  TestVerify_ValidPackage;
  TestVerify_NoPackageJson;
  TestVerify_InvalidJson;
  TestVerify_MissingName;
  TestVerify_MissingVersion;
  TestVerify_MissingFiles;
  TestVerify_NoFilesArray;
  TestVerify_EmptyFilesArray;
  TestVerify_JsonArray;
  TestVerify_NonexistentDir;
  TestChecksum_Valid;
  TestChecksum_Invalid;
  TestChecksum_CaseInsensitive;
  TestChecksum_NonexistentFile;
  TestLoadVerifyMetadata_ValidObject;
  TestLoadVerifyMetadata_MissingName;
  TestVerifyMetadataChecksum_MismatchReturnsActualHash;
  TestExecutePackageVerifyCore_RejectsMissingInstall;
  TestExecutePackageVerifyCore_SuccessWithVersionWarningAndChecksum;
  TestExecutePackageVerifyCore_ReportsChecksumMismatch;

  Cleanup;
  Check(not DirectoryExists(TempRoot), 'Temp root removed');

  WriteLn('');
  WriteLn('=== Results ===');
  WriteLn('Passed: ', Passed);
  WriteLn('Failed: ', Failed);
  WriteLn('Total:  ', Passed + Failed);

  if Failed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end.
