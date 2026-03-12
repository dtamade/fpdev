program test_package_resolver_integration;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpjson, jsonparser,
  fpdev.package.metadata,
  fpdev.package.resolver, fpdev.utils.fs;

type
  { TPackageResolverIntegrationTest }
  TPackageResolverIntegrationTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestRootDir: string;
    FTestDataDir: string;
    FLockFilePath: string;
    FOriginalDir: string;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestPackageJSON(const AName, AVersion: string; const ADeps: array of string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Integration test methods
    procedure TestResolveSimplePackage;
    procedure TestResolveChainedDependencies;
    procedure TestResolveDiamondDependency;
    procedure TestDetectCircularDependency;
    procedure TestMissingPackageError;
    procedure TestEmptyPackage;
    procedure TestLockFileContainsRealSHA256;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageResolverIntegrationTest }

constructor TPackageResolverIntegrationTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  FTestRootDir := IncludeTrailingPathDelimiter(GetTempDir(False))
    + 'fpdev-package-resolver-' + IntToStr(GetTickCount64);
  FTestDataDir := IncludeTrailingPathDelimiter(FTestRootDir) + 'packages';
  FLockFilePath := IncludeTrailingPathDelimiter(FTestRootDir) + 'fpdev-lock.json';
  FOriginalDir := GetCurrentDir;

  AssertTrue(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(FTestDataDir)) = 1,
    'Test data dir should live under system temp'
  );

  ForceDirectories(FTestDataDir);
  if not SetCurrentDir(FTestRootDir) then
    raise Exception.Create('Failed to change current directory to test root: ' + FTestRootDir);
end;

destructor TPackageResolverIntegrationTest.Destroy;
begin
  if (FOriginalDir <> '') and DirectoryExists(FOriginalDir) then
    SetCurrentDir(FOriginalDir);
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageResolverIntegrationTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageResolverIntegrationTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageResolverIntegrationTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageResolverIntegrationTest.CreateTestPackageJSON(const AName, AVersion: string; const ADeps: array of string);
var
  F: TextFile;
  FilePath: string;
  I: Integer;
  JSONContent: string;
begin
  FilePath := FTestDataDir + PathDelim + AName + '.json';

  // Build JSON content
  JSONContent := '{' + LineEnding;
  JSONContent := JSONContent + '  "name": "' + AName + '",' + LineEnding;
  JSONContent := JSONContent + '  "version": "' + AVersion + '"';

  if Length(ADeps) > 0 then
  begin
    JSONContent := JSONContent + ',' + LineEnding;
    JSONContent := JSONContent + '  "dependencies": {' + LineEnding;

    for I := 0 to High(ADeps) div 2 do
    begin
      JSONContent := JSONContent + '    "' + ADeps[I * 2] + '": "' + ADeps[I * 2 + 1] + '"';
      if I < High(ADeps) div 2 then
        JSONContent := JSONContent + ',';
      JSONContent := JSONContent + LineEnding;
    end;

    JSONContent := JSONContent + '  }' + LineEnding;
  end
  else
    JSONContent := JSONContent + LineEnding;

  JSONContent := JSONContent + '}' + LineEnding;

  // Write to file
  AssignFile(F, FilePath);
  try
    Rewrite(F);
    Write(F, JSONContent);
  finally
    CloseFile(F);
  end;
end;

procedure TPackageResolverIntegrationTest.CleanupTestFiles;
begin
  if (FLockFilePath <> '') and FileExists(FLockFilePath) then
    DeleteFile(FLockFilePath);

  if (FTestRootDir <> '') and DirectoryExists(FTestRootDir) then
    DeleteDirRecursive(FTestRootDir);
end;

procedure TPackageResolverIntegrationTest.TestResolveSimplePackage;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  WriteLn;
  WriteLn('=== Test: Resolve Simple Package ===');

  // Create test packages:
  // mylib 1.0.0 -> libfoo 1.2.3
  CreateTestPackageJSON('mylib', '1.0.0', ['libfoo', '>=1.2.0']);
  CreateTestPackageJSON('libfoo', '1.2.3', []);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(Result.Success, 'Resolution should succeed');
    AssertEqualsInt(2, Length(Result.InstallOrder), 'Should resolve 2 packages');
    AssertEquals('libfoo', Result.InstallOrder[0], 'libfoo should be installed first');
    AssertEquals('mylib', Result.InstallOrder[1], 'mylib should be installed second');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestResolveChainedDependencies;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  WriteLn;
  WriteLn('=== Test: Resolve Chained Dependencies ===');

  // Create test packages:
  // mylib 1.0.0 -> libfoo 1.2.3 -> libbar 2.1.0
  CreateTestPackageJSON('mylib', '1.0.0', ['libfoo', '>=1.2.0']);
  CreateTestPackageJSON('libfoo', '1.2.3', ['libbar', '>=2.0.0']);
  CreateTestPackageJSON('libbar', '2.1.0', []);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(Result.Success, 'Resolution should succeed');
    AssertEqualsInt(3, Length(Result.InstallOrder), 'Should resolve 3 packages');
    AssertEquals('libbar', Result.InstallOrder[0], 'libbar should be installed first');
    AssertEquals('libfoo', Result.InstallOrder[1], 'libfoo should be installed second');
    AssertEquals('mylib', Result.InstallOrder[2], 'mylib should be installed third');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestResolveDiamondDependency;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
  CommonCount: Integer;
  I: Integer;
begin
  WriteLn;
  WriteLn('=== Test: Resolve Diamond Dependency ===');

  // Create test packages with diamond dependency:
  // mylib 1.0.0 -> libfoo 1.2.3 -> libcommon 1.0.0
  //             -> libbar 2.1.0 -> libcommon 1.0.0
  CreateTestPackageJSON('mylib', '1.0.0', ['libfoo', '>=1.2.0', 'libbar', '>=2.0.0']);
  CreateTestPackageJSON('libfoo', '1.2.3', ['libcommon', '>=1.0.0']);
  CreateTestPackageJSON('libbar', '2.1.0', ['libcommon', '>=1.0.0']);
  CreateTestPackageJSON('libcommon', '1.0.0', []);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(Result.Success, 'Resolution should succeed');
    AssertEqualsInt(4, Length(Result.InstallOrder), 'Should resolve 4 packages');

    // libcommon should appear only once
    CommonCount := 0;
    for I := 0 to High(Result.InstallOrder) do
      if Result.InstallOrder[I] = 'libcommon' then
        Inc(CommonCount);

    AssertEqualsInt(1, CommonCount, 'libcommon should appear only once');
    AssertEquals('libcommon', Result.InstallOrder[0], 'libcommon should be installed first');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestDetectCircularDependency;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  WriteLn;
  WriteLn('=== Test: Detect Circular Dependency ===');

  // Create test packages with circular dependency:
  // mylib 1.0.0 -> libfoo 1.2.3 -> libbar 2.1.0 -> mylib 1.0.0
  CreateTestPackageJSON('mylib', '1.0.0', ['libfoo', '>=1.2.0']);
  CreateTestPackageJSON('libfoo', '1.2.3', ['libbar', '>=2.0.0']);
  CreateTestPackageJSON('libbar', '2.1.0', ['mylib', '>=1.0.0']);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(not Result.Success, 'Resolution should fail for circular dependency');
    AssertTrue(Result.HasCircularDependency, 'Should detect circular dependency');
    AssertTrue(Result.ErrorMessage <> '', 'Should have error message');
    AssertTrue(Pos('circular', LowerCase(Result.ErrorMessage)) > 0, 'Error message should mention circular dependency');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestMissingPackageError;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  WriteLn;
  WriteLn('=== Test: Missing Package Error ===');

  // Create test package that depends on non-existent package
  CreateTestPackageJSON('mylib', '1.0.0', ['nonexistent', '>=1.0.0']);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(not Result.Success, 'Resolution should fail for missing package');
    AssertTrue(Result.ErrorMessage <> '', 'Should have error message');
    AssertTrue(Pos('not found', LowerCase(Result.ErrorMessage)) > 0, 'Error message should mention package not found');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestEmptyPackage;
var
  Resolver: TPackageResolver;
  Result: TPackageResolveResult;
begin
  WriteLn;
  WriteLn('=== Test: Empty Package (No Dependencies) ===');

  // Create test package with no dependencies
  CreateTestPackageJSON('mylib', '1.0.0', []);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    Result := Resolver.Resolve('mylib');

    AssertTrue(Result.Success, 'Resolution should succeed');
    AssertEqualsInt(1, Length(Result.InstallOrder), 'Should resolve only the package itself');
    AssertEquals('mylib', Result.InstallOrder[0], 'Should return the package name');
  finally
    Resolver.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.TestLockFileContainsRealSHA256;
var
  Resolver: TPackageResolver;
  ResolveResult: TPackageResolveResult;
  LockJsonStr: string;
  JSONData: TJSONData;
  RootObj: TJSONObject;
  PackagesObj: TJSONObject;
  PkgObj: TJSONObject;
  Integrity: string;
begin
  WriteLn;
  WriteLn('=== Test: Lock File Contains Real SHA256 ===');

  CreateTestPackageJSON('mylib', '1.0.0', ['libfoo', '>=1.2.0']);
  CreateTestPackageJSON('libfoo', '1.2.3', []);

  Resolver := TPackageResolver.Create(FTestDataDir);
  try
    ResolveResult := Resolver.Resolve('mylib');
    AssertTrue(ResolveResult.Success, 'Resolution should succeed before lock integrity verification');
  finally
    Resolver.Free;
  end;

  AssertTrue(
    Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
      ExpandFileName(FLockFilePath)) = 1,
    'Lock file should live under system temp'
  );
  AssertTrue(FileExists(FLockFilePath), 'Lock file should be generated');

  with TStringList.Create do
  try
    LoadFromFile(FLockFilePath);
    LockJsonStr := Text;
  finally
    Free;
  end;

  JSONData := GetJSON(LockJsonStr);
  try
    AssertTrue(JSONData is TJSONObject, 'Lock file root should be JSON object');
    if not (JSONData is TJSONObject) then Exit;

    RootObj := TJSONObject(JSONData);
    AssertTrue(RootObj.Find('packages', PackagesObj), 'Lock file should contain packages field');
    if not RootObj.Find('packages', PackagesObj) then Exit;

    AssertTrue(PackagesObj.Find('mylib', PkgObj), 'Lock file should contain mylib package');
    if not PackagesObj.Find('mylib', PkgObj) then Exit;

    Integrity := PkgObj.Get('integrity', '');
    AssertTrue(Integrity <> '', 'Integrity should not be empty');
    AssertTrue(Pos('placeholder', LowerCase(Integrity)) = 0, 'Integrity should not use placeholder value');
    AssertEqualsInt(64, Length(Integrity), 'Integrity should be SHA256 hex length (64)');
  finally
    JSONData.Free;
  end;
end;

procedure TPackageResolverIntegrationTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Resolver Integration Tests');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestResolveSimplePackage;
  TestResolveChainedDependencies;
  TestResolveDiamondDependency;
  TestDetectCircularDependency;
  TestMissingPackageError;
  TestEmptyPackage;
  TestLockFileContainsRealSHA256;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Test Summary:');
  WriteLn('  Passed: ', FTestsPassed);
  WriteLn('  Failed: ', FTestsFailed);
  WriteLn('  Total:  ', FTestsPassed + FTestsFailed);
  WriteLn('========================================');

  if FTestsFailed = 0 then
    WriteLn('SUCCESS: All integration tests passed!')
  else
    WriteLn('FAILURE: Some integration tests failed!');
end;

var
  Test: TPackageResolverIntegrationTest;
begin
  Test := TPackageResolverIntegrationTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
