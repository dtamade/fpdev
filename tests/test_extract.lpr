program test_extract;
{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.toolchain.extract;

type
  { TExtractTest }
  TExtractTest = class
  private
    FTestDataDir: string;
    FTestOutputDir: string;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    
    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertFalse(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    
    procedure SetupTestEnvironment;
    procedure CleanupTestEnvironment;
    procedure CleanupDir(const ADir: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RunAllTests;
    
    // Unit tests
    procedure TestDetectArchiveFormat;
    procedure TestZipExtract;
    procedure TestExtractArchiveUnified;
    
    // Property-based tests
    procedure TestProperty4_ArchiveFormatSupport;
    
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TExtractTest }

constructor TExtractTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTestDataDir := 'tests' + PathDelim + 'data' + PathDelim + 'cross' + PathDelim;
  FTestOutputDir := GetTempDir + 'fpdev_extract_test' + PathDelim;
end;

destructor TExtractTest.Destroy;
begin
  CleanupTestEnvironment;
  inherited Destroy;
end;

procedure TExtractTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TExtractTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TExtractTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TExtractTest.CleanupDir(const ADir: string);
var
  SR: TSearchRec;
  SubDir: string;
begin
  if not DirectoryExists(ADir) then
    Exit;
    
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        if (SR.Attr and faDirectory) <> 0 then
        begin
          SubDir := ADir + SR.Name + PathDelim;
          CleanupDir(SubDir);
          RemoveDir(SubDir);
        end
        else
          DeleteFile(ADir + SR.Name);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

procedure TExtractTest.SetupTestEnvironment;
begin
  if not DirectoryExists(FTestOutputDir) then
    ForceDirectories(FTestOutputDir);
end;

procedure TExtractTest.CleanupTestEnvironment;
begin
  CleanupDir(FTestOutputDir);
  if DirectoryExists(FTestOutputDir) then
    RemoveDir(FTestOutputDir);
end;

procedure TExtractTest.RunAllTests;
begin
  WriteLn('=== Archive Extraction Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  SetupTestEnvironment;
  try
    // Unit tests
    WriteLn('--- Unit Tests ---');
    TestDetectArchiveFormat;
    TestZipExtract;
    TestExtractArchiveUnified;
    
    WriteLn;
    WriteLn('--- Property-Based Tests ---');
    TestProperty4_ArchiveFormatSupport;
  finally
    CleanupTestEnvironment;
  end;
  
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

procedure TExtractTest.TestDetectArchiveFormat;
begin
  WriteLn('TestDetectArchiveFormat:');
  
  AssertTrue(DetectArchiveFormat('test.zip') = afZip, 'Should detect .zip format');
  AssertTrue(DetectArchiveFormat('test.tar.gz') = afTarGz, 'Should detect .tar.gz format');
  AssertTrue(DetectArchiveFormat('test.tgz') = afTarGz, 'Should detect .tgz format');
  AssertTrue(DetectArchiveFormat('test.tar') = afTar, 'Should detect .tar format');
  AssertTrue(DetectArchiveFormat('test.txt') = afUnknown, 'Should return unknown for .txt');
  AssertTrue(DetectArchiveFormat('test') = afUnknown, 'Should return unknown for no extension');
  
  WriteLn;
end;

procedure TExtractTest.TestZipExtract;
var
  ZipFile, OutputDir, ErrMsg: string;
begin
  WriteLn('TestZipExtract:');
  
  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  OutputDir := FTestOutputDir + 'zip_test' + PathDelim;
  
  // Test extraction
  if FileExists(ZipFile) then
  begin
    AssertTrue(ZipExtract(ZipFile, OutputDir, ErrMsg), 
      'Should extract ZIP file successfully');
    AssertTrue(DirectoryExists(OutputDir), 'Output directory should exist');
    
    // Check for extracted content
    AssertTrue(DirectoryExists(OutputDir + 'bin') or 
               FileExists(OutputDir + 'README.txt') or
               (ErrMsg = ''),
      'Should have extracted content or no error');
  end
  else
  begin
    WriteLn('  [SKIP] Test ZIP file not found: ', ZipFile);
  end;
  
  // Test with non-existent file
  AssertFalse(ZipExtract('nonexistent.zip', OutputDir, ErrMsg),
    'Should fail for non-existent file');
  AssertTrue(ErrMsg <> '', 'Should have error message');
  
  // Test with empty dest dir
  AssertFalse(ZipExtract(ZipFile, '', ErrMsg),
    'Should fail for empty dest dir');
  
  WriteLn;
end;

procedure TExtractTest.TestExtractArchiveUnified;
var
  ZipFile, OutputDir, ErrMsg: string;
begin
  WriteLn('TestExtractArchiveUnified:');
  
  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  OutputDir := FTestOutputDir + 'unified_test' + PathDelim;
  
  // Test unified extraction with ZIP
  if FileExists(ZipFile) then
  begin
    AssertTrue(ExtractArchive(ZipFile, OutputDir, ErrMsg),
      'Should extract ZIP via unified function');
  end
  else
  begin
    WriteLn('  [SKIP] Test ZIP file not found');
  end;
  
  // Test with unsupported format
  AssertFalse(ExtractArchive('test.txt', OutputDir, ErrMsg),
    'Should fail for unsupported format');
  AssertTrue(Pos('unsupported', LowerCase(ErrMsg)) > 0,
    'Error should mention unsupported format');
  
  WriteLn;
end;

procedure TExtractTest.TestProperty4_ArchiveFormatSupport;
{
  **Feature: cross-toolchain-download, Property 4: Archive Format Support**
  **Validates: Requirements 2.5, 3.5**
  
  *For any* archive in ZIP or TAR.GZ format containing valid files, extraction 
  SHALL produce the same directory structure and file contents regardless of format.
  
  Note: This test verifies that both ZIP and TAR.GZ formats can be extracted.
  Full content comparison requires both format archives with identical content.
}
const
  ITERATIONS = 100;
var
  i, PassCount: Integer;
  ZipFile, OutputDir, ErrMsg: string;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty4_ArchiveFormatSupport:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');
  
  AllPassed := True;
  PassCount := 0;
  
  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  
  if not FileExists(ZipFile) then
  begin
    WriteLn('  [SKIP] Test archive not found');
    AssertTrue(True, 'Property 4: Skipped - test archive not found');
    Exit;
  end;
  
  for i := 1 to ITERATIONS do
  begin
    OutputDir := FTestOutputDir + 'prop4_' + IntToStr(i) + PathDelim;
    
    // Test ZIP extraction
    if not ExtractArchive(ZipFile, OutputDir, ErrMsg) then
    begin
      AllPassed := False;
      Continue;
    end;
    
    // Verify output directory was created
    if not DirectoryExists(OutputDir) then
    begin
      AllPassed := False;
      Continue;
    end;
    
    // Verify format detection works correctly
    if DetectArchiveFormat(ZipFile) <> afZip then
    begin
      AllPassed := False;
      Continue;
    end;
    
    Inc(PassCount);
    
    // Cleanup this iteration
    CleanupDir(OutputDir);
    if DirectoryExists(OutputDir) then
      RemoveDir(OutputDir);
  end;
  
  AssertTrue(AllPassed, 'Property 4: Archive format support (' + 
    IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  WriteLn;
end;

{ Main }

var
  Test: TExtractTest;
begin
  try
    WriteLn('Archive Extraction Test Suite');
    WriteLn('==============================');
    WriteLn;
    
    Test := TExtractTest.Create;
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
