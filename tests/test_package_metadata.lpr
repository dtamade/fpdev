program test_package_metadata;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes, fpjson, jsonparser,
  fpdev.package.metadata, test_temp_paths;

type
  { TPackageMetadataTest }
  TPackageMetadataTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestDataDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestPackageJSON(const AFileName, AContent: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods (Red Phase - these will fail initially)
    procedure TestParseBasicMetadata;
    procedure TestParseDependencies;
    procedure TestParseVersionConstraints;
    procedure TestParseOptionalDependencies;
    procedure TestValidateMetadata;
    procedure TestInvalidJSON;
    procedure TestMissingRequiredFields;
    procedure TestEmptyDependencies;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageMetadataTest }

constructor TPackageMetadataTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  FTestDataDir := CreateUniqueTempDir('test_metadata_data');
end;

destructor TPackageMetadataTest.Destroy;
begin
  if FTestDataDir <> '' then
  begin
    CleanupTempDir(FTestDataDir);
    FTestDataDir := '';
  end;
  inherited Destroy;
end;

procedure TPackageMetadataTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageMetadataTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageMetadataTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageMetadataTest.CreateTestPackageJSON(const AFileName, AContent: string);
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

procedure TPackageMetadataTest.CleanupTestFiles;
begin
  if FTestDataDir <> '' then
  begin
    CleanupTempDir(FTestDataDir);
    ForceDirectories(FTestDataDir);
  end;
end;

procedure TPackageMetadataTest.TestParseBasicMetadata;
var
  JSONContent: string;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Parse Basic Metadata ===');

  // Create test package.json with basic metadata
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"description": "My awesome library",'
    + '"author": "John Doe <john@example.com>",'
    + '"license": "MIT"'
    + '}';

  CreateTestPackageJSON('basic.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'basic.json');
  try
    AssertEquals('mylib', Meta.Name, 'Package name should be parsed correctly');
    AssertEquals('1.0.0', Meta.Version, 'Package version should be parsed correctly');
    AssertEquals('My awesome library', Meta.Description, 'Package description should be parsed correctly');
    AssertEquals('John Doe <john@example.com>', Meta.Author, 'Package author should be parsed correctly');
    AssertEquals('MIT', Meta.License, 'Package license should be parsed correctly');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.TestParseDependencies;
var
  JSONContent: string;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Parse Dependencies ===');

  // Create test package.json with dependencies
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"dependencies": {'
    + '  "libfoo": ">=1.2.0",'
    + '  "libbar": "^2.0.0"'
    + '}'
    + '}';

  CreateTestPackageJSON('deps.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'deps.json');
  try
    AssertEqualsInt(2, Meta.Dependencies.Count, 'Should have 2 dependencies');
    AssertEquals('>=1.2.0', Meta.Dependencies.KeyData['libfoo'], 'libfoo version constraint should be parsed');
    AssertEquals('^2.0.0', Meta.Dependencies.KeyData['libbar'], 'libbar version constraint should be parsed');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.TestParseVersionConstraints;
var
  JSONContent: string;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Parse Version Constraints ===');

  // Create test package.json with various version constraints
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"dependencies": {'
    + '  "exact": "1.2.3",'
    + '  "gte": ">=1.2.0",'
    + '  "lte": "<=2.0.0",'
    + '  "caret": "^1.2.0",'
    + '  "tilde": "~1.2.0"'
    + '}'
    + '}';

  CreateTestPackageJSON('constraints.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'constraints.json');
  try
    AssertEquals('1.2.3', Meta.Dependencies.KeyData['exact'], 'Exact version should be parsed');
    AssertEquals('>=1.2.0', Meta.Dependencies.KeyData['gte'], 'GTE constraint should be parsed');
    AssertEquals('<=2.0.0', Meta.Dependencies.KeyData['lte'], 'LTE constraint should be parsed');
    AssertEquals('^1.2.0', Meta.Dependencies.KeyData['caret'], 'Caret constraint should be parsed');
    AssertEquals('~1.2.0', Meta.Dependencies.KeyData['tilde'], 'Tilde constraint should be parsed');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.TestParseOptionalDependencies;
var
  JSONContent: string;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Parse Optional Dependencies ===');

  // Create test package.json with optional dependencies
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"dependencies": {'
    + '  "libfoo": ">=1.2.0"'
    + '},'
    + '"optionalDependencies": {'
    + '  "liboptional": "~1.0.0"'
    + '}'
    + '}';

  CreateTestPackageJSON('optional.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'optional.json');
  try
    AssertEqualsInt(1, Meta.Dependencies.Count, 'Should have 1 required dependency');
    AssertEqualsInt(1, Meta.OptionalDependencies.Count, 'Should have 1 optional dependency');
    AssertEquals('~1.0.0', Meta.OptionalDependencies.KeyData['liboptional'], 'Optional dependency should be parsed');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.TestValidateMetadata;
var
  JSONContent: string;
  Meta: TPackageMetadata;
  IsValid: Boolean;
begin
  WriteLn;
  WriteLn('=== Test: Validate Metadata ===');

  // Create test package.json with FPC version constraints
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"fpc": {'
    + '  "minVersion": "3.2.0",'
    + '  "maxVersion": "3.2.2"'
    + '}'
    + '}';

  CreateTestPackageJSON('validate.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'validate.json');
  try
    IsValid := ValidateMetadata(Meta);
    AssertTrue(IsValid, 'Valid metadata should pass validation');
    AssertEquals('3.2.0', Meta.FPCMinVersion, 'FPC min version should be parsed');
    AssertEquals('3.2.2', Meta.FPCMaxVersion, 'FPC max version should be parsed');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.TestInvalidJSON;
var
  JSONContent: string;
  ExceptionRaised: Boolean;
begin
  WriteLn;
  WriteLn('=== Test: Invalid JSON ===');

  // Create test package.json with invalid JSON
  JSONContent := '{ "name": "mylib", "version": "1.0.0" INVALID }';

  CreateTestPackageJSON('invalid.json', JSONContent);

  ExceptionRaised := False;
  try
    LoadMetadata(FTestDataDir + PathDelim + 'invalid.json');
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  AssertTrue(ExceptionRaised, 'Invalid JSON should raise exception');
end;

procedure TPackageMetadataTest.TestMissingRequiredFields;
var
  JSONContent: string;
  ExceptionRaised: Boolean;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Missing Required Fields ===');

  // Create test package.json without required fields (name, version)
  JSONContent := '{ "description": "Missing name and version" }';

  CreateTestPackageJSON('missing.json', JSONContent);

  ExceptionRaised := False;
  try
    Meta := LoadMetadata(FTestDataDir + PathDelim + 'missing.json');
    try
      ValidateMetadata(Meta); // Should raise exception
    finally
      Meta.Free;
    end;
  except
    on E: Exception do
      ExceptionRaised := True;
  end;

  AssertTrue(ExceptionRaised, 'Missing required fields should raise exception');
end;

procedure TPackageMetadataTest.TestEmptyDependencies;
var
  JSONContent: string;
  Meta: TPackageMetadata;
begin
  WriteLn;
  WriteLn('=== Test: Empty Dependencies ===');

  // Create test package.json with empty dependencies object
  JSONContent := '{'
    + '"name": "mylib",'
    + '"version": "1.0.0",'
    + '"dependencies": {}'
    + '}';

  CreateTestPackageJSON('empty_deps.json', JSONContent);

  Meta := LoadMetadata(FTestDataDir + PathDelim + 'empty_deps.json');
  try
    AssertEqualsInt(0, Meta.Dependencies.Count, 'Empty dependencies should result in 0 count');
  finally
    Meta.Free;
  end;
end;

procedure TPackageMetadataTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Metadata Parser Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestParseBasicMetadata;
  TestParseDependencies;
  TestParseVersionConstraints;
  TestParseOptionalDependencies;
  TestValidateMetadata;
  TestInvalidJSON;
  TestMissingRequiredFields;
  TestEmptyDependencies;

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
    WriteLn('RED PHASE: All tests are expected to fail.');
    WriteLn('Next step: Implement fpdev.package.metadata.pas (Green Phase)');
  end;
end;

var
  Test: TPackageMetadataTest;
begin
  Test := TPackageMetadataTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
