program test_package_registry;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser, fpdev.package.registry,
  test_temp_paths;

type
  { TPackageRegistryTest }
  TPackageRegistryTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestRegistryDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestRegistry;
    procedure CleanupTestRegistry;
    procedure CreateTestPackage(const AName, AVersion: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package registry (Red Phase - these will fail initially)
    procedure TestRegistryInitialization;
    procedure TestLoadIndex;
    procedure TestSaveIndex;
    procedure TestAddPackage;
    procedure TestRemovePackage;
    procedure TestGetPackageMetadata;
    procedure TestGetPackageVersions;
    procedure TestHasPackage;
    procedure TestHasPackageVersion;
    procedure TestGetPackageArchive;
    procedure TestListPackages;
    procedure TestSearchPackages;
    procedure TestDuplicateVersionHandling;
    procedure TestInvalidPackageHandling;
    procedure TestRegistryCorruption;
    procedure TestConcurrentAccess;
    procedure TestLargePackageHandling;
    procedure TestVersionOrdering;
    procedure TestMetadataUpdate;
    procedure TestIndexRebuild;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageRegistryTest }

constructor TPackageRegistryTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  FTestRegistryDir := CreateUniqueTempDir('test_package_registry_data');
end;

destructor TPackageRegistryTest.Destroy;
begin
  CleanupTestRegistry;
  FTestRegistryDir := '';
  inherited Destroy;
end;

procedure TPackageRegistryTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageRegistryTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageRegistryTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageRegistryTest.CreateTestRegistry;
begin
  CleanupTestRegistry;
  ForceDirectories(FTestRegistryDir);
end;

procedure TPackageRegistryTest.CleanupTestRegistry;
begin
  if FTestRegistryDir <> '' then
    CleanupTempDir(FTestRegistryDir);
end;

procedure TPackageRegistryTest.CreateTestPackage(const AName, AVersion: string);
var
  PackageDir: string;
  F: TextFile;
  MetadataPath: string;
begin
  PackageDir := FTestRegistryDir + PathDelim + 'packages' + PathDelim + AName + PathDelim + AVersion;
  ForceDirectories(PackageDir);

  // Create package.json
  MetadataPath := PackageDir + PathDelim + 'package.json';
  AssignFile(F, MetadataPath);
  try
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "name": "' + AName + '",');
    WriteLn(F, '  "version": "' + AVersion + '",');
    WriteLn(F, '  "description": "Test package",');
    WriteLn(F, '  "author": "Test Author",');
    WriteLn(F, '  "license": "MIT"');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;

  // Create archive file (empty for testing)
  AssignFile(F, PackageDir + PathDelim + AName + '-' + AVersion + '.tar.gz');
  try
    Rewrite(F);
    Write(F, 'test archive content');
  finally
    CloseFile(F);
  end;

  // Create checksum file
  AssignFile(F, PackageDir + PathDelim + AName + '-' + AVersion + '.tar.gz.sha256');
  try
    Rewrite(F);
    Write(F, 'abc123def456');
  finally
    CloseFile(F);
  end;
end;

procedure TPackageRegistryTest.TestRegistryInitialization;
var
  Registry: TPackageRegistry;
begin
  WriteLn;
  WriteLn('=== Test: Registry Initialization ===');

  CreateTestRegistry;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    AssertTrue(Registry.Initialize, 'Should initialize registry successfully');
    AssertTrue(DirectoryExists(FTestRegistryDir + PathDelim + 'packages'), 'Packages directory should exist');
    AssertTrue(FileExists(FTestRegistryDir + PathDelim + 'index.json'), 'Index file should exist');
    AssertTrue(FileExists(FTestRegistryDir + PathDelim + 'config.json'), 'Config file should exist');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestLoadIndex;
var
  Registry: TPackageRegistry;
  F: TextFile;
  IndexPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Load Index ===');

  CreateTestRegistry;

  // Create a test index file
  IndexPath := FTestRegistryDir + PathDelim + 'index.json';
  AssignFile(F, IndexPath);
  try
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "version": "1.0",');
    WriteLn(F, '  "packages": {}');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    AssertTrue(Registry.Initialize, 'Should load existing index');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestSaveIndex;
var
  Registry: TPackageRegistry;
begin
  WriteLn;
  WriteLn('=== Test: Save Index ===');

  CreateTestRegistry;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    AssertTrue(FileExists(FTestRegistryDir + PathDelim + 'index.json'), 'Index file should be saved');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestAddPackage;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Add Package ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    AssertTrue(Registry.AddPackage(ArchivePath), 'Should add package successfully');
    AssertTrue(Registry.HasPackage('testlib'), 'Package should exist in registry');
    AssertTrue(Registry.HasPackageVersion('testlib', '1.0.0'), 'Package version should exist');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestRemovePackage;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Remove Package ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    AssertTrue(Registry.RemovePackage('testlib', '1.0.0'), 'Should remove package successfully');
    AssertTrue(not Registry.HasPackageVersion('testlib', '1.0.0'), 'Package version should not exist after removal');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestGetPackageMetadata;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Metadata: TJSONObject;
begin
  WriteLn;
  WriteLn('=== Test: Get Package Metadata ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    Metadata := Registry.GetPackageMetadata('testlib');
    try
      AssertTrue(Metadata <> nil, 'Should return metadata');
      AssertEquals('testlib', Metadata.Get('name', ''), 'Package name should match');
    finally
      Metadata.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestGetPackageVersions;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Versions: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Get Package Versions ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');
  CreateTestPackage('testlib', '1.0.1');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.1' + PathDelim + 'testlib-1.0.1.tar.gz';
    Registry.AddPackage(ArchivePath);

    Versions := Registry.GetPackageVersions('testlib');
    try
      AssertEqualsInt(2, Versions.Count, 'Should return 2 versions');
    finally
      Versions.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestHasPackage;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Has Package ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    AssertTrue(Registry.HasPackage('testlib'), 'Should find existing package');
    AssertTrue(not Registry.HasPackage('nonexistent'), 'Should not find non-existent package');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestHasPackageVersion;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Has Package Version ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    AssertTrue(Registry.HasPackageVersion('testlib', '1.0.0'), 'Should find existing version');
    AssertTrue(not Registry.HasPackageVersion('testlib', '2.0.0'), 'Should not find non-existent version');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestGetPackageArchive;
var
  Registry: TPackageRegistry;
  ArchivePath, ResultPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Get Package Archive ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ResultPath := Registry.GetPackageArchive('testlib', '1.0.0');
    AssertTrue(ResultPath <> '', 'Should return archive path');
    AssertTrue(FileExists(ResultPath), 'Archive file should exist');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestListPackages;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Packages: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: List Packages ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');
  CreateTestPackage('otherlib', '2.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'otherlib' + PathDelim + '2.0.0' + PathDelim + 'otherlib-2.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    Packages := Registry.ListPackages;
    try
      AssertEqualsInt(2, Packages.Count, 'Should return 2 packages');
    finally
      Packages.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestSearchPackages;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Results: TStringList;
  F: TextFile;
  MetadataPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Search Packages ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');
  CreateTestPackage('otherlib', '2.0.0');

  // Modify otherlib's description to not contain "test"
  MetadataPath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'otherlib' + PathDelim + '2.0.0' + PathDelim + 'package.json';
  AssignFile(F, MetadataPath);
  try
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "name": "otherlib",');
    WriteLn(F, '  "version": "2.0.0",');
    WriteLn(F, '  "description": "Another library",');
    WriteLn(F, '  "author": "Another Author",');
    WriteLn(F, '  "license": "MIT"');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'otherlib' + PathDelim + '2.0.0' + PathDelim + 'otherlib-2.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    Results := Registry.SearchPackages('test');
    try
      AssertEqualsInt(1, Results.Count, 'Should find 1 package matching "test"');
    finally
      Results.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestDuplicateVersionHandling;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Duplicate Version Handling ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';

    AssertTrue(Registry.AddPackage(ArchivePath), 'First add should succeed');
    AssertTrue(not Registry.AddPackage(ArchivePath), 'Duplicate add should fail');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestInvalidPackageHandling;
var
  Registry: TPackageRegistry;
begin
  WriteLn;
  WriteLn('=== Test: Invalid Package Handling ===');

  CreateTestRegistry;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    AssertTrue(not Registry.AddPackage('nonexistent.tar.gz'), 'Should fail for non-existent archive');
    AssertTrue(Registry.GetLastError <> '', 'Should set error message');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestRegistryCorruption;
var
  Registry: TPackageRegistry;
  F: TextFile;
  IndexPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Registry Corruption ===');

  CreateTestRegistry;

  // Create corrupted index file
  IndexPath := FTestRegistryDir + PathDelim + 'index.json';
  AssignFile(F, IndexPath);
  try
    Rewrite(F);
    WriteLn(F, 'invalid json {');
  finally
    CloseFile(F);
  end;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    AssertTrue(not Registry.Initialize, 'Should fail to load corrupted index');
    AssertTrue(Registry.GetLastError <> '', 'Should set error message');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestConcurrentAccess;
var
  Registry1, Registry2: TPackageRegistry;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Concurrent Access ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry1 := TPackageRegistry.Create(FTestRegistryDir);
  Registry2 := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry1.Initialize;
    Registry2.Initialize;

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry1.AddPackage(ArchivePath);

    // Registry2 should see the package after reloading
    Registry2.Free;
    Registry2 := TPackageRegistry.Create(FTestRegistryDir);
    Registry2.Initialize;

    AssertTrue(Registry2.HasPackage('testlib'), 'Second registry should see added package');
  finally
    Registry1.Free;
    Registry2.Free;
  end;
end;

procedure TPackageRegistryTest.TestLargePackageHandling;
var
  Registry: TPackageRegistry;
  I: Integer;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Large Package Handling ===');

  CreateTestRegistry;

  // Create 10 packages with multiple versions
  for I := 1 to 10 do
  begin
    CreateTestPackage('lib' + IntToStr(I), '1.0.0');
    CreateTestPackage('lib' + IntToStr(I), '1.0.1');
  end;

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    // Add all packages
    for I := 1 to 10 do
    begin
      ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'lib' + IntToStr(I) + PathDelim + '1.0.0' + PathDelim + 'lib' + IntToStr(I) + '-1.0.0.tar.gz';
      Registry.AddPackage(ArchivePath);

      ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'lib' + IntToStr(I) + PathDelim + '1.0.1' + PathDelim + 'lib' + IntToStr(I) + '-1.0.1.tar.gz';
      Registry.AddPackage(ArchivePath);
    end;

    AssertEqualsInt(10, Registry.ListPackages.Count, 'Should handle 10 packages');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestVersionOrdering;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Versions: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Version Ordering ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');
  CreateTestPackage('testlib', '1.0.1');
  CreateTestPackage('testlib', '2.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    // Add versions in random order
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '2.0.0' + PathDelim + 'testlib-2.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.1' + PathDelim + 'testlib-1.0.1.tar.gz';
    Registry.AddPackage(ArchivePath);

    Versions := Registry.GetPackageVersions('testlib');
    try
      AssertEqualsInt(3, Versions.Count, 'Should return 3 versions');
      // Versions should be sorted (implementation detail)
    finally
      Versions.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestMetadataUpdate;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  Metadata: TJSONObject;
begin
  WriteLn;
  WriteLn('=== Test: Metadata Update ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);

    Metadata := Registry.GetPackageMetadata('testlib');
    try
      AssertTrue(Metadata <> nil, 'Should return metadata');
      AssertTrue(Metadata.Find('name') <> nil, 'Metadata should have name field');
    finally
      Metadata.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.TestIndexRebuild;
var
  Registry: TPackageRegistry;
  ArchivePath: string;
  IndexPath: string;
begin
  WriteLn;
  WriteLn('=== Test: Index Rebuild ===');

  CreateTestRegistry;
  CreateTestPackage('testlib', '1.0.0');

  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    ArchivePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + 'testlib' + PathDelim + '1.0.0' + PathDelim + 'testlib-1.0.0.tar.gz';
    Registry.AddPackage(ArchivePath);
  finally
    Registry.Free;
  end;

  // Delete index file
  IndexPath := FTestRegistryDir + PathDelim + 'index.json';
  DeleteFile(IndexPath);

  // Recreate registry - should rebuild index
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    AssertTrue(Registry.Initialize, 'Should rebuild index');
    AssertTrue(FileExists(IndexPath), 'Index file should be recreated');
  finally
    Registry.Free;
  end;
end;

procedure TPackageRegistryTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Registry Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestRegistryInitialization;
  TestLoadIndex;
  TestSaveIndex;
  TestAddPackage;
  TestRemovePackage;
  TestGetPackageMetadata;
  TestGetPackageVersions;
  TestHasPackage;
  TestHasPackageVersion;
  TestGetPackageArchive;
  TestListPackages;
  TestSearchPackages;
  TestDuplicateVersionHandling;
  TestInvalidPackageHandling;
  TestRegistryCorruption;
  TestConcurrentAccess;
  TestLargePackageHandling;
  TestVersionOrdering;
  TestMetadataUpdate;
  TestIndexRebuild;

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
    WriteLn('Next step: Implement TPackageRegistry class (Green Phase)');
  end;
end;

var
  Test: TPackageRegistryTest;
begin
  Test := TPackageRegistryTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
