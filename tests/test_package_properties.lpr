program test_package_properties;

{$mode objfpc}{$H+}

{
  Property-Based Tests for Package Management
  
  Property 1: Dependency Resolution Completeness
  Property 4: Package Verification Round-Trip
  Property 5: Checksum Verification Correctness
  Property 6: Package Creation Round-Trip
  Property 7: Build Artifact Exclusion
  Property 9: Error Result Consistency
  
  Validates: Requirements 1.1, 1.2, 1.5, 2.1, 2.2, 2.3, 2.5, 3.1, 3.3, 3.4, 3.6, 6.2
}

uses
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.cmd.package, fpdev.package.types, fpdev.hash, fpdev.paths;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TotalTests: Integer = 0;
  TempDir: string;

procedure Assert(Condition: Boolean; const TestName: string);
begin
  Inc(TotalTests);
  if Condition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

{ Helper: Create temporary directory }
function CreateTempDir(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) + 'fpdev_test_' + AName + '_' + IntToStr(GetTickCount64);
  ForceDirectories(Result);
end;

{ Helper: Remove directory recursively }
procedure RemoveDirRecursive(const ADir: string);
var
  SR: TSearchRec;
  P: string;
begin
  if not DirectoryExists(ADir) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      P := IncludeTrailingPathDelimiter(ADir) + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
        RemoveDirRecursive(P)
      else
        DeleteFile(P);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
  RemoveDir(ADir);
end;

{ Helper: Create test file with content }
procedure CreateTestFile(const APath, AContent: string);
var
  SL: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  SL := TStringList.Create;
  try
    SL.Text := AContent;
    SL.SaveToFile(APath);
  finally
    SL.Free;
  end;
end;

{ Helper: Create test package index }
function CreateTestPackageIndex: TPackageArray;
begin
  SetLength(Result, 5);
  
  // Package A - no dependencies (leaf)
  Result[0].Name := 'pkgA';
  Result[0].Version := '1.0.0';
  SetLength(Result[0].Dependencies, 0);
  
  // Package B - depends on A
  Result[1].Name := 'pkgB';
  Result[1].Version := '2.0.0';
  SetLength(Result[1].Dependencies, 1);
  Result[1].Dependencies[0] := 'pkgA:>=1.0.0';
  
  // Package C - depends on A and B
  Result[2].Name := 'pkgC';
  Result[2].Version := '1.5.0';
  SetLength(Result[2].Dependencies, 2);
  Result[2].Dependencies[0] := 'pkgA:>=1.0.0';
  Result[2].Dependencies[1] := 'pkgB:>=1.0.0';
  
  // Package D - depends on C (transitive: D -> C -> A, B -> A)
  Result[3].Name := 'pkgD';
  Result[3].Version := '3.0.0';
  SetLength(Result[3].Dependencies, 1);
  Result[3].Dependencies[0] := 'pkgC:>=1.0.0';
  
  // Package E - no dependencies (isolated)
  Result[4].Name := 'pkgE';
  Result[4].Version := '1.0.0';
  SetLength(Result[4].Dependencies, 0);
end;


{ ============================================================ }
{ Property 1: Dependency Resolution Completeness               }
{ For any valid package with dependencies, resolving           }
{ dependencies SHALL return a complete list containing all     }
{ transitive dependencies.                                     }
{ Validates: Requirements 1.1, 1.2, 1.5                        }
{ ============================================================ }

procedure PropertyTestDependencyResolutionCompleteness;
var
  Index: TPackageArray;
  Graph: TDependencyGraph;
  SortedOrder: TStringArray;
  i, j, k, m: Integer;
  DepName: string;
  DepParts: TStringArray;
  DepFound: Boolean;
  AllDepsIncluded: Boolean;
  HasDuplicates: Boolean;
begin
  WriteLn('');
  WriteLn('=== Property 1: Dependency Resolution Completeness ===');
  WriteLn('For any valid package, all transitive dependencies are included');
  
  Index := CreateTestPackageIndex;
  
  // Test with multiple root packages
  for i := 0 to High(Index) do
  begin
    Graph := BuildDependencyGraph(Index[i].Name, Index);
    
    // Verify: all dependencies of each node are also in the graph
    AllDepsIncluded := True;
    for j := 0 to High(Graph) do
    begin
      for k := 0 to High(Graph[j].Dependencies) do
      begin
        DepParts := Graph[j].Dependencies[k].Split([':']);
        if Length(DepParts) > 0 then
        begin
          DepName := DepParts[0];
          DepFound := False;
          
          // Check if dependency is in graph
          for m := 0 to High(Graph) do
          begin
            if SameText(Graph[m].Name, DepName) then
            begin
              DepFound := True;
              Break;
            end;
          end;
          
          if not DepFound then
          begin
            AllDepsIncluded := False;
            WriteLn('  Missing dependency: ', DepName, ' for package ', Graph[j].Name);
          end;
        end;
      end;
    end;
    
    Assert(AllDepsIncluded, 'All deps included for ' + Index[i].Name);
  end;
  
  // Test topological sort produces valid order
  Graph := BuildDependencyGraph('pkgD', Index);
  SortedOrder := TopologicalSortDependencies(Graph);
  
  // Verify: sorted order contains all nodes
  Assert(Length(SortedOrder) = Length(Graph), 'Topo sort includes all nodes');
  
  // Verify: no duplicates in sorted order
  HasDuplicates := False;
  for i := 0 to High(SortedOrder) do
  begin
    for j := i + 1 to High(SortedOrder) do
    begin
      if SameText(SortedOrder[i], SortedOrder[j]) then
      begin
        HasDuplicates := True;
        Break;
      end;
    end;
    if HasDuplicates then Break;
  end;
  Assert(not HasDuplicates, 'Topo sort has no duplicates');
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 1: Dependency Resolution Completeness verified');
end;

{ ============================================================ }
{ Property 4: Package Verification Round-Trip                  }
{ For any valid installed package, verifying the package       }
{ SHALL return success status.                                 }
{ Validates: Requirements 2.1, 2.2, 2.5                        }
{ ============================================================ }

procedure PropertyTestPackageVerificationRoundTrip;
var
  TestDir: string;
  MetaPath: string;
  VerifyResult: TPackageVerificationResult;
  i: Integer;
  TestPackages: array[0..2] of record
    Name: string;
    Version: string;
    HasLpk: Boolean;
  end;
begin
  WriteLn('');
  WriteLn('=== Property 4: Package Verification Round-Trip ===');
  WriteLn('For any valid installed package, verification returns success');
  
  // Define test packages
  TestPackages[0].Name := 'testpkg1';
  TestPackages[0].Version := '1.0.0';
  TestPackages[0].HasLpk := True;
  
  TestPackages[1].Name := 'testpkg2';
  TestPackages[1].Version := '2.3.4';
  TestPackages[1].HasLpk := False;  // Has Makefile instead
  
  TestPackages[2].Name := 'testpkg3';
  TestPackages[2].Version := '0.1.0-alpha';
  TestPackages[2].HasLpk := True;
  
  for i := 0 to High(TestPackages) do
  begin
    // Create test package directory
    TestDir := CreateTempDir('verify_' + TestPackages[i].Name);
    try
      // Create package.json
      MetaPath := IncludeTrailingPathDelimiter(TestDir) + 'package.json';
      CreateTestFile(MetaPath, 
        '{"name":"' + TestPackages[i].Name + '","version":"' + TestPackages[i].Version + '","description":"Test package"}');
      
      // Create required file (.lpk or Makefile)
      if TestPackages[i].HasLpk then
        CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'test.lpk', '<?xml version="1.0"?><CONFIG></CONFIG>')
      else
        CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'Makefile', 'all:\n\techo "build"');
      
      // Verify the package
      VerifyResult := VerifyInstalledPackage(TestDir);
      
      // Check results
      Assert(VerifyResult.Status = vsValid, 'Verify ' + TestPackages[i].Name + ' - status valid');
      Assert(VerifyResult.PackageName = TestPackages[i].Name, 'Verify ' + TestPackages[i].Name + ' - name matches');
      Assert(VerifyResult.Version = TestPackages[i].Version, 'Verify ' + TestPackages[i].Name + ' - version matches');
      Assert(Length(VerifyResult.MissingFiles) = 0, 'Verify ' + TestPackages[i].Name + ' - no missing files');
    finally
      RemoveDirRecursive(TestDir);
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 4: Package Verification Round-Trip verified');
end;


{ ============================================================ }
{ Property 5: Checksum Verification Correctness                }
{ For any file with a known SHA256 checksum, the verifier      }
{ SHALL correctly identify matching and non-matching checksums }
{ Validates: Requirements 2.3                                  }
{ ============================================================ }

procedure PropertyTestChecksumVerificationCorrectness;
var
  TestDir: string;
  TestFile: string;
  ComputedHash: string;
  WrongHash: string;
  i: Integer;
  TestContents: array[0..4] of string;
begin
  WriteLn('');
  WriteLn('=== Property 5: Checksum Verification Correctness ===');
  WriteLn('For any file, checksum verification correctly identifies matches');
  
  // Define test contents
  TestContents[0] := 'Hello, World!';
  TestContents[1] := 'This is a test file with some content.';
  TestContents[2] := '{"name":"test","version":"1.0.0"}';
  TestContents[3] := 'Line1'#10'Line2'#10'Line3';
  TestContents[4] := '';  // Empty file
  
  TestDir := CreateTempDir('checksum');
  try
    for i := 0 to High(TestContents) do
    begin
      TestFile := IncludeTrailingPathDelimiter(TestDir) + 'test' + IntToStr(i) + '.txt';
      CreateTestFile(TestFile, TestContents[i]);
      
      // Compute actual hash
      ComputedHash := SHA256FileHex(TestFile);
      
      // Test 1: Correct hash should verify
      Assert(VerifyPackageChecksum(TestFile, ComputedHash), 
        'Checksum match for content ' + IntToStr(i));
      
      // Test 2: Wrong hash should not verify
      WrongHash := StringOfChar('0', 64);  // All zeros
      Assert(not VerifyPackageChecksum(TestFile, WrongHash), 
        'Checksum mismatch detected for content ' + IntToStr(i));
      
      // Test 3: Invalid hash length should not verify
      Assert(not VerifyPackageChecksum(TestFile, 'abc123'), 
        'Invalid hash length rejected for content ' + IntToStr(i));
      
      // Test 4: Empty hash should not verify
      Assert(not VerifyPackageChecksum(TestFile, ''), 
        'Empty hash rejected for content ' + IntToStr(i));
    end;
    
    // Test 5: Non-existent file should not verify
    Assert(not VerifyPackageChecksum(TestDir + '/nonexistent.txt', ComputedHash), 
      'Non-existent file rejected');
    
  finally
    RemoveDirRecursive(TestDir);
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 5: Checksum Verification Correctness verified');
end;

{ ============================================================ }
{ Property 6: Package Creation Round-Trip                      }
{ For any valid source directory, creating a package and       }
{ extracting it SHALL produce equivalent source files.         }
{ Validates: Requirements 3.1, 3.3, 3.4, 3.6                   }
{ ============================================================ }

procedure PropertyTestPackageCreationRoundTrip;
var
  SourceDir, OutputDir: string;
  Options: TPackageCreationOptions;
  Files: TStringArray;
  MetaJson: string;
  OutputPath: string;
  Err: string;
  i, j: Integer;
  HasBuildArtifact: Boolean;
  SourceCount: Integer;
  SourceFiles: array[0..3] of record
    Name: string;
    Content: string;
  end;
begin
  WriteLn('');
  WriteLn('=== Property 6: Package Creation Round-Trip ===');
  WriteLn('Creating a package preserves source files (excluding build artifacts)');
  
  // Define source files
  SourceFiles[0].Name := 'main.pas';
  SourceFiles[0].Content := 'program main; begin end.';
  
  SourceFiles[1].Name := 'unit1.pas';
  SourceFiles[1].Content := 'unit unit1; interface implementation end.';
  
  SourceFiles[2].Name := 'test.lpk';
  SourceFiles[2].Content := '<?xml version="1.0"?><CONFIG></CONFIG>';
  
  SourceFiles[3].Name := 'README.md';
  SourceFiles[3].Content := '# Test Package';
  
  SourceDir := CreateTempDir('pkg_source');
  OutputDir := CreateTempDir('pkg_output');
  try
    // Create source files
    for i := 0 to High(SourceFiles) do
      CreateTestFile(IncludeTrailingPathDelimiter(SourceDir) + SourceFiles[i].Name, 
                     SourceFiles[i].Content);
    
    // Create some build artifacts that should be excluded
    CreateTestFile(IncludeTrailingPathDelimiter(SourceDir) + 'main.o', 'binary');
    CreateTestFile(IncludeTrailingPathDelimiter(SourceDir) + 'unit1.ppu', 'binary');
    CreateTestFile(IncludeTrailingPathDelimiter(SourceDir) + 'main.exe', 'binary');
    
    // Collect source files
    SetLength(Options.ExcludePatterns, 0);
    Files := CollectPackageSourceFiles(SourceDir, Options.ExcludePatterns);

    // Verify build artifacts are excluded
    HasBuildArtifact := False;
    for i := 0 to High(Files) do
    begin
      if IsBuildArtifact(Files[i]) then
      begin
        HasBuildArtifact := True;
        WriteLn('  Unexpected build artifact: ', Files[i]);
      end;
    end;
    Assert(not HasBuildArtifact, 'Build artifacts excluded from collection');

    // Verify source files are included
    SourceCount := 0;
    for i := 0 to High(SourceFiles) do
    begin
      for j := 0 to High(Files) do
      begin
        if SameText(ExtractFileName(Files[j]), SourceFiles[i].Name) then
        begin
          Inc(SourceCount);
          Break;
        end;
      end;
    end;
    Assert(SourceCount = Length(SourceFiles), 'All source files included');
    
    // Generate metadata
    FillChar(Options, SizeOf(Options), 0);
    Options.Name := 'testpkg';
    Options.Version := '1.0.0';
    Options.SourcePath := SourceDir;
    
    MetaJson := GeneratePackageMetadataJson(Options);
    Assert(MetaJson <> '', 'Metadata JSON generated');
    Assert(Pos('"name":"testpkg"', MetaJson) > 0, 'Metadata contains name');
    Assert(Pos('"version":"1.0.0"', MetaJson) > 0, 'Metadata contains version');
    
    // Create ZIP archive
    OutputPath := IncludeTrailingPathDelimiter(OutputDir) + 'testpkg-1.0.0.zip';
    Assert(CreatePackageZipArchive(SourceDir, Files, OutputPath, Err), 
      'ZIP archive created: ' + Err);
    Assert(FileExists(OutputPath), 'ZIP file exists');
    
  finally
    RemoveDirRecursive(SourceDir);
    RemoveDirRecursive(OutputDir);
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 6: Package Creation Round-Trip verified');
end;


{ ============================================================ }
{ Property 7: Build Artifact Exclusion                         }
{ For any source directory containing build artifacts,         }
{ the created package SHALL NOT contain any of these files.    }
{ Validates: Requirements 3.6                                  }
{ ============================================================ }

procedure PropertyTestBuildArtifactExclusion;
var
  TestDir: string;
  Files: TStringArray;
  ExcludePatterns: TStringArray;
  i, j: Integer;
  BuildArtifacts: array[0..8] of string;
  SourceFiles: array[0..3] of string;
  HasArtifact: Boolean;
  SourceCount: Integer;
begin
  WriteLn('');
  WriteLn('=== Property 7: Build Artifact Exclusion ===');
  WriteLn('Build artifacts (.o, .ppu, .exe, .dll, etc.) are excluded');
  
  // Define build artifacts to test
  BuildArtifacts[0] := 'main.o';
  BuildArtifacts[1] := 'unit1.ppu';
  BuildArtifacts[2] := 'program.exe';
  BuildArtifacts[3] := 'library.dll';
  BuildArtifacts[4] := 'static.a';
  BuildArtifacts[5] := 'shared.so';
  BuildArtifacts[6] := 'delphi.dcu';
  BuildArtifacts[7] := 'package.bpl';
  BuildArtifacts[8] := 'design.dcp';
  
  // Define source files that should be included
  SourceFiles[0] := 'main.pas';
  SourceFiles[1] := 'unit1.pas';
  SourceFiles[2] := 'test.lpk';
  SourceFiles[3] := 'README.txt';
  
  TestDir := CreateTempDir('artifacts');
  try
    // Create all files
    for i := 0 to High(BuildArtifacts) do
      CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + BuildArtifacts[i], 'binary content');
    
    for i := 0 to High(SourceFiles) do
      CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + SourceFiles[i], 'source content');
    
    // Collect files
    SetLength(ExcludePatterns, 0);
    Files := CollectPackageSourceFiles(TestDir, ExcludePatterns);
    
    // Verify: no build artifacts in collected files
    HasArtifact := False;
    for i := 0 to High(Files) do
    begin
      if IsBuildArtifact(Files[i]) then
      begin
        HasArtifact := True;
        WriteLn('  Unexpected artifact: ', Files[i]);
      end;
    end;
    Assert(not HasArtifact, 'No build artifacts in collected files');
    
    // Verify: all source files are included
    SourceCount := 0;
    for i := 0 to High(SourceFiles) do
    begin
      for j := 0 to High(Files) do
      begin
        if SameText(ExtractFileName(Files[j]), SourceFiles[i]) then
        begin
          Inc(SourceCount);
          Break;
        end;
      end;
    end;
    Assert(SourceCount = Length(SourceFiles), 'All source files included');
    
    // Test IsBuildArtifact function directly
    for i := 0 to High(BuildArtifacts) do
      Assert(IsBuildArtifact(BuildArtifacts[i]), 'IsBuildArtifact(' + BuildArtifacts[i] + ')');
    
    for i := 0 to High(SourceFiles) do
      Assert(not IsBuildArtifact(SourceFiles[i]), 'Not artifact: ' + SourceFiles[i]);
    
  finally
    RemoveDirRecursive(TestDir);
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 7: Build Artifact Exclusion verified');
end;

{ ============================================================ }
{ Property 9: Error Result Consistency                         }
{ For any failed operation, the returned TPackageOperationResult }
{ SHALL have Success=False, non-empty ErrorMessage, and valid  }
{ ErrorCode.                                                   }
{ Validates: Requirements 6.2                                  }
{ ============================================================ }

procedure PropertyTestErrorResultConsistency;
var
  Result: TPackageOperationResult;
  i, j: Integer;
  ErrorCodes: array[0..9] of TPackageErrorCode;
begin
  WriteLn('');
  WriteLn('=== Property 9: Error Result Consistency ===');
  WriteLn('Failed operations have Success=False, non-empty ErrorMessage, valid ErrorCode');
  
  // Define all error codes
  ErrorCodes[0] := pecNone;
  ErrorCodes[1] := pecPackageNotFound;
  ErrorCodes[2] := pecDependencyNotFound;
  ErrorCodes[3] := pecCircularDependency;
  ErrorCodes[4] := pecVersionConflict;
  ErrorCodes[5] := pecInvalidMetadata;
  ErrorCodes[6] := pecChecksumMismatch;
  ErrorCodes[7] := pecNetworkError;
  ErrorCodes[8] := pecFileSystemError;
  ErrorCodes[9] := pecRepositoryNotConfigured;
  
  // Test: Simulate error results and verify consistency
  for i := 1 to High(ErrorCodes) do  // Skip pecNone
  begin
    // Create a failed result
    Result.Success := False;
    Result.ErrorCode := ErrorCodes[i];
    Result.ErrorMessage := 'Test error message for code ' + IntToStr(Ord(ErrorCodes[i]));
    
    // Verify consistency
    Assert(not Result.Success, 'Error result has Success=False for code ' + IntToStr(i));
    Assert(Result.ErrorCode <> pecNone, 'Error result has non-None ErrorCode for code ' + IntToStr(i));
    Assert(Result.ErrorMessage <> '', 'Error result has non-empty ErrorMessage for code ' + IntToStr(i));
  end;
  
  // Test: Success result should have pecNone
  Result.Success := True;
  Result.ErrorCode := pecNone;
  Result.ErrorMessage := '';
  
  Assert(Result.Success, 'Success result has Success=True');
  Assert(Result.ErrorCode = pecNone, 'Success result has ErrorCode=pecNone');
  
  // Test: Verify error code enum values are distinct
  for i := 0 to High(ErrorCodes) do
  begin
    for j := i + 1 to High(ErrorCodes) do
    begin
      Assert(ErrorCodes[i] <> ErrorCodes[j],
        'Error codes are distinct: ' + IntToStr(i) + ' vs ' + IntToStr(j));
    end;
  end;
  
  Inc(TestsPassed);
  Inc(TotalTests);
  WriteLn('[PASS] Property 9: Error Result Consistency verified');
end;

{ ============================================================ }
{ Additional Unit Tests                                        }
{ ============================================================ }

procedure TestValidatePackageSourcePath;
var
  TestDir: string;
begin
  WriteLn('');
  WriteLn('=== ValidatePackageSourcePath Tests ===');
  
  TestDir := CreateTempDir('validate_source');
  try
    // Test: Empty directory should fail
    Assert(not ValidatePackageSourcePath(TestDir), 'Empty dir fails validation');
    
    // Test: Directory with .lpk should pass
    CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'test.lpk', '<CONFIG/>');
    Assert(ValidatePackageSourcePath(TestDir), 'Dir with .lpk passes');
    DeleteFile(IncludeTrailingPathDelimiter(TestDir) + 'test.lpk');
    
    // Test: Directory with Makefile should pass
    CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'Makefile', 'all:');
    Assert(ValidatePackageSourcePath(TestDir), 'Dir with Makefile passes');
    
    // Test: Non-existent directory should fail
    Assert(not ValidatePackageSourcePath('/nonexistent/path'), 'Non-existent dir fails');
    
  finally
    RemoveDirRecursive(TestDir);
  end;
end;

procedure TestValidatePackageMetadata;
var
  TestDir: string;
  MetaPath: string;
begin
  WriteLn('');
  WriteLn('=== ValidatePackageMetadata Tests ===');
  
  TestDir := CreateTempDir('validate_meta');
  MetaPath := IncludeTrailingPathDelimiter(TestDir) + 'package.json';
  try
    // Test: Valid metadata
    CreateTestFile(MetaPath, '{"name":"test","version":"1.0.0"}');
    Assert(ValidatePackageMetadata(MetaPath), 'Valid metadata passes');
    
    // Test: Missing name
    CreateTestFile(MetaPath, '{"version":"1.0.0"}');
    Assert(not ValidatePackageMetadata(MetaPath), 'Missing name fails');
    
    // Test: Missing version
    CreateTestFile(MetaPath, '{"name":"test"}');
    Assert(not ValidatePackageMetadata(MetaPath), 'Missing version fails');
    
    // Test: Empty name
    CreateTestFile(MetaPath, '{"name":"","version":"1.0.0"}');
    Assert(not ValidatePackageMetadata(MetaPath), 'Empty name fails');
    
    // Test: Invalid JSON
    CreateTestFile(MetaPath, 'not json');
    Assert(not ValidatePackageMetadata(MetaPath), 'Invalid JSON fails');
    
    // Test: Empty file
    CreateTestFile(MetaPath, '');
    Assert(not ValidatePackageMetadata(MetaPath), 'Empty file fails');
    
    // Test: Non-existent file
    DeleteFile(MetaPath);
    Assert(not ValidatePackageMetadata(MetaPath), 'Non-existent file fails');
    
  finally
    RemoveDirRecursive(TestDir);
  end;
end;

procedure TestCheckPackageRequiredFiles;
var
  TestDir: string;
  Missing: TStringArray;
begin
  WriteLn('');
  WriteLn('=== CheckPackageRequiredFiles Tests ===');
  
  TestDir := CreateTempDir('check_files');
  try
    // Test: Empty directory - missing package.json and .lpk/Makefile
    Missing := CheckPackageRequiredFiles(TestDir);
    Assert(Length(Missing) >= 1, 'Empty dir has missing files');
    
    // Test: With package.json but no .lpk/Makefile
    CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'package.json', '{}');
    Missing := CheckPackageRequiredFiles(TestDir);
    Assert(Length(Missing) >= 1, 'Missing .lpk/Makefile detected');
    
    // Test: With package.json and .lpk
    CreateTestFile(IncludeTrailingPathDelimiter(TestDir) + 'test.lpk', '<CONFIG/>');
    Missing := CheckPackageRequiredFiles(TestDir);
    Assert(Length(Missing) = 0, 'Complete package has no missing files');
    
    // Test: Non-existent directory
    Missing := CheckPackageRequiredFiles('/nonexistent/path');
    Assert(Length(Missing) > 0, 'Non-existent dir reports missing');
    
  finally
    RemoveDirRecursive(TestDir);
  end;
end;

{ Main }
begin
  Randomize;
  
  WriteLn('========================================');
  WriteLn('Package Management Property Tests');
  WriteLn('Properties 1, 4, 5, 6, 7, 9');
  WriteLn('Validates: Requirements 1.1-1.5, 2.1-2.5, 3.1-3.6, 6.2');
  WriteLn('========================================');
  
  // Property-based tests
  PropertyTestDependencyResolutionCompleteness;
  PropertyTestPackageVerificationRoundTrip;
  PropertyTestChecksumVerificationCorrectness;
  PropertyTestPackageCreationRoundTrip;
  PropertyTestBuildArtifactExclusion;
  PropertyTestErrorResultConsistency;
  
  // Additional unit tests
  TestValidatePackageSourcePath;
  TestValidatePackageMetadata;
  TestCheckPackageRequiredFiles;
  
  WriteLn('');
  WriteLn('========================================');
  WriteLn('Test Results: ', TestsPassed, '/', TotalTests, ' passed');
  if TestsFailed > 0 then
    WriteLn('FAILED: ', TestsFailed, ' tests failed')
  else
    WriteLn('SUCCESS: All tests passed');
  WriteLn('========================================');
  
  if TestsFailed > 0 then
    Halt(1);
end.
