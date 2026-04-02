program test_package_install_flow_helper;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  fpdev.package.installflow, fpdev.utils.fs,
  test_temp_paths;

type
  TStubInstallFlow = class
  public
    LastExtractArchive: string;
    LastExtractDest: string;
    LastInstallPackage: string;
    LastInstallSource: string;
    function ExtractArchive(const AArchive, ADestDir: string; out AErr: string): Boolean;
    function InstallFromSource(const APackageName, ASourcePath: string): Boolean;
  end;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  GStubInstallFlow: TStubInstallFlow = nil;

procedure AssertTrue(ACondition: Boolean; const AMessage: string); forward;

function MakeSandboxDir(const APrefix: string): string;
begin
  Result := CreateUniqueTempDir(APrefix);
end;

procedure AssertUsesSystemTempPath(const APath, ALabel: string);
begin
  AssertTrue(PathUsesSystemTempRoot(APath),
    ALabel + ' lives under system temp');
end;

function TStubInstallFlow.ExtractArchive(const AArchive, ADestDir: string; out AErr: string): Boolean;
begin
  LastExtractArchive := AArchive;
  LastExtractDest := ADestDir;
  ForceDirectories(ADestDir);
  AErr := '';
  Result := True;
end;

function TStubInstallFlow.InstallFromSource(const APackageName, ASourcePath: string): Boolean;
begin
  LastInstallPackage := APackageName;
  LastInstallSource := ASourcePath;
  Result := True;
end;


function StubExtractArchiveBridge(const AArchive, ADestDir: string; out AErr: string): Boolean;
begin
  if GStubInstallFlow = nil then
  begin
    AErr := 'stub not assigned';
    Exit(False);
  end;
  Result := GStubInstallFlow.ExtractArchive(AArchive, ADestDir, AErr);
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

procedure TestInstallPackageArchiveCoreCleansTempDir;
var
  Stub: TStubInstallFlow;
  SandboxDir: string;
  TempDir: string;
  CleanupWarningPath: string;
  Err: string;
begin
  SandboxDir := MakeSandboxDir('fpdev_install_flow_clean');
  AssertUsesSystemTempPath(SandboxDir, 'cleanup-enabled sandbox');
  Stub := TStubInstallFlow.Create;
  try
    GStubInstallFlow := Stub;
    AssertTrue(
      InstallPackageArchiveCore(
        'alpha', '1.2.0', '/tmp/cache/alpha-1.2.0.zip', SandboxDir, False,
        @StubExtractArchiveBridge, @Stub.InstallFromSource,
        CleanupWarningPath, Err
      ),
      'install flow succeeds when cleanup enabled'
    );
    TempDir := IncludeTrailingPathDelimiter(SandboxDir) + 'pkg-alpha-1.2.0';
    AssertEquals(TempDir, Stub.LastExtractDest, 'extract path uses sandbox package temp dir');
    AssertEquals('alpha', Stub.LastInstallPackage, 'install callback receives package name');
    AssertEquals(TempDir, Stub.LastInstallSource, 'install callback receives temp dir');
    AssertTrue(not DirectoryExists(TempDir), 'temp dir is removed when keepArtifacts is false');
    AssertEquals('', CleanupWarningPath, 'no cleanup warning path on successful cleanup');
  finally
    CleanupTempDir(SandboxDir);
    GStubInstallFlow := nil;
    Stub.Free;
  end;
  AssertTrue(not DirectoryExists(SandboxDir), 'sandbox dir is cleaned after cleanup-enabled test');
end;

procedure TestInstallPackageArchiveCoreKeepsTempDirWhenRequested;
var
  Stub: TStubInstallFlow;
  SandboxDir: string;
  TempDir: string;
  CleanupWarningPath: string;
  Err: string;
begin
  SandboxDir := MakeSandboxDir('fpdev_install_flow_keep');
  AssertUsesSystemTempPath(SandboxDir, 'keep-artifacts sandbox');
  Stub := TStubInstallFlow.Create;
  try
    GStubInstallFlow := Stub;
    AssertTrue(
      InstallPackageArchiveCore(
        'beta', '2.0.0', '/tmp/cache/beta-2.0.0.zip', SandboxDir, True,
        @StubExtractArchiveBridge, @Stub.InstallFromSource,
        CleanupWarningPath, Err
      ),
      'install flow succeeds when keepArtifacts enabled'
    );
    TempDir := IncludeTrailingPathDelimiter(SandboxDir) + 'pkg-beta-2.0.0';
    AssertTrue(DirectoryExists(TempDir), 'temp dir is preserved when keepArtifacts is true');
    AssertEquals('', CleanupWarningPath, 'no cleanup warning path when keeping artifacts');
  finally
    CleanupTempDir(SandboxDir);
    GStubInstallFlow := nil;
    Stub.Free;
  end;
  AssertTrue(not DirectoryExists(SandboxDir), 'sandbox dir is cleaned after keep-artifacts test');
end;

begin
  TestInstallPackageArchiveCoreCleansTempDir;
  TestInstallPackageArchiveCoreKeepsTempDirWhenRequested;

  if TestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('FAILED: ', TestsFailed, ' assertions failed');
    Halt(1);
  end;

  WriteLn;
  WriteLn('SUCCESS: All ', TestsPassed, ' assertions passed');
end.
