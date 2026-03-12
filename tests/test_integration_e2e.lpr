program test_integration_e2e;

{$codepage utf8}
{$mode objfpc}{$H+}

(*
  End-to-End Integration Test for Package Publishing System

  Tests the complete workflow:
  1. Create a test package
  2. Publish package to registry
  3. Search for the package
  4. Get package information
  5. Verify all components work together
*)

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.registry,
  fpdev.cmd.package.publish,
  fpdev.cmd.package.search, test_temp_paths;

type
  { TIntegrationTest }
  TIntegrationTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestRegistryDir: string;
    FTestPackageDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertContains(const AText, ASubstring: string; const AMessage: string);

    procedure CreateTestPackage(const AName, AVersion, ADescription, AAuthor: string);
    procedure CreateTestArchive(const AName, AVersion: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Integration test scenarios
    procedure TestCompletePublishWorkflow;
    procedure TestSearchAfterPublish;
    procedure TestMultiplePackagesWorkflow;
    procedure TestPublishSearchGetInfoWorkflow;
    procedure TestVersionManagement;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TIntegrationTest }

constructor TIntegrationTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  FTestRegistryDir := CreateUniqueTempDir('test_integration_registry');
  FTestPackageDir := CreateUniqueTempDir('test_integration_packages');
end;

destructor TIntegrationTest.Destroy;
begin
  if FTestRegistryDir <> '' then
  begin
    CleanupTempDir(FTestRegistryDir);
    FTestRegistryDir := '';
  end;

  if FTestPackageDir <> '' then
  begin
    CleanupTempDir(FTestPackageDir);
    FTestPackageDir := '';
  end;

  inherited Destroy;
end;

procedure TIntegrationTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TIntegrationTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TIntegrationTest.AssertContains(const AText, ASubstring: string; const AMessage: string);
begin
  AssertTrue(Pos(ASubstring, AText) > 0, AMessage + ' (Expected to contain: "' + ASubstring + '")');
end;

procedure TIntegrationTest.CreateTestPackage(const AName, AVersion, ADescription, AAuthor: string);
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
    WriteLn(F, '  "description": "' + ADescription + '",');
    WriteLn(F, '  "author": "' + AAuthor + '",');
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

procedure TIntegrationTest.CreateTestArchive(const AName, AVersion: string);
var
  ArchivePath: string;
  F: TextFile;
begin
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

procedure TIntegrationTest.CleanupTestFiles;
begin
  if FTestRegistryDir <> '' then
  begin
    CleanupTempDir(FTestRegistryDir);
    ForceDirectories(FTestRegistryDir);
  end;

  if FTestPackageDir <> '' then
  begin
    CleanupTempDir(FTestPackageDir);
    ForceDirectories(FTestPackageDir);
  end;
end;

procedure TIntegrationTest.TestCompletePublishWorkflow;
var
  Registry: TPackageRegistry;
  Publisher: TPackagePublishCommand;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Complete Publish Workflow ===');

  CleanupTestFiles;
  ForceDirectories(FTestRegistryDir);
  ForceDirectories(FTestPackageDir);

  // Step 1: Initialize registry
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    AssertTrue(Registry.Initialize, 'Registry should initialize');
  finally
    Registry.Free;
  end;

  // Step 2: Create test package
  CreateTestPackage('testlib', '1.0.0', 'Test library for integration', 'Integration Tester');
  CreateTestArchive('testlib', '1.0.0');

  // Step 3: Publish package
  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'testlib-1.0.0.tar.gz';
    AssertTrue(Publisher.Publish(ArchivePath), 'Package should publish successfully');
  finally
    Publisher.Free;
  end;

  // Step 4: Verify package in registry
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    AssertTrue(Registry.HasPackage('testlib'), 'Registry should contain published package');
    AssertTrue(Registry.HasPackageVersion('testlib', '1.0.0'), 'Registry should contain published version');
  finally
    Registry.Free;
  end;
end;

procedure TIntegrationTest.TestSearchAfterPublish;
var
  Publisher: TPackagePublishCommand;
  Search: TPackageSearchCommand;
  Results: TStringList;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Search After Publish ===');

  CleanupTestFiles;
  ForceDirectories(FTestRegistryDir);
  ForceDirectories(FTestPackageDir);

  // Publish a package
  CreateTestPackage('searchlib', '1.0.0', 'Searchable library', 'Search Tester');
  CreateTestArchive('searchlib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'searchlib-1.0.0.tar.gz';
    Publisher.Publish(ArchivePath);
  finally
    Publisher.Free;
  end;

  // Search for the package
  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('searchlib');
    try
      AssertTrue(Results.Count = 1, 'Should find published package');
      AssertTrue(Results.IndexOf('searchlib') >= 0, 'Should find searchlib in results');
    finally
      Results.Free;
    end;

    // Search by description
    Results := Search.Search('Searchable');
    try
      AssertTrue(Results.Count = 1, 'Should find package by description');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TIntegrationTest.TestMultiplePackagesWorkflow;
var
  Publisher: TPackagePublishCommand;
  Search: TPackageSearchCommand;
  Results: TStringList;
  ArchivePath: string;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Test: Multiple Packages Workflow ===');

  CleanupTestFiles;
  ForceDirectories(FTestRegistryDir);
  ForceDirectories(FTestPackageDir);

  // Publish multiple packages
  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    for I := 1 to 3 do
    begin
      CreateTestPackage('lib' + IntToStr(I), '1.0.0', 'Library ' + IntToStr(I), 'Multi Tester');
      CreateTestArchive('lib' + IntToStr(I), '1.0.0');
      ArchivePath := FTestPackageDir + PathDelim + 'lib' + IntToStr(I) + '-1.0.0.tar.gz';
      AssertTrue(Publisher.Publish(ArchivePath), 'Package lib' + IntToStr(I) + ' should publish');
    end;
  finally
    Publisher.Free;
  end;

  // List all packages
  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.ListAll;
    try
      AssertTrue(Results.Count = 3, 'Should list all 3 published packages');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TIntegrationTest.TestPublishSearchGetInfoWorkflow;
var
  Publisher: TPackagePublishCommand;
  Search: TPackageSearchCommand;
  Info: string;
  ArchivePath: string;
begin
  WriteLn;
  WriteLn('=== Test: Publish-Search-GetInfo Workflow ===');

  CleanupTestFiles;
  ForceDirectories(FTestRegistryDir);
  ForceDirectories(FTestPackageDir);

  // Publish package
  CreateTestPackage('infolib', '1.0.0', 'Library with info', 'Info Tester');
  CreateTestArchive('infolib', '1.0.0');

  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    ArchivePath := FTestPackageDir + PathDelim + 'infolib-1.0.0.tar.gz';
    AssertTrue(Publisher.Publish(ArchivePath), 'Package should publish');
  finally
    Publisher.Free;
  end;

  // Get package info
  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Info := Search.GetInfo('infolib');
    AssertTrue(Info <> '', 'Should get package info');
    AssertContains(Info, 'infolib', 'Info should contain package name');
    AssertContains(Info, '1.0.0', 'Info should contain version');
    AssertContains(Info, 'Library with info', 'Info should contain description');
    AssertContains(Info, 'Info Tester', 'Info should contain author');
  finally
    Search.Free;
  end;
end;

procedure TIntegrationTest.TestVersionManagement;
var
  Publisher: TPackagePublishCommand;
  Registry: TPackageRegistry;
  Versions: TStringList;
  ArchivePath: string;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Test: Version Management ===');

  CleanupTestFiles;
  ForceDirectories(FTestRegistryDir);
  ForceDirectories(FTestPackageDir);

  // Publish multiple versions
  Publisher := TPackagePublishCommand.Create(FTestRegistryDir);
  try
    for I := 0 to 2 do
    begin
      CreateTestPackage('versionlib', '1.0.' + IntToStr(I), 'Version test library', 'Version Tester');
      CreateTestArchive('versionlib', '1.0.' + IntToStr(I));
      ArchivePath := FTestPackageDir + PathDelim + 'versionlib-1.0.' + IntToStr(I) + '.tar.gz';
      AssertTrue(Publisher.Publish(ArchivePath), 'Version 1.0.' + IntToStr(I) + ' should publish');
    end;
  finally
    Publisher.Free;
  end;

  // Verify all versions
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;
    Versions := Registry.GetPackageVersions('versionlib');
    try
      AssertTrue(Versions.Count = 3, 'Should have 3 versions');
      AssertTrue(Versions.IndexOf('1.0.0') >= 0, 'Should have version 1.0.0');
      AssertTrue(Versions.IndexOf('1.0.1') >= 0, 'Should have version 1.0.1');
      AssertTrue(Versions.IndexOf('1.0.2') >= 0, 'Should have version 1.0.2');
    finally
      Versions.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TIntegrationTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('End-to-End Integration Tests');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestCompletePublishWorkflow;
  TestSearchAfterPublish;
  TestMultiplePackagesWorkflow;
  TestPublishSearchGetInfoWorkflow;
  TestVersionManagement;

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
    WriteLn('Some integration tests failed!');
  end
  else
  begin
    WriteLn;
    WriteLn('All integration tests passed!');
  end;
end;

var
  Test: TIntegrationTest;
begin
  Test := TIntegrationTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
