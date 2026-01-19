program test_package_validate;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser, fpdev.cmd.package.validate;

type
  { TPackageValidateTest }
  TPackageValidateTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestDataDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestDirectory(const ADirName: string);
    procedure CreateTestFile(const AFileName, AContent: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for package validation (Red Phase - these will fail initially)
    procedure TestValidateMetadataSuccess;
    procedure TestValidateMetadataMissingFields;
    procedure TestValidateMetadataInvalidVersion;
    procedure TestValidateFilesSuccess;
    procedure TestValidateFilesMissing;
    procedure TestValidateDependenciesSuccess;
    procedure TestValidateDependenciesInvalidFormat;
    procedure TestValidateLicenseExists;
    procedure TestValidateLicenseMissing;
    procedure TestValidateReadmeExists;
    procedure TestValidateReadmeMissing;
    procedure TestValidateSensitiveFiles;
    procedure TestValidateCompletePackage;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageValidateTest }

constructor TPackageValidateTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test data directory
  FTestDataDir := 'test_package_validate_data';
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);
end;

destructor TPackageValidateTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageValidateTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageValidateTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageValidateTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageValidateTest.CreateTestDirectory(const ADirName: string);
var
  FullPath: string;
begin
  FullPath := FTestDataDir + PathDelim + ADirName;
  if not DirectoryExists(FullPath) then
    ForceDirectories(FullPath);
end;

procedure TPackageValidateTest.CreateTestFile(const AFileName, AContent: string);
var
  F: TextFile;
  FullPath: string;
begin
  FullPath := FTestDataDir + PathDelim + AFileName;
  AssignFile(F, FullPath);
  try
    Rewrite(F);
    Write(F, AContent);
  finally
    CloseFile(F);
  end;
end;

procedure TPackageValidateTest.CleanupTestFiles;

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
  if DirectoryExists(FTestDataDir) then
    DeleteDirectory(FTestDataDir);
end;

procedure TPackageValidateTest.TestValidateMetadataSuccess;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Metadata Success ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create valid package.json
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test package","author":"Test Author","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.ValidateMetadata, 'Should validate metadata successfully');
    AssertTrue(not Validator.HasErrors, 'Should have no errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateMetadataMissingFields;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Metadata Missing Fields ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with missing required fields
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateMetadata, 'Should fail validation for missing fields');
    AssertTrue(Validator.HasErrors, 'Should have errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateMetadataInvalidVersion;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Metadata Invalid Version ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with invalid version
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"invalid","description":"Test","author":"Test","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateMetadata, 'Should fail validation for invalid version');
    AssertTrue(Validator.HasErrors, 'Should have errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateFilesSuccess;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Files Success ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with files array
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT","files":["src/test.pas"]}');
  CreateTestDirectory('src');
  CreateTestFile('src' + PathDelim + 'test.pas', 'unit test;');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.ValidateFiles, 'Should validate files successfully');
    AssertTrue(not Validator.HasErrors, 'Should have no errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateFilesMissing;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Files Missing ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with files array pointing to non-existent file
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT","files":["src/missing.pas"]}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateFiles, 'Should fail validation for missing files');
    AssertTrue(Validator.HasErrors, 'Should have errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateDependenciesSuccess;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Dependencies Success ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with valid dependencies
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT","dependencies":{"libfoo":">=1.0.0","libbar":"^2.0.0"}}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.ValidateDependencies, 'Should validate dependencies successfully');
    AssertTrue(not Validator.HasErrors, 'Should have no errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateDependenciesInvalidFormat;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Dependencies Invalid Format ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with invalid dependency format
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT","dependencies":{"libfoo":"invalid-version"}}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateDependencies, 'Should fail validation for invalid dependency format');
    AssertTrue(Validator.HasErrors, 'Should have errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateLicenseExists;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate License Exists ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create LICENSE file
  CreateTestFile('LICENSE', 'MIT License');
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.ValidateLicense, 'Should validate LICENSE file exists');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateLicenseMissing;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate License Missing ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json without LICENSE file
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateLicense, 'Should fail validation for missing LICENSE');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateReadmeExists;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate README Exists ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create README.md file
  CreateTestFile('README.md', '# Test Package');
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.ValidateReadme, 'Should validate README.md file exists');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateReadmeMissing;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate README Missing ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json without README.md file
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    // README is optional, so validation should still pass (just with a warning)
    AssertTrue(Validator.ValidateReadme, 'Should pass validation even without README (warning only)');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateSensitiveFiles;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Sensitive Files ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create package.json with sensitive files in files array
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test","author":"Test","license":"MIT","files":[".env","credentials.json"]}');
  CreateTestFile('.env', 'SECRET=123');
  CreateTestFile('credentials.json', '{"key":"secret"}');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(not Validator.ValidateSensitiveFiles, 'Should fail validation for sensitive files');
    AssertTrue(Validator.HasErrors, 'Should have errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.TestValidateCompletePackage;
var
  Validator: TPackageValidator;
begin
  WriteLn;
  WriteLn('=== Test: Validate Complete Package ===');

  // Clean up first
  CleanupTestFiles;
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create complete valid package
  CreateTestFile('package.json',
    '{"name":"testpkg","version":"1.0.0","description":"Test package","author":"Test Author","license":"MIT","files":["src/test.pas"]}');
  CreateTestDirectory('src');
  CreateTestFile('src' + PathDelim + 'test.pas', 'unit test;');
  CreateTestFile('LICENSE', 'MIT License');
  CreateTestFile('README.md', '# Test Package');

  Validator := TPackageValidator.Create(FTestDataDir);
  try
    AssertTrue(Validator.Validate, 'Should validate complete package successfully');
    AssertTrue(not Validator.HasErrors, 'Should have no errors');
  finally
    Validator.Free;
  end;
end;

procedure TPackageValidateTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Validation Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestValidateMetadataSuccess;
  TestValidateMetadataMissingFields;
  TestValidateMetadataInvalidVersion;
  TestValidateFilesSuccess;
  TestValidateFilesMissing;
  TestValidateDependenciesSuccess;
  TestValidateDependenciesInvalidFormat;
  TestValidateLicenseExists;
  TestValidateLicenseMissing;
  TestValidateReadmeExists;
  TestValidateReadmeMissing;
  TestValidateSensitiveFiles;
  TestValidateCompletePackage;

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
    WriteLn('Next step: Implement package validation features (Green Phase)');
  end;
end;

var
  Test: TPackageValidateTest;
begin
  Test := TPackageValidateTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
