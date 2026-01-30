program test_package_search;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.registry, fpdev.cmd.package.search;

type
  { TPackageSearchTest }
  TPackageSearchTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestRegistryDir: string;
    FTestPackageDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertContains(const AText, ASubstring: string; const AMessage: string);

    procedure CreateTestRegistry;
    procedure CreateTestPackage(const AName, AVersion, ADescription, AAuthor: string);
    procedure PublishTestPackage(const AName, AVersion: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package search (Red Phase - these will fail initially)
    procedure TestSearchByName;
    procedure TestSearchByDescription;
    procedure TestSearchCaseInsensitive;
    procedure TestSearchNoResults;
    procedure TestSearchEmptyQuery;
    procedure TestListAllPackages;
    procedure TestListEmptyRegistry;
    procedure TestGetPackageInfo;
    procedure TestGetNonExistentPackageInfo;
    procedure TestSearchMultipleMatches;
    procedure TestSearchPartialMatch;
    procedure TestFormatPackageInfo;
    procedure TestSearchWithSpecialCharacters;
    procedure TestListPackagesOrder;
    procedure TestGetPackageInfoWithVersions;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageSearchTest }

constructor TPackageSearchTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test directories
  FTestRegistryDir := 'test_package_search_registry';
  FTestPackageDir := 'test_package_search_packages';

  if not DirectoryExists(FTestRegistryDir) then
    CreateDir(FTestRegistryDir);
  if not DirectoryExists(FTestPackageDir) then
    CreateDir(FTestPackageDir);
end;

destructor TPackageSearchTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageSearchTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageSearchTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageSearchTest.AssertContains(const AText, ASubstring: string; const AMessage: string);
begin
  AssertTrue(Pos(ASubstring, AText) > 0, AMessage + ' (Expected to contain: "' + ASubstring + '")');
end;

procedure TPackageSearchTest.CreateTestRegistry;
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

procedure TPackageSearchTest.CreateTestPackage(const AName, AVersion, ADescription, AAuthor: string);
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

procedure TPackageSearchTest.PublishTestPackage(const AName, AVersion: string);
var
  ArchivePath: string;
  F: TextFile;
  Registry: TPackageRegistry;
  PackagePath: string;
  MetadataPath, SrcMetadata: string;
  Content: string;
  Line: string;
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

  // Copy metadata to registry manually (simulating publish)
  Registry := TPackageRegistry.Create(FTestRegistryDir);
  try
    Registry.Initialize;

    // Create package directory in registry
    PackagePath := FTestRegistryDir + PathDelim + 'packages' + PathDelim + AName + PathDelim + AVersion;
    ForceDirectories(PackagePath);

    // Copy metadata
    SrcMetadata := FTestPackageDir + PathDelim + AName + PathDelim + 'package.json';
    MetadataPath := PackagePath + PathDelim + 'package.json';
    if FileExists(SrcMetadata) then
    begin
      AssignFile(F, SrcMetadata);
      Reset(F);
      try
        Content := '';
        while not Eof(F) do
        begin
          ReadLn(F, Line);
          Content := Content + Line + LineEnding;
        end;
        CloseFile(F);

        AssignFile(F, MetadataPath);
        Rewrite(F);
        Write(F, Content);
      finally
        CloseFile(F);
      end;
    end;

    // Add to registry index
    Registry.AddPackage(ArchivePath);
  finally
    Registry.Free;
  end;
end;

procedure TPackageSearchTest.CleanupTestFiles;

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

procedure TPackageSearchTest.TestSearchByName;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search By Name ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('xmllib', '1.0.0', 'XML parsing library', 'Test Author');
  PublishTestPackage('xmllib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('jsonlib');
    try
      AssertTrue(Results.Count = 1, 'Should find 1 package');
      AssertTrue(Results.IndexOf('jsonlib') >= 0, 'Should find jsonlib');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchByDescription;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search By Description ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('xmllib', '1.0.0', 'XML parsing library', 'Test Author');
  PublishTestPackage('xmllib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('JSON');
    try
      AssertTrue(Results.Count = 1, 'Should find 1 package by description');
      AssertTrue(Results.IndexOf('jsonlib') >= 0, 'Should find jsonlib by description');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchCaseInsensitive;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search Case Insensitive ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('JSONLIB');
    try
      AssertTrue(Results.Count = 1, 'Should find package case-insensitively');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchNoResults;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search No Results ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('nonexistent');
    try
      AssertTrue(Results.Count = 0, 'Should return empty results for non-existent package');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchEmptyQuery;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search Empty Query ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('xmllib', '1.0.0', 'XML parsing library', 'Test Author');
  PublishTestPackage('xmllib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('');
    try
      AssertTrue(Results.Count = 2, 'Empty query should return all packages');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestListAllPackages;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: List All Packages ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('xmllib', '1.0.0', 'XML parsing library', 'Test Author');
  PublishTestPackage('xmllib', '1.0.0');
  CreateTestPackage('httplib', '1.0.0', 'HTTP client library', 'Test Author');
  PublishTestPackage('httplib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.ListAll;
    try
      AssertTrue(Results.Count = 3, 'Should list all 3 packages');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestListEmptyRegistry;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: List Empty Registry ===');

  CreateTestRegistry;

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.ListAll;
    try
      AssertTrue(Results.Count = 0, 'Should return empty list for empty registry');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestGetPackageInfo;
var
  Search: TPackageSearchCommand;
  Info: string;
begin
  WriteLn;
  WriteLn('=== Test: Get Package Info ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Info := Search.GetInfo('jsonlib');
    AssertTrue(Info <> '', 'Should return package info');
    AssertContains(Info, 'jsonlib', 'Info should contain package name');
    AssertContains(Info, '1.0.0', 'Info should contain version');
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestGetNonExistentPackageInfo;
var
  Search: TPackageSearchCommand;
  Info: string;
begin
  WriteLn;
  WriteLn('=== Test: Get Non-Existent Package Info ===');

  CreateTestRegistry;

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Info := Search.GetInfo('nonexistent');
    AssertTrue(Info = '', 'Should return empty string for non-existent package');
    AssertTrue(Search.GetLastError <> '', 'Should set error message');
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchMultipleMatches;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search Multiple Matches ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('jsonparser', '1.0.0', 'JSON parser utility', 'Test Author');
  PublishTestPackage('jsonparser', '1.0.0');
  CreateTestPackage('xmllib', '1.0.0', 'XML parsing library', 'Test Author');
  PublishTestPackage('xmllib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('json');
    try
      AssertTrue(Results.Count = 2, 'Should find 2 packages matching "json"');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchPartialMatch;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search Partial Match ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('lib');
    try
      AssertTrue(Results.Count = 1, 'Should find package with partial match');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestFormatPackageInfo;
var
  Search: TPackageSearchCommand;
  Info: string;
begin
  WriteLn;
  WriteLn('=== Test: Format Package Info ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Info := Search.GetInfo('jsonlib');
    AssertContains(Info, 'JSON parsing library', 'Info should contain description');
    AssertContains(Info, 'Test Author', 'Info should contain author');
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestSearchWithSpecialCharacters;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: Search With Special Characters ===');

  CreateTestRegistry;
  CreateTestPackage('json-lib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('json-lib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.Search('json-lib');
    try
      AssertTrue(Results.Count = 1, 'Should find package with special characters');
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestListPackagesOrder;
var
  Search: TPackageSearchCommand;
  Results: TStringList;
begin
  WriteLn;
  WriteLn('=== Test: List Packages Order ===');

  CreateTestRegistry;
  CreateTestPackage('zlib', '1.0.0', 'Compression library', 'Test Author');
  PublishTestPackage('zlib', '1.0.0');
  CreateTestPackage('alib', '1.0.0', 'A library', 'Test Author');
  PublishTestPackage('alib', '1.0.0');
  CreateTestPackage('mlib', '1.0.0', 'M library', 'Test Author');
  PublishTestPackage('mlib', '1.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Results := Search.ListAll;
    try
      AssertTrue(Results.Count = 3, 'Should list all 3 packages');
      // Note: Order may vary depending on implementation
    finally
      Results.Free;
    end;
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.TestGetPackageInfoWithVersions;
var
  Search: TPackageSearchCommand;
  Info: string;
begin
  WriteLn;
  WriteLn('=== Test: Get Package Info With Versions ===');

  CreateTestRegistry;
  CreateTestPackage('jsonlib', '1.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.0');
  CreateTestPackage('jsonlib', '1.0.1', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '1.0.1');
  CreateTestPackage('jsonlib', '2.0.0', 'JSON parsing library', 'Test Author');
  PublishTestPackage('jsonlib', '2.0.0');

  Search := TPackageSearchCommand.Create(FTestRegistryDir);
  try
    Info := Search.GetInfo('jsonlib');
    AssertTrue(Info <> '', 'Should return package info');
    AssertContains(Info, '1.0.0', 'Info should contain version 1.0.0');
    AssertContains(Info, '1.0.1', 'Info should contain version 1.0.1');
    AssertContains(Info, '2.0.0', 'Info should contain version 2.0.0');
  finally
    Search.Free;
  end;
end;

procedure TPackageSearchTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Search Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestSearchByName;
  TestSearchByDescription;
  TestSearchCaseInsensitive;
  TestSearchNoResults;
  TestSearchEmptyQuery;
  TestListAllPackages;
  TestListEmptyRegistry;
  TestGetPackageInfo;
  TestGetNonExistentPackageInfo;
  TestSearchMultipleMatches;
  TestSearchPartialMatch;
  TestFormatPackageInfo;
  TestSearchWithSpecialCharacters;
  TestListPackagesOrder;
  TestGetPackageInfoWithVersions;

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
    WriteLn('Next step: Implement TPackageSearchCommand class (Green Phase)');
  end;
end;

var
  Test: TPackageSearchTest;
begin
  Test := TPackageSearchTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
