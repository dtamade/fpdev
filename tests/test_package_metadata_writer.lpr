program test_package_metadata_writer;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.types,
  fpdev.utils.fs,
  fpdev.package.metadataio,
  fpdev.package.publishflow,
  fpdev.exitcodes,
  fpdev.output.intf,
  test_cli_helpers;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual,
    AMessage + ' (expected: ' + AExpected + ', got: ' + AActual + ')');
end;

function CreateTempDir(const ASuffix: string): string;
var
  TempPath: string;
begin
  TempPath := GetTempFileName(GetTempDir(False), 'pkg');
  if FileExists(TempPath) then
    DeleteFile(TempPath);
  Result := TempPath + '_' + ASuffix;
  ForceDirectories(Result);
end;

procedure WriteTextFile(const APath, AContent: string);
var
  Content: TStringList;
begin
  Content := TStringList.Create;
  try
    Content.Text := AContent;
    Content.SaveToFile(APath);
  finally
    Content.Free;
  end;
end;

procedure TestWritePackageMetadataCorePersistsExpectedFields;
var
  TempDir: string;
  InstallDir: string;
  MetaPath: string;
  Info: TPackageInfo;
  JsonText: TStringList;
  JsonData: TJSONData;
  JsonObj: TJSONObject;
begin
  TempDir := CreateTempDir('metadata_write');
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'installed_pkg';
    ForceDirectories(InstallDir);
    MetaPath := IncludeTrailingPathDelimiter(InstallDir) + 'package.json';

    Initialize(Info);
    Info.Name := 'writer-demo';
    Info.Version := '1.2.3';
    Info.Description := 'metadata write test';
    Info.Author := 'Writer Demo <writer@example.com>';
    Info.Homepage := 'https://example.com/pkg';
    Info.License := 'MIT';
    Info.Repository := 'https://example.com/repo';
    Info.SourcePath := '/tmp/source-writer-demo';
    Info.Sha256 := 'abc123';
    SetLength(Info.URLs, 2);
    Info.URLs[0] := 'https://example.com/pkg.tar.gz';
    Info.URLs[1] := 'https://mirror.example.com/pkg.tar.gz';

    AssertTrue(
      WritePackageMetadataCore(InstallDir, Info, 'fpc', '/tmp/build.log'),
      'metadata write succeeds'
    );
    AssertTrue(FileExists(MetaPath), 'package.json is created');

    JsonText := TStringList.Create;
    try
      JsonText.LoadFromFile(MetaPath);
      JsonData := GetJSON(JsonText.Text);
    finally
      JsonText.Free;
    end;
    try
      AssertTrue(JsonData.JSONType = jtObject, 'written metadata is a JSON object');
      JsonObj := TJSONObject(JsonData);
      AssertEquals('writer-demo', JsonObj.Get('name', ''), 'name is persisted');
      AssertEquals('1.2.3', JsonObj.Get('version', ''), 'version is persisted');
      AssertEquals('Writer Demo <writer@example.com>', JsonObj.Get('author', ''), 'author is persisted');
      AssertEquals(InstallDir, JsonObj.Get('install_path', ''), 'install path is persisted');
      AssertEquals('/tmp/source-writer-demo', JsonObj.Get('source_path', ''), 'source path is persisted');
      AssertEquals('fpc', JsonObj.Get('build_tool', ''), 'build tool is persisted');
      AssertEquals('/tmp/build.log', JsonObj.Get('build_log', ''), 'build log is persisted');
      AssertTrue(JsonObj.Get('install_date', '') <> '', 'install date is persisted');
      AssertTrue(Assigned(JsonObj.Arrays['url']) and (JsonObj.Arrays['url'].Count = 2), 'url array is persisted');
    finally
      JsonData.Free;
    end;
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestApplyPackageMetadataToInfoCoreOverlaysKnownFields;
var
  TempDir: string;
  MetaPath: string;
  Info: TPackageInfo;
begin
  TempDir := CreateTempDir('metadata_overlay');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempDir) + 'package.json';
    WriteTextFile(
      MetaPath,
      '{' + LineEnding +
      '  "name": "pkg_overlay",' + LineEnding +
      '  "version": "2.0.1",' + LineEnding +
      '  "description": "overlay description",' + LineEnding +
      '  "author": "Overlay Author",' + LineEnding +
      '  "license": "Apache-2.0",' + LineEnding +
      '  "homepage": "https://example.com/overlay",' + LineEnding +
      '  "repository": "https://example.com/repo.git"' + LineEnding +
      '}'
    );

    Initialize(Info);
    Info.Name := 'fallback_name';
    Info.Version := '1.0.0';
    Info.Description := 'fallback description';

    AssertTrue(
      ApplyPackageMetadataToInfoCore(MetaPath, Info),
      'package metadata overlay succeeds for valid metadata'
    );
    AssertEquals('pkg_overlay', Info.Name, 'metadata overlay updates name');
    AssertEquals('2.0.1', Info.Version, 'metadata overlay updates version');
    AssertEquals('overlay description', Info.Description, 'metadata overlay updates description');
    AssertEquals('Overlay Author', Info.Author, 'metadata overlay updates author');
    AssertEquals('Apache-2.0', Info.License, 'metadata overlay updates license');
    AssertEquals('https://example.com/overlay', Info.Homepage, 'metadata overlay updates homepage');
    AssertEquals('https://example.com/repo.git', Info.Repository, 'metadata overlay updates repository');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestApplyPackageMetadataToInfoCoreIgnoresInvalidMetadata;
var
  TempDir: string;
  MetaPath: string;
  Info: TPackageInfo;
begin
  TempDir := CreateTempDir('metadata_overlay_invalid');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempDir) + 'package.json';
    WriteTextFile(MetaPath, '{ invalid json }');

    Initialize(Info);
    Info.Name := 'fallback_name';
    Info.Version := '1.0.0';
    Info.Description := 'fallback description';

    AssertTrue(
      not ApplyPackageMetadataToInfoCore(MetaPath, Info),
      'package metadata overlay reports invalid metadata'
    );
    AssertEquals('fallback_name', Info.Name, 'invalid metadata keeps fallback name');
    AssertEquals('1.0.0', Info.Version, 'invalid metadata keeps fallback version');
    AssertEquals('fallback description', Info.Description, 'invalid metadata keeps fallback description');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestResolvePackageNameFromMetadataCoreUsesMetadataName;
var
  TempDir: string;
  MetaPath: string;
  PackageName: string;
begin
  TempDir := CreateTempDir('metadata_name');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempDir) + 'package.json';
    WriteTextFile(
      MetaPath,
      '{' + LineEnding +
      '  "name": "pkg_from_meta"' + LineEnding +
      '}'
    );

    PackageName := ResolvePackageNameFromMetadataCore(MetaPath, 'dir_name');
    AssertEquals('pkg_from_meta', PackageName,
      'metadata name overrides directory fallback');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestResolvePackageNameFromMetadataCoreFallsBackOnInvalidMetadata;
var
  TempDir: string;
  MetaPath: string;
  PackageName: string;
begin
  TempDir := CreateTempDir('metadata_invalid_name');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempDir) + 'package.json';
    WriteTextFile(MetaPath, '{ invalid json }');

    PackageName := ResolvePackageNameFromMetadataCore(MetaPath, 'dir_name');
    AssertEquals('dir_name', PackageName,
      'invalid metadata keeps directory-name fallback');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestTryResolvePublishMetadataCoreResolvesRelativeSourcePath;
var
  TempDir: string;
  InstallDir: string;
  RelativeSourceDir: string;
  Version: string;
  ArchiveSourcePath: string;
  SourcePathFromMeta: string;
  Status: TPackageMetadataLoadStatus;
  ErrorText: string;
begin
  TempDir := CreateTempDir('metadata_publish_relative');
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'pkg';
    RelativeSourceDir := IncludeTrailingPathDelimiter(InstallDir) + 'src_rel';
    ForceDirectories(RelativeSourceDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(RelativeSourceDir) + 'demo.pas',
      'unit demo;' + LineEnding + 'interface' + LineEnding + 'implementation' + LineEnding + 'end.'
    );
    WriteTextFile(
      IncludeTrailingPathDelimiter(InstallDir) + 'package.json',
      '{' + LineEnding +
      '  "version": "2.4.6",' + LineEnding +
      '  "source_path": "src_rel"' + LineEnding +
      '}'
    );

    AssertTrue(
      TryResolvePublishMetadataCore(
        InstallDir,
        '1.0.0',
        Version,
        ArchiveSourcePath,
        SourcePathFromMeta,
        Status,
        ErrorText
      ),
      'publish metadata resolution succeeds for relative source path'
    );
    AssertTrue(Status = pmlsOk, 'publish metadata status is ok');
    AssertEquals('2.4.6', Version, 'publish metadata version is loaded');
    AssertEquals('src_rel', SourcePathFromMeta, 'original source_path is preserved');
    AssertEquals(ExpandFileName(RelativeSourceDir), ArchiveSourcePath,
      'relative source_path is resolved against install dir');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

procedure TestTryResolvePublishMetadataCoreReportsMissingSourcePath;
var
  TempDir: string;
  InstallDir: string;
  Version: string;
  ArchiveSourcePath: string;
  SourcePathFromMeta: string;
  Status: TPackageMetadataLoadStatus;
  ErrorText: string;
begin
  TempDir := CreateTempDir('metadata_publish_missing_source');
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'pkg';
    ForceDirectories(InstallDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(InstallDir) + 'package.json',
      '{' + LineEnding +
      '  "version": "2.4.7",' + LineEnding +
      '  "source_path": "missing_src"' + LineEnding +
      '}'
    );

    AssertTrue(
      not TryResolvePublishMetadataCore(
        InstallDir,
        '1.0.0',
        Version,
        ArchiveSourcePath,
        SourcePathFromMeta,
        Status,
        ErrorText
      ),
      'publish metadata resolution fails when source_path is missing'
    );
    AssertTrue(Status = pmlsSourcePathMissing,
      'missing source path returns source-path-missing status');
    AssertEquals('missing_src', ErrorText,
      'missing source path returns original metadata path');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;


procedure TestBuildPublishArchivePathCoreUsesPublishDir;
var
  ArchiveName: string;
  ArchivePath: string;
begin
  BuildPublishArchivePathCore(
    '/tmp/fpdev_install_root',
    'alpha',
    '1.2.3',
    ArchiveName,
    ArchivePath
  );

  AssertEquals('alpha-1.2.3.tar.gz', ArchiveName,
    'publish archive name uses package name and metadata version');
  AssertEquals('/tmp/fpdev_install_root' + PathDelim + 'publish' + PathDelim +
    'alpha-1.2.3.tar.gz', ArchivePath,
    'publish archive path is rooted under install_root/publish');
end;

procedure TestHandlePublishMetadataFailureCoreMapsMissingSource;
var
  StdErr: TStringOutput;
  ErrOut: IOutput;
  ExitCode: Integer;
begin
  StdErr := TStringOutput.Create;
  ErrOut := StdErr as IOutput;
  ExitCode := HandlePublishMetadataFailureCore(
    pmlsSourcePathMissing,
    'missing_src',
    ErrOut
  );

  AssertTrue(ExitCode = EXIT_NOT_FOUND,
    'publish metadata missing source maps to not-found exit code');
  AssertTrue(
    Pos('missing_src', LowerCase(StdErr.GetBuffer)) > 0,
    'publish metadata failure keeps source path in stderr output'
  );
end;

procedure TestCreatePublishArchiveCoreCreatesArchive;
var
  TempDir: string;
  SourceDir: string;
  ArchivePath: string;
  ExitCode: Integer;
  StdOut: TStringOutput;
  StdErr: TStringOutput;
  OutIntf: IOutput;
  ErrIntf: IOutput;
begin
  TempDir := CreateTempDir('publish_archive_core');
  try
    SourceDir := IncludeTrailingPathDelimiter(TempDir) + 'source';
    ForceDirectories(SourceDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(SourceDir) + 'demo.pas',
      'unit demo;' + LineEnding + 'interface' + LineEnding +
      'implementation' + LineEnding + 'end.'
    );

    StdOut := TStringOutput.Create;
    StdErr := TStringOutput.Create;
    OutIntf := StdOut as IOutput;
    ErrIntf := StdErr as IOutput;

    AssertTrue(
      CreatePublishArchiveCore(
        'alpha',
        '3.4.5',
        SourceDir,
        TempDir,
        OutIntf,
        ErrIntf,
        ArchivePath,
        ExitCode
      ),
      'publish archive helper succeeds for valid source tree'
    );
    AssertTrue(ExitCode = EXIT_OK, 'publish archive helper sets ok exit code');
    AssertTrue(FileExists(ArchivePath), 'publish archive helper creates tarball');
    AssertTrue(Pos('alpha-3.4.5.tar.gz', StdOut.GetBuffer) > 0,
      'publish archive helper reports created archive name');
    AssertTrue(Trim(StdErr.GetBuffer) = '',
      'publish archive helper keeps stderr empty on success');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;
procedure TestTryLoadPackageMetadataCoreReportsInvalidJson;
var
  TempDir: string;
  MetaPath: string;
  Metadata: TJSONObject;
  Status: TPackageMetadataLoadStatus;
  ErrorText: string;
begin
  TempDir := CreateTempDir('metadata_invalid_json');
  try
    MetaPath := IncludeTrailingPathDelimiter(TempDir) + 'package.json';
    WriteTextFile(MetaPath, '{"name":');

    AssertTrue(
      not TryLoadPackageMetadataCore(MetaPath, Metadata, Status, ErrorText),
      'invalid metadata json does not load'
    );
    AssertTrue(Status = pmlsInvalidJSON, 'invalid json status is reported');
    AssertTrue(ErrorText <> '', 'invalid json returns parse detail');
  finally
    DeleteDirRecursive(TempDir);
  end;
end;

begin
  TestWritePackageMetadataCorePersistsExpectedFields;
  TestApplyPackageMetadataToInfoCoreOverlaysKnownFields;
  TestApplyPackageMetadataToInfoCoreIgnoresInvalidMetadata;
  TestResolvePackageNameFromMetadataCoreUsesMetadataName;
  TestResolvePackageNameFromMetadataCoreFallsBackOnInvalidMetadata;
  TestTryResolvePublishMetadataCoreResolvesRelativeSourcePath;
  TestTryResolvePublishMetadataCoreReportsMissingSourcePath;
  TestBuildPublishArchivePathCoreUsesPublishDir;
  TestHandlePublishMetadataFailureCoreMapsMissingSource;
  TestCreatePublishArchiveCoreCreatesArchive;
  TestTryLoadPackageMetadataCoreReportsInvalidJson;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
