program test_package_sourceinstall;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.package.types,
  fpdev.utils.fs,
  fpdev.package.sourceinstall, test_temp_paths;

type
  TStubSourceInstall = class
  public
    InfoToReturn: TPackageInfo;
    BuildResult: Boolean;
    WriteResult: Boolean;
    BuildCalls: Integer;
    WriteCalls: Integer;
    LastRequestedPackage: string;
    LastBuildPath: string;
    LastWriteInstallPath: string;
    LastWrittenInfo: TPackageInfo;
    function GetPackageInfo(const APackageName: string): TPackageInfo;
    function BuildPackage(const ASourcePath: string): Boolean;
    function WritePackageMetadata(const AInstallPath: string; const AInfo: TPackageInfo): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

function TStubSourceInstall.GetPackageInfo(const APackageName: string): TPackageInfo;
begin
  LastRequestedPackage := APackageName;
  Result := InfoToReturn;
end;

function TStubSourceInstall.BuildPackage(const ASourcePath: string): Boolean;
begin
  Inc(BuildCalls);
  LastBuildPath := ASourcePath;
  Result := BuildResult;
end;

function TStubSourceInstall.WritePackageMetadata(const AInstallPath: string; const AInfo: TPackageInfo): Boolean;
begin
  Inc(WriteCalls);
  LastWriteInstallPath := AInstallPath;
  LastWrittenInfo := AInfo;
  Result := WriteResult;
end;

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
begin
  Result := CreateUniqueTempDir('pkginst_' + ASuffix);
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

procedure TestInstallPreparedPackageSourceCoreOverlaysMetadataAndWritesFinalInfo;
var
  Stub: TStubSourceInstall;
  TempDir: string;
  InstallDir: string;
begin
  TempDir := CreateTempDir('sourceinstall_success');
  Stub := TStubSourceInstall.Create;
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'pkg';
    ForceDirectories(InstallDir);
    WriteTextFile(
      IncludeTrailingPathDelimiter(InstallDir) + 'package.json',
      '{' + LineEnding +
      '  "version": "2.0.1",' + LineEnding +
      '  "description": "overlay description",' + LineEnding +
      '  "author": "Overlay Author"' + LineEnding +
      '}'
    );

    Initialize(Stub.InfoToReturn);
    Stub.InfoToReturn.SourcePath := '/tmp/original-source';
    Stub.BuildResult := True;
    Stub.WriteResult := True;

    AssertTrue(
      InstallPreparedPackageSourceCore(
        'alpha',
        InstallDir,
        @Stub.GetPackageInfo,
        @Stub.BuildPackage,
        @Stub.WritePackageMetadata
      ),
      'source install finalize succeeds when build and metadata write succeed'
    );
    AssertEquals('alpha', Stub.LastRequestedPackage, 'info provider receives package name');
    AssertTrue(Stub.BuildCalls = 1, 'build is called once');
    AssertEquals(InstallDir, Stub.LastBuildPath, 'build uses install dir');
    AssertTrue(Stub.WriteCalls = 1, 'metadata write is called once');
    AssertEquals(InstallDir, Stub.LastWriteInstallPath, 'metadata write uses install dir');
    AssertEquals('alpha', Stub.LastWrittenInfo.Name, 'empty package name falls back to requested package name');
    AssertEquals('2.0.1', Stub.LastWrittenInfo.Version, 'metadata overlay updates version before write');
    AssertEquals('overlay description', Stub.LastWrittenInfo.Description, 'metadata overlay updates description before write');
    AssertEquals('Overlay Author', Stub.LastWrittenInfo.Author, 'metadata overlay updates author before write');
    AssertEquals('', Stub.LastWrittenInfo.SourcePath, 'written metadata clears source path for self-contained install');
  finally
    Stub.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestInstallPreparedPackageSourceCoreStopsOnBuildFailure;
var
  Stub: TStubSourceInstall;
  TempDir: string;
  InstallDir: string;
begin
  TempDir := CreateTempDir('sourceinstall_build_fail');
  Stub := TStubSourceInstall.Create;
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'pkg';
    ForceDirectories(InstallDir);
    Stub.BuildResult := False;
    Stub.WriteResult := True;

    AssertTrue(
      not InstallPreparedPackageSourceCore(
        'beta',
        InstallDir,
        @Stub.GetPackageInfo,
        @Stub.BuildPackage,
        @Stub.WritePackageMetadata
      ),
      'source install finalize fails when build fails'
    );
    AssertTrue(Stub.BuildCalls = 1, 'build failure still records one build call');
    AssertTrue(Stub.WriteCalls = 0, 'metadata write is skipped after build failure');
  finally
    Stub.Free;
    CleanupTempDir(TempDir);
  end;
end;

procedure TestInstallPreparedPackageSourceCoreStopsOnMetadataWriteFailure;
var
  Stub: TStubSourceInstall;
  TempDir: string;
  InstallDir: string;
begin
  TempDir := CreateTempDir('sourceinstall_write_fail');
  Stub := TStubSourceInstall.Create;
  try
    InstallDir := IncludeTrailingPathDelimiter(TempDir) + 'pkg';
    ForceDirectories(InstallDir);
    Stub.BuildResult := True;
    Stub.WriteResult := False;

    AssertTrue(
      not InstallPreparedPackageSourceCore(
        'gamma',
        InstallDir,
        @Stub.GetPackageInfo,
        @Stub.BuildPackage,
        @Stub.WritePackageMetadata
      ),
      'source install finalize fails when metadata write fails'
    );
    AssertTrue(Stub.BuildCalls = 1, 'build succeeds once before metadata write failure');
    AssertTrue(Stub.WriteCalls = 1, 'metadata write failure still records one write call');
  finally
    Stub.Free;
    CleanupTempDir(TempDir);
  end;
end;

begin
  TestInstallPreparedPackageSourceCoreOverlaysMetadataAndWritesFinalInfo;
  TestInstallPreparedPackageSourceCoreStopsOnBuildFailure;
  TestInstallPreparedPackageSourceCoreStopsOnMetadataWriteFailure;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
