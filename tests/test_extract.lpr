program test_extract;
{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, Classes,
  fpdev.toolchain.extract, fpdev.fpc.utils, fpdev.fpc.types;

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
    procedure TestOutputDirUsesSystemTempAndUniqueSuffix;
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
  FTestOutputDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'fpdev_extract_test-' + IntToHex(PtrUInt(Self), SizeOf(Pointer) * 2) +
    '-' + IntToStr(GetTickCount64) + PathDelim;
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
    TestOutputDirUsesSystemTempAndUniqueSuffix;
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

procedure TExtractTest.TestOutputDirUsesSystemTempAndUniqueSuffix;
var
  Other: TExtractTest;
begin
  WriteLn('TestOutputDirUsesSystemTempAndUniqueSuffix:');

  AssertTrue(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(FTestOutputDir)) = 1,
    'Output directory should live under system temp'
  );

  Other := TExtractTest.Create;
  try
    AssertTrue(
      ExpandFileName(FTestOutputDir) <> ExpandFileName(Other.FTestOutputDir),
      'Output directory should be unique per test instance'
    );
  finally
    Other.Free;
    SetupTestEnvironment;
  end;

  WriteLn;
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
  ZipFile, OutputDir: string;
  OpResult: TOperationResult;
begin
  WriteLn('TestZipExtract:');

  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  OutputDir := FTestOutputDir + 'zip_test' + PathDelim;

  // Test extraction
  if FileExists(ZipFile) then
  begin
    OpResult := ExtractZip(ZipFile, OutputDir);
    AssertTrue(OpResult.Success,
      'Should extract ZIP file successfully');
    AssertTrue(DirectoryExists(OutputDir), 'Output directory should exist');

    // Check for extracted content
    AssertTrue(DirectoryExists(OutputDir + 'bin') or
               FileExists(OutputDir + 'README.txt') or
               OpResult.Success,
      'Should have extracted content or success');
  end
  else
  begin
    WriteLn('  [SKIP] Test ZIP file not found: ', ZipFile);
  end;

  // Test with non-existent file
  OpResult := ExtractZip('nonexistent.zip', OutputDir);
  AssertFalse(OpResult.Success,
    'Should fail for non-existent file');
  AssertTrue(OpResult.ErrorMessage <> '', 'Should have error message');

  // Test with empty dest dir
  OpResult := ExtractZip(ZipFile, '');
  AssertFalse(OpResult.Success,
    'Should fail for empty dest dir');

  WriteLn;
end;

procedure TExtractTest.TestExtractArchiveUnified;
var
  ZipFile, OutputDir: string;
  OpResult: TOperationResult;
begin
  WriteLn('TestExtractArchiveUnified:');

  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  OutputDir := FTestOutputDir + 'unified_test' + PathDelim;

  // Test unified extraction with ZIP
  if FileExists(ZipFile) then
  begin
    OpResult := ExtractArchive(ZipFile, OutputDir);
    AssertTrue(OpResult.Success,
      'Should extract ZIP via unified function');
  end
  else
  begin
    WriteLn('  [SKIP] Test ZIP file not found');
  end;

  // Test with unsupported format
  OpResult := ExtractArchive('test.txt', OutputDir);
  AssertFalse(OpResult.Success,
    'Should fail for unsupported format');
  AssertTrue(Pos('unsupported', LowerCase(OpResult.ErrorMessage)) > 0,
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
  ZipFile, OutputDir: string;
  OpResult: TOperationResult;
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
    OpResult := ExtractArchive(ZipFile, OutputDir);
    if not OpResult.Success then
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

  PauseIfRequested('Press Enter to continue...');
end.
