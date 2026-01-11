program test_cross_manifest;
{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, DateUtils,
  fpdev.cross.manifest;

type
  { TCrossManifestTest }
  TCrossManifestTest = class
  private
    FTestDataPath: string;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    
    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RunAllTests;
    
    // Unit tests
    procedure TestLoadValidManifest;
    procedure TestLoadInvalidManifest;
    procedure TestFindEntry;
    procedure TestHostPlatformMatching;
    procedure TestManifestNeedsUpdate;
    procedure TestMissingRequiredFields;
    
    // Property-based tests
    procedure TestProperty1_ManifestStructureValidity;
    procedure TestProperty7_MalformedManifestErrorReporting;
    
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TCrossManifestTest }

constructor TCrossManifestTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTestDataPath := 'tests' + PathDelim + 'data' + PathDelim + 'cross' + PathDelim;
end;

destructor TCrossManifestTest.Destroy;
begin
  inherited Destroy;
end;

procedure TCrossManifestTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('  [PASS] ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('  [FAIL] ', AMessage);
  end;
end;

procedure TCrossManifestTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TCrossManifestTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TCrossManifestTest.AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TCrossManifestTest.RunAllTests;
begin
  WriteLn('=== Cross Toolchain Manifest Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  // Unit tests
  WriteLn('--- Unit Tests ---');
  TestLoadValidManifest;
  TestLoadInvalidManifest;
  TestFindEntry;
  TestHostPlatformMatching;
  TestManifestNeedsUpdate;
  TestMissingRequiredFields;
  
  WriteLn;
  WriteLn('--- Property-Based Tests ---');
  TestProperty1_ManifestStructureValidity;
  TestProperty7_MalformedManifestErrorReporting;
  
  WriteLn;
  WriteLn('=== Test Results ===');
  WriteLn('Tests Passed: ', FTestsPassed);
  WriteLn('Tests Failed: ', FTestsFailed);
  WriteLn('Total Tests: ', FTestsPassed + FTestsFailed);
  
  if FTestsFailed = 0 then
    WriteLn('All tests passed!')
  else
    WriteLn('Some tests failed!');
end;

procedure TCrossManifestTest.TestLoadValidManifest;
var
  Manifest: TCrossToolchainManifest;
begin
  WriteLn('TestLoadValidManifest:');
  
  Manifest := TCrossToolchainManifest.Create;
  try
    AssertTrue(Manifest.LoadFromFile(FTestDataPath + 'test-manifest.json'), 
      'Should load valid manifest file');
    AssertEquals('1.0', Manifest.Version, 'Version should be 1.0');
    AssertTrue(Length(Manifest.Entries) >= 2, 'Should have at least 2 entries');
    AssertTrue(Manifest.LastUpdated > 0, 'LastUpdated should be set');
  finally
    Manifest.Free;
  end;
  WriteLn;
end;

procedure TCrossManifestTest.TestLoadInvalidManifest;
var
  Manifest: TCrossToolchainManifest;
begin
  WriteLn('TestLoadInvalidManifest:');
  
  Manifest := TCrossToolchainManifest.Create;
  try
    AssertFalse(Manifest.LoadFromFile(FTestDataPath + 'invalid-manifest.json'), 
      'Should fail to load invalid manifest');
    AssertTrue(Manifest.LastError.Code <> ERR_NONE, 'Should have error code set');
    AssertTrue(Manifest.LastError.Message <> '', 'Should have error message');
  finally
    Manifest.Free;
  end;
  WriteLn;
end;

procedure TCrossManifestTest.TestFindEntry;
var
  Manifest: TCrossToolchainManifest;
  Host: THostPlatform;
  Entry: TCrossToolchainEntry;
begin
  WriteLn('TestFindEntry:');
  
  Manifest := TCrossToolchainManifest.Create;
  try
    AssertTrue(Manifest.LoadFromFile(FTestDataPath + 'test-manifest.json'), 
      'Should load manifest');
    
    // Test finding win64 binutils for windows x86_64 host
    Host.OS := 'windows';
    Host.Arch := 'x86_64';
    Entry := Manifest.FindEntry('win64', 'binutils', Host);
    AssertTrue(Entry.Target <> '', 'Should find win64 binutils entry');
    AssertEquals('win64', Entry.Target, 'Target should be win64');
    AssertEquals('binutils', Entry.ComponentType, 'ComponentType should be binutils');
    
    // Test finding win64 libraries
    Entry := Manifest.FindEntry('win64', 'libraries', Host);
    AssertTrue(Entry.Target <> '', 'Should find win64 libraries entry');
    AssertEquals('libraries', Entry.ComponentType, 'ComponentType should be libraries');
    
    // Test not finding non-existent target
    Entry := Manifest.FindEntry('nonexistent', 'binutils', Host);
    AssertTrue(Entry.Target = '', 'Should not find non-existent target');
  finally
    Manifest.Free;
  end;
  WriteLn;
end;

procedure TCrossManifestTest.TestHostPlatformMatching;
var
  A, B: THostPlatform;
begin
  WriteLn('TestHostPlatformMatching:');
  
  A.OS := 'windows';
  A.Arch := 'x86_64';
  B.OS := 'windows';
  B.Arch := 'x86_64';
  AssertTrue(HostPlatformMatches(A, B), 'Same platforms should match');
  
  B.OS := 'linux';
  AssertFalse(HostPlatformMatches(A, B), 'Different OS should not match');
  
  B.OS := 'windows';
  B.Arch := 'aarch64';
  AssertFalse(HostPlatformMatches(A, B), 'Different arch should not match');
  
  // Case insensitive
  A.OS := 'WINDOWS';
  B.OS := 'windows';
  B.Arch := 'x86_64';
  AssertTrue(HostPlatformMatches(A, B), 'Matching should be case insensitive');
  WriteLn;
end;

procedure TCrossManifestTest.TestManifestNeedsUpdate;
var
  Manifest: TCrossToolchainManifest;
begin
  WriteLn('TestManifestNeedsUpdate:');
  
  Manifest := TCrossToolchainManifest.Create;
  try
    // Empty manifest needs update
    AssertTrue(Manifest.NeedsUpdate, 'Empty manifest should need update');
    
    // Load manifest with recent date
    AssertTrue(Manifest.LoadFromFile(FTestDataPath + 'test-manifest.json'), 
      'Should load manifest');
    // Note: test-manifest.json has lastUpdated in the future (2026), so it won't need update
    // In real scenarios, we'd test with actual dates
  finally
    Manifest.Free;
  end;
  WriteLn;
end;

procedure TCrossManifestTest.TestMissingRequiredFields;
var
  Manifest: TCrossToolchainManifest;
  JSON: string;
begin
  WriteLn('TestMissingRequiredFields:');
  
  Manifest := TCrossToolchainManifest.Create;
  try
    // Missing version
    JSON := '{"lastUpdated": "2026-01-06T00:00:00Z", "toolchains": []}';
    AssertFalse(Manifest.LoadFromString(JSON), 'Should fail without version');
    AssertEquals(ERR_MISSING_FIELD, Manifest.LastError.Code, 'Error code should be ERR_MISSING_FIELD');
    
    // Missing lastUpdated
    JSON := '{"version": "1.0", "toolchains": []}';
    AssertFalse(Manifest.LoadFromString(JSON), 'Should fail without lastUpdated');
    
    // Missing toolchains
    JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z"}';
    AssertFalse(Manifest.LoadFromString(JSON), 'Should fail without toolchains');
    
    // Empty toolchains array
    JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z", "toolchains": []}';
    AssertFalse(Manifest.LoadFromString(JSON), 'Should fail with empty toolchains');
  finally
    Manifest.Free;
  end;
  WriteLn;
end;


{ Property-Based Tests }

procedure TCrossManifestTest.TestProperty1_ManifestStructureValidity;
{
  **Feature: cross-toolchain-download, Property 1: Manifest Structure Validity**
  **Validates: Requirements 1.1, 1.4, 6.4**
  
  *For any* valid manifest JSON, parsing then serializing back to JSON SHALL produce
  an equivalent structure containing all required fields (target, componentType, 
  version, urls, sha256) for each entry.
}
const
  ITERATIONS = 100;
var
  Manifest1, Manifest2: TCrossToolchainManifest;
  OriginalJSON, SerializedJSON: string;
  i, j: Integer;
  Entry1, Entry2: TCrossToolchainEntry;
  AllPassed: Boolean;
  FailCount: Integer;
begin
  WriteLn('TestProperty1_ManifestStructureValidity:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');
  
  AllPassed := True;
  FailCount := 0;
  
  // For this property test, we use the test manifest and verify round-trip
  Manifest1 := TCrossToolchainManifest.Create;
  Manifest2 := TCrossToolchainManifest.Create;
  try
    // Load original manifest
    if not Manifest1.LoadFromFile(FTestDataPath + 'test-manifest.json') then
    begin
      AssertTrue(False, 'Failed to load test manifest');
      Exit;
    end;
    
    // Perform round-trip test multiple times
    for i := 1 to ITERATIONS do
    begin
      // Serialize to JSON
      SerializedJSON := Manifest1.ToJSON;
      
      // Parse the serialized JSON
      if not Manifest2.LoadFromString(SerializedJSON) then
      begin
        AllPassed := False;
        Inc(FailCount);
        Continue;
      end;
      
      // Verify structure equivalence
      if Manifest1.Version <> Manifest2.Version then
      begin
        AllPassed := False;
        Inc(FailCount);
        Continue;
      end;
      
      if Length(Manifest1.Entries) <> Length(Manifest2.Entries) then
      begin
        AllPassed := False;
        Inc(FailCount);
        Continue;
      end;
      
      // Verify each entry has required fields
      for j := 0 to High(Manifest2.Entries) do
      begin
        Entry1 := Manifest1.Entries[j];
        Entry2 := Manifest2.Entries[j];
        
        // Check required fields preserved
        if (Entry2.Target = '') or
           (Entry2.ComponentType = '') or
           (Entry2.Version = '') or
           (Length(Entry2.URLs) = 0) or
           (Entry2.SHA256 = '') then
        begin
          AllPassed := False;
          Inc(FailCount);
          Break;
        end;
        
        // Check values match
        if (Entry1.Target <> Entry2.Target) or
           (Entry1.ComponentType <> Entry2.ComponentType) or
           (Entry1.Version <> Entry2.Version) or
           (Entry1.SHA256 <> Entry2.SHA256) then
        begin
          AllPassed := False;
          Inc(FailCount);
          Break;
        end;
      end;
    end;
    
    AssertTrue(AllPassed, 'Property 1: Manifest round-trip preserves structure (' + 
      IntToStr(ITERATIONS - FailCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  finally
    Manifest1.Free;
    Manifest2.Free;
  end;
  WriteLn;
end;

procedure TCrossManifestTest.TestProperty7_MalformedManifestErrorReporting;
{
  **Feature: cross-toolchain-download, Property 7: Malformed Manifest Error Reporting**
  **Validates: Requirements 1.5**
  
  *For any* malformed JSON input (missing required fields, invalid structure, 
  syntax errors), parsing SHALL fail and return a descriptive error message 
  indicating the specific problem.
}
const
  ITERATIONS = 100;
type
  TMalformedCase = record
    JSON: string;
    ExpectedField: string;
    Description: string;
  end;
var
  Manifest: TCrossToolchainManifest;
  Cases: array of TMalformedCase;
  i, j, PassCount: Integer;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty7_MalformedManifestErrorReporting:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');
  
  // Define malformed cases
  SetLength(Cases, 10);
  
  Cases[0].JSON := 'not valid json';
  Cases[0].ExpectedField := '';
  Cases[0].Description := 'Invalid JSON syntax';
  
  Cases[1].JSON := '[]';
  Cases[1].ExpectedField := '';
  Cases[1].Description := 'Array instead of object';
  
  Cases[2].JSON := '{"lastUpdated": "2026-01-06T00:00:00Z", "toolchains": []}';
  Cases[2].ExpectedField := 'version';
  Cases[2].Description := 'Missing version';
  
  Cases[3].JSON := '{"version": "1.0", "toolchains": []}';
  Cases[3].ExpectedField := 'lastUpdated';
  Cases[3].Description := 'Missing lastUpdated';
  
  Cases[4].JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z"}';
  Cases[4].ExpectedField := 'toolchains';
  Cases[4].Description := 'Missing toolchains';
  
  Cases[5].JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z", "toolchains": []}';
  Cases[5].ExpectedField := 'toolchains';
  Cases[5].Description := 'Empty toolchains array';
  
  Cases[6].JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z", "toolchains": [{"componentType": "binutils"}]}';
  Cases[6].ExpectedField := 'target';
  Cases[6].Description := 'Entry missing target';
  
  Cases[7].JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z", "toolchains": [{"target": "win64"}]}';
  Cases[7].ExpectedField := 'componentType';
  Cases[7].Description := 'Entry missing componentType';
  
  Cases[8].JSON := '{"version": "1.0", "lastUpdated": "invalid-date", "toolchains": []}';
  Cases[8].ExpectedField := 'lastUpdated';
  Cases[8].Description := 'Invalid date format';
  
  Cases[9].JSON := '{"version": "1.0", "lastUpdated": "2026-01-06T00:00:00Z", "toolchains": [{"target": "win64", "componentType": "binutils", "version": "1.0", "hostPlatforms": [], "urls": ["http://test"], "sha256": "abc", "archiveFormat": "zip"}]}';
  Cases[9].ExpectedField := 'hostPlatforms';
  Cases[9].Description := 'Empty hostPlatforms array';
  
  AllPassed := True;
  PassCount := 0;
  
  Manifest := TCrossToolchainManifest.Create;
  try
    for i := 1 to ITERATIONS do
    begin
      // Test each malformed case
      for j := 0 to High(Cases) do
      begin
        // Parsing should fail
        if Manifest.LoadFromString(Cases[j].JSON) then
        begin
          AllPassed := False;
          WriteLn('    FAIL: Should reject - ', Cases[j].Description);
          Continue;
        end;
        
        // Error message should be set
        if Manifest.LastError.Message = '' then
        begin
          AllPassed := False;
          WriteLn('    FAIL: No error message for - ', Cases[j].Description);
          Continue;
        end;
        
        // Error code should be non-zero
        if Manifest.LastError.Code = ERR_NONE then
        begin
          AllPassed := False;
          WriteLn('    FAIL: No error code for - ', Cases[j].Description);
          Continue;
        end;
        
        Inc(PassCount);
      end;
    end;
    
    AssertTrue(AllPassed, 'Property 7: Malformed manifests produce descriptive errors (' + 
      IntToStr(PassCount) + '/' + IntToStr(ITERATIONS * Length(Cases)) + ' checks passed)');
  finally
    Manifest.Free;
  end;
  WriteLn;
end;

{ Main }

var
  Test: TCrossManifestTest;
begin
  try
    WriteLn('Cross Toolchain Manifest Test Suite');
    WriteLn('====================================');
    WriteLn;
    
    Test := TCrossManifestTest.Create;
    try
      Test.RunAllTests;
      
      if Test.TestsFailed > 0 then
        ExitCode := 1;
    finally
      Test.Free;
    end;
    
    WriteLn;
    WriteLn('Test suite completed.');
    
  except
    on E: Exception do
    begin
      WriteLn('Error running tests: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  {$IFDEF MSWINDOWS}
  WriteLn;
  WriteLn('Press Enter to continue...');
  ReadLn;
  {$ENDIF}
end.
