program test_package_sourceprep;

{$mode objfpc}{$H+}

uses
  SysUtils,
  fpdev.utils.fs,
  fpdev.package.sourceprep, test_temp_paths;

type
  TStubSourcePrep = class
  public
    DeleteCalls: Integer;
    CopyCalls: Integer;
    EnsureCalls: Integer;
    LastDeletePath: string;
    LastCopySource: string;
    LastCopyDest: string;
    LastEnsurePath: string;
    DeleteResult: Boolean;
    CopyResult: Boolean;
    EnsureResult: Boolean;
    function DeleteDir(const APath: string): Boolean;
    function CopyDir(const ASrc, ADest: string): Boolean;
    function EnsurePath(const APath: string): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GStub: TStubSourcePrep = nil;

function TStubSourcePrep.DeleteDir(const APath: string): Boolean;
begin
  Inc(DeleteCalls);
  LastDeletePath := APath;
  Result := DeleteResult;
end;

function TStubSourcePrep.CopyDir(const ASrc, ADest: string): Boolean;
begin
  Inc(CopyCalls);
  LastCopySource := ASrc;
  LastCopyDest := ADest;
  Result := CopyResult;
end;

function TStubSourcePrep.EnsurePath(const APath: string): Boolean;
begin
  Inc(EnsureCalls);
  LastEnsurePath := APath;
  Result := EnsureResult;
end;

function DeleteDirBridge(const APath: string): Boolean;
begin
  if GStub = nil then
    Exit(False);
  Result := GStub.DeleteDir(APath);
end;

function CopyDirBridge(const ASrc, ADest: string): Boolean;
begin
  if GStub = nil then
    Exit(False);
  Result := GStub.CopyDir(ASrc, ADest);
end;

function EnsureDirBridge(const APath: string): Boolean;
begin
  if GStub = nil then
    Exit(False);
  Result := GStub.EnsurePath(APath);
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
  Result := CreateUniqueTempDir('pkgsrc_' + ASuffix);
end;

procedure TestPreparePackageInstallSourceTreeCoreReplacesExistingInstallDir;
var
  Stub: TStubSourcePrep;
  TempRoot: string;
  SourceDir: string;
  InstallDir: string;
begin
  TempRoot := CreateTempDir('replace');
  Stub := TStubSourcePrep.Create;
  try
    SourceDir := IncludeTrailingPathDelimiter(TempRoot) + 'src';
    InstallDir := IncludeTrailingPathDelimiter(TempRoot) + 'install';
    ForceDirectories(SourceDir);
    ForceDirectories(InstallDir);

    Stub.DeleteResult := True;
    Stub.CopyResult := True;
    Stub.EnsureResult := True;
    GStub := Stub;

    AssertTrue(
      PreparePackageInstallSourceTreeCore(
        SourceDir,
        InstallDir,
        @DeleteDirBridge,
        @CopyDirBridge,
        @EnsureDirBridge
      ),
      'source prep succeeds when replacing an existing install dir'
    );
    AssertTrue(Stub.DeleteCalls = 1, 'existing install dir is deleted once');
    AssertEquals(ExpandFileName(InstallDir), Stub.LastDeletePath, 'delete uses resolved install dir');
    AssertTrue(Stub.CopyCalls = 1, 'source tree is copied once');
    AssertEquals(ExpandFileName(SourceDir), Stub.LastCopySource, 'copy uses resolved source dir');
    AssertEquals(ExpandFileName(InstallDir), Stub.LastCopyDest, 'copy uses resolved install dir');
    AssertTrue(Stub.EnsureCalls = 0, 'ensure dir is not called for replacement copy');
  finally
    GStub := nil;
    Stub.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPreparePackageInstallSourceTreeCoreSkipsCopyForSameResolvedPath;
var
  Stub: TStubSourcePrep;
  TempRoot: string;
  SourceDir: string;
begin
  TempRoot := CreateTempDir('same_path');
  Stub := TStubSourcePrep.Create;
  try
    SourceDir := IncludeTrailingPathDelimiter(TempRoot) + 'package';
    ForceDirectories(SourceDir);

    Stub.DeleteResult := True;
    Stub.CopyResult := True;
    Stub.EnsureResult := True;
    GStub := Stub;

    AssertTrue(
      PreparePackageInstallSourceTreeCore(
        SourceDir,
        SourceDir + PathDelim,
        @DeleteDirBridge,
        @CopyDirBridge,
        @EnsureDirBridge
      ),
      'source prep succeeds when source and install resolve to the same path'
    );
    AssertTrue(Stub.DeleteCalls = 0, 'same path does not delete the install dir');
    AssertTrue(Stub.CopyCalls = 0, 'same path does not copy the source tree');
    AssertTrue(Stub.EnsureCalls = 0, 'same existing path does not ensure directory again');
  finally
    GStub := nil;
    Stub.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPreparePackageInstallSourceTreeCoreEnsuresMissingSamePathDir;
var
  Stub: TStubSourcePrep;
  TempRoot: string;
  SourceDir: string;
begin
  TempRoot := CreateTempDir('ensure_same_path');
  Stub := TStubSourcePrep.Create;
  try
    SourceDir := IncludeTrailingPathDelimiter(TempRoot) + 'package';

    Stub.DeleteResult := True;
    Stub.CopyResult := True;
    Stub.EnsureResult := True;
    GStub := Stub;

    AssertTrue(
      PreparePackageInstallSourceTreeCore(
        SourceDir,
        SourceDir,
        @DeleteDirBridge,
        @CopyDirBridge,
        @EnsureDirBridge
      ),
      'source prep succeeds by ensuring a missing same-path install dir'
    );
    AssertTrue(Stub.DeleteCalls = 0, 'missing same-path dir does not delete');
    AssertTrue(Stub.CopyCalls = 0, 'missing same-path dir does not copy');
    AssertTrue(Stub.EnsureCalls = 1, 'missing same-path dir is ensured once');
    AssertEquals(ExpandFileName(SourceDir), Stub.LastEnsurePath, 'ensure uses resolved install dir');
  finally
    GStub := nil;
    Stub.Free;
    CleanupTempDir(TempRoot);
  end;
end;

procedure TestPreparePackageInstallSourceTreeCoreStopsOnDeleteFailure;
var
  Stub: TStubSourcePrep;
  TempRoot: string;
  SourceDir: string;
  InstallDir: string;
begin
  TempRoot := CreateTempDir('delete_fail');
  Stub := TStubSourcePrep.Create;
  try
    SourceDir := IncludeTrailingPathDelimiter(TempRoot) + 'src';
    InstallDir := IncludeTrailingPathDelimiter(TempRoot) + 'install';
    ForceDirectories(SourceDir);
    ForceDirectories(InstallDir);

    Stub.DeleteResult := False;
    Stub.CopyResult := True;
    Stub.EnsureResult := True;
    GStub := Stub;

    AssertTrue(
      not PreparePackageInstallSourceTreeCore(
        SourceDir,
        InstallDir,
        @DeleteDirBridge,
        @CopyDirBridge,
        @EnsureDirBridge
      ),
      'source prep fails when deleting existing install dir fails'
    );
    AssertTrue(Stub.DeleteCalls = 1, 'delete failure still records one delete call');
    AssertTrue(Stub.CopyCalls = 0, 'copy is skipped after delete failure');
    AssertTrue(Stub.EnsureCalls = 0, 'ensure is skipped after delete failure');
  finally
    GStub := nil;
    Stub.Free;
    CleanupTempDir(TempRoot);
  end;
end;

begin
  TestPreparePackageInstallSourceTreeCoreReplacesExistingInstallDir;
  TestPreparePackageInstallSourceTreeCoreSkipsCopyForSameResolvedPath;
  TestPreparePackageInstallSourceTreeCoreEnsuresMissingSamePathDir;
  TestPreparePackageInstallSourceTreeCoreStopsOnDeleteFailure;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
