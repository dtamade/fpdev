program test_package_publish;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.registry, fpdev.cmd.package.publish;

type
  { TPackagePublishTest }
  TPackagePublishTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestRegistryDir: string;
    FTestPackageDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);

    procedure CreateTestRegistry;
    procedure CreateTestPackage(const AName, AVersion: string);
    procedure CreateTestArchive(const AName, AVersion: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package publishing (Red Phase - these will fail initially)
    procedure TestPublishValidPackage;
    procedure TestPublishInvalidArchive;
    procedure TestPublishMissingMetadata;
    procedure TestPublishDuplicateVersion;
    procedure TestPublishWithValidation;
    procedure TestPublishUpdatesIndex;
    procedure TestPublishCreatesDirectory;
    procedure TestPublishCopiesArchive;
    procedure TestPublishCopiesChecksum;
    procedure TestPublishCopiesMetadata;
    procedure TestPublishErrorHandling;
    procedure TestPublishDryRun;
    procedure TestPublishForceOverwrite;
    procedure TestPublishInvalidPackageName;
    procedure TestPublishInvalidVersion;
    procedure TestPublishLargeArchive;
    procedure TestPublishMultipleVersions;
    procedure TestPublishConcurrent;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackagePublishTest }

constructor TPackagePublishTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test directories
  FTestRegistryDir := 'test_package_publish_registry';
  FTestPackageDir := 'test_package_publish_packages';

  if not DirectoryExists(FTestRegistryDir) then
    CreateDir(FTestRegistryDir);
  if not DirectoryExists(FTestPackageDir) then
    CreateDir(FTestPackageDir);
end;

destructor TPackagePublishTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackagePublishTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('FAIL: ', AMessage);
  end;
end;

procedure TPackagePublishTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackagePublishTest.CreateTestRegistry;
var
  Registry: TPackageRegistry;
begin
  CleanupTestFiles;
  if not DirectoryExists(FTestRegistryDir) then
    CreateDir(FTestRegistryDir);
  if not DirectoryExists(FTestPackageDir) then
    CreateDir(FTestPackageDir);

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
  finally
    Registry.Free;
  end;
end;

procedure TPackagePublishTest.CreateTestPackage(const AName, AVersion: string);
var
  PackageDir: string;
  F: TextFile;
  MetadataPath: string;
begin
  PackageDir := FTestPackageDir + PathDelim + AName;
  ForceDirectories(PackageDir);

  // Create package.json
  MetadataPath := PackageDir + PathDelim + 'package.json';
  AssignFile(F, MetadataPath);
  try
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "name": "' + AName + '",');
    WriteLn(F, '  "version": "' + AVersion + '",');
    WriteLn(F, '  "description": "Test package for ' + AName + '",');
    WriteLn(F, '  "author": "Test Author",');
    WriteLn(F, '  "license": "MIT"');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;

  // Create a dummy source file
  AssignFile(F, PackageDir + PathDelim + AName + '.pas');
  try
    Rewrite(F);
    WriteLn(F, 'unit ' + AName + ';');
    WriteLn(F, 'interface');
    WriteLn(F, 'implementation');
    WriteLn(F, 'end.');
  finally
    CloseFile(F);
  end;
end;

procedure TPackagePublishTest.CreateTestArchive(const AName, AVersion: string);
var
  ArchivePath: string;
  F: TextFile;
begin
  CreateTestPackage(AName, AVersion);

  // Create archive file (simulated)
  ArchivePath := FTestPackageDir + PathDelim + AName + '-' + AVersion + '.tar.gz';
  AssignFile(F, ArchivePath);
  try
    Rewrite(F);
    Write(F, 'test archive content for ' + AName + ' ' + AVersion);
  finally
    CloseFile(F);
  end;

  // Create checksum file
  AssignFile(F, ArchivePath + '.sha256');
  try
    Rewrite(F);
    Write(F, 'abc123def456789');
  finally
    CloseFile(F);
  end;
end;

procedure TPackagePublishTest.CleanupTestFiles;

  procedure DeleteDirectory(const ADir: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if FindFirst(ADir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            FilePath := ADir + PathDelim + SR.Name;
            if (SR.Attr and faDirectory) <> 0 then
              DeleteDirectory(FilePath)
            else
              DeleteFile(FilePath);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    RemoveDir(ADir);
  end;

begin
  if DirectoryExists(FTestRegistryDir) then
    DeleteDirectory(FTestRegistryDir);
  if DirectoryExists(FTestPackageDir) then
    DeleteDirectory(FTestPackageDir);
end;

procedure TPackagePublishTest.TestPublishValidPackage;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Valid Package ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    AssertTrue(Publisher.Publish(ArchivePath), 'Should publish package successfully');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishInvalidArchive;
var
  Publisher: TPackagePublishCommand;
begin
  WriteLn;
  WriteLn('=== Test: Publish Invalid Archive ===');

  CreateTestRegistry;

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    AssertTrue(not Publisher.Publish('nonexistent.tar.gz'), 'Should fail for non-existent archive');
    AssertTrue(Publisher.GetLastError <> '', 'Should set error message');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishMissingMetadata;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
  F: TextFile;
begin
  WriteLn;
  WriteLn('=== Test: Publish Missing Metadata ===');

  CreateTestRegistry;

  // Create archive without metadata
  ArchivePath := FTestPackageDir + PathDelim + 'badlib-1.0.0.tar.gz';
  AssignFile(F, ArchivePath);
  try
    Rewrite(F);
    Write(F, 'test archive without metadata');
  finally
    CloseFile(F);
  end;

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    AssertTrue(not Publisher.Publish(ArchivePath), 'Should fail for missing metadata');
    AssertTrue(Publisher.GetLastError <> '', 'Should set error message');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishDuplicateVersion;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Duplicate Version ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';

    AssertTrue(Publisher.Publish(ArchivePath), 'First publish should succeed');
    AssertTrue(not Publisher.Publish(ArchivePath), 'Duplicate publish should fail');
    AssertTrue(Publisher.GetLastError <> '', 'Should set error message for duplicate');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishWithValidation;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish With Validation ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    AssertTrue(Publisher.Publish(ArchivePath), 'Should validate and publish successfully');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishUpdatesIndex;
var
  Publisher: TPackagePublishCommand;
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Updates Index ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);
  finally
    Publisher.Free;
  end;

  // Verify index was updated
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    AssertTrue(Registry.HasPackage('testlib'), 'Package should be in registry index');
    AssertTrue(Registry.HasPackageVersion('testlib', '1.0.0'), 'Package version should be in index');
  finally
    Registry.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishCreatesDirectory;
var
  Publisher: TPackagePublishCommand;
  ArchivePath, PackagePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Creates Directory ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);

    PackagePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0';
    AssertTrue(DirectoryExists(PackagePath), 'Package directory should be created');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishCopiesArchive;
var
  Publisher: TPackagePublishCommand;
  ArchivePath, DestPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Copies Archive ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);

    DestPath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    AssertTrue(FileExists(DestPath), 'Archive should be copied to registry');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishCopiesChecksum;
var
  Publisher: TPackagePublishCommand;
  ArchivePath, DestPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Copies Checksum ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);

    DestPath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz.sha256';
    AssertTrue(FileExists(DestPath), 'Checksum should be copied to registry');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishCopiesMetadata;
var
  Publisher: TPackagePublishCommand;
  ArchivePath, DestPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Copies Metadata ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);

    DestPath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'package.json';
    AssertTrue(FileExists(DestPath), 'Metadata should be copied to registry');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishErrorHandling;
var
  Publisher: TPackagePublishCommand;
begin
  WriteLn;
  WriteLn('=== Test: Publish Error Handling ===');

  CreateTestRegistry;

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    AssertTrue(not Publisher.Publish(''), 'Should fail for empty path');
    AssertTrue(Publisher.GetLastError <> '', 'Should set error message');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishDryRun;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
  Registry: TPackageRegistry;
begin
  WriteLn;
  WriteLn('=== Test: Publish Dry Run ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.SetDryRun(True);
    AssertTrue(Publisher.Publish(ArchivePath), 'Dry run should succeed');
  finally
    Publisher.Free;
  end;

  // Verify nothing was actually published
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    AssertTrue(not Registry.HasPackage('testlib'), 'Package should not be in registry after dry run');
  finally
    Registry.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishForceOverwrite;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Force Overwrite ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';

    Publisher.Publish(ArchivePath);

    Publisher.SetForce(True);
    AssertTrue(Publisher.Publish(ArchivePath), 'Force overwrite should succeed');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishInvalidPackageName;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
  F: TextFile;
begin
  WriteLn;
  WriteLn('=== Test: Publish Invalid Package Name ===');

  CreateTestRegistry;

  // Create archive with invalid name
  ArchivePath := FTestPackageDir + PathDelim + 'invalid name-1.0.0.tar.gz';
  AssignFile(F, ArchivePath);
  try
    Rewrite(F);
    Write(F, 'test');
  finally
    CloseFile(F);
  end;

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    AssertTrue(not Publisher.Publish(ArchivePath), 'Should fail for invalid package name');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishInvalidVersion;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
  F: TextFile;
begin
  WriteLn;
  WriteLn('=== Test: Publish Invalid Version ===');

  CreateTestRegistry;

  // Create archive with invalid version
  ArchivePath := FTestPackageDir + PathDelim + 'testlib-invalid.tar.gz';
  AssignFile(F, ArchivePath);
  try
    Rewrite(F);
    Write(F, 'test');
  finally
    CloseFile(F);
  end;

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    AssertTrue(not Publisher.Publish(ArchivePath), 'Should fail for invalid version');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishLargeArchive;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Large Archive ===');

  CreateTestRegistry;
  CreateTestArchive('largelib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'largelib-1.0.0.tar.gz';
    AssertTrue(Publisher.Publish(ArchivePath), 'Should handle large archives');
  finally
    Publisher.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishMultipleVersions;
var
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
  Registry: TPackageRegistry;
  Versions: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Publish Multiple Versions ===');

  CreateTestRegistry;
  CreateTestArchive('testlib', '1.0.0');
  CreateTestArchive('testlib', '1.0.1');
  CreateTestArchive('testlib', '2.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);

    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.1.tar.gz';
    Publisher.Publish(ArchivePath);

    ArchivePath := FTestPackageDir + PathDelim + 'testlib-2.0.0.tar.gz';
    Publisher.Publish(ArchivePath);
  finally
    Publisher.Free;
  end;

  // Verify all versions are published
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    Versions := Registry.GetPackageVersions('testlib');
    try
      AssertTrue(Versions.Count = 3, 'Should have 3 versions published');
    finally
      Versions.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackagePublishTest.TestPublishConcurrent;
var
  Publisher1, Publisher2: TPackagePublishCommand;
  ArchivePath1, ArchivePath2: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish Concurrent ===');

  CreateTestRegistry;
  CreateTestArchive('lib1', '1.0.0');
  CreateTestArchive('lib2', '1.0.0');

  Publisher1 := TPackagePublishCommand.Create(FTestRegistryDir);
  Publisher2 := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath1 := FTestPackageDir + PathDelim + 'lib1-1.0.0.tar.gz';
    ArchivePath2 := FTestPackageDir + PathDelim + 'lib2-1.0.0.tar.gz';

    AssertTrue(Publisher1.Publish(ArchivePath1), 'First publish should succeed');
    AssertTrue(Publisher2.Publish(ArchivePath2), 'Second publish should succeed');
  finally
    Publisher1.Free;
    Publisher2.Free;
  end;
end;

procedure TPackagePublishTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Publishing Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestPublishValidPackage;
  TestPublishInvalidArchive;
  TestPublishMissingMetadata;
  TestPublishDuplicateVersion;
  TestPublishWithValidation;
  TestPublishUpdatesIndex;
  TestPublishCreatesDirectory;
  TestPublishCopiesArchive;
  TestPublishCopiesChecksum;
  TestPublishCopiesMetadata;
  TestPublishErrorHandling;
  TestPublishDryRun;
  TestPublishForceOverwrite;
  TestPublishInvalidPackageName;
  TestPublishInvalidVersion;
  TestPublishLargeArchive;
  TestPublishMultipleVersions;
  TestPublishConcurrent;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Summary:');
  WriteLn('  Passed: ', FTestsPassed);
  WriteLn('  Failed: ', FTestsFailed);
  WriteLn('  Total:  ', FTestsPassed + FTestsFailed);
  WriteLn('========================================');

  if FTestsFailed > 0 then
  begin
    WriteLn;
    WriteLn('RED PHASE: Tests are expected to fail.');
    WriteLn('Next step: Implement TPackagePublishCommand class (Green Phase)');
  end;
end;

var
  Test: TPackagePublishTest;
begin
  Test := TPackagePublishTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
