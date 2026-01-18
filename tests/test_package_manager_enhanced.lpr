program test_package_manager_enhanced;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.cmd.package,
  fpdev.config.interfaces,
  fpdev.config.managers,
  fpdev.pkg.version;

type
  { TPackageManagerEnhancedTest }
  TPackageManagerEnhancedTest = class
  private
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    FTestDataDir: string;
    FConfigManager: IConfigManager;

    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);

    procedure CreateTestIndexJSON(const AContent: string);
    procedure CleanupTestFiles;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Test methods for enhanced functionality
    procedure TestDependencyWithVersionConstraint;
    procedure TestResolveDependenciesWithVersionValidation;
    procedure TestInstallWithNoDepsFlag;
    procedure TestInstallWithDryRunFlag;
    procedure TestDependencyTreeDisplay;
    procedure TestVersionConstraintParsing;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageManagerEnhancedTest }

constructor TPackageManagerEnhancedTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;

  // Create temporary test data directory
  FTestDataDir := 'test_package_manager_enhanced_data';
  if not DirectoryExists(FTestDataDir) then
    CreateDir(FTestDataDir);

  // Create test config manager
  FConfigManager := TConfigManager.Create(FTestDataDir + PathDelim + 'config.json');
end;

destructor TPackageManagerEnhancedTest.Destroy;
begin
  CleanupTestFiles;
  inherited Destroy;
end;

procedure TPackageManagerEnhancedTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TPackageManagerEnhancedTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageManagerEnhancedTest.AssertEqualsInt(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TPackageManagerEnhancedTest.CreateTestIndexJSON(const AContent: string);
var
  F: TextFile;
  FilePath: string;
begin
  FilePath := FTestDataDir + PathDelim + 'index.json';
  AssignFile(F, FilePath);
  try
    Rewrite(F);
    Write(F, AContent);
  finally
    CloseFile(F);
  end;
end;

procedure TPackageManagerEnhancedTest.CleanupTestFiles;
var
  SR: TSearchRec;
  FilePath: string;
begin
  if DirectoryExists(FTestDataDir) then
  begin
    if FindFirst(FTestDataDir + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      try
        repeat
          if (SR.Name <> '.') and (SR.Name <> '..') then
          begin
            FilePath := FTestDataDir + PathDelim + SR.Name;
            if (SR.Attr and faDirectory) <> 0 then
              RemoveDir(FilePath)
            else
              DeleteFile(FilePath);
          end;
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;
    RemoveDir(FTestDataDir);
  end;
end;

procedure TPackageManagerEnhancedTest.TestDependencyWithVersionConstraint;
var
  JSONContent: string;
begin
  WriteLn;
  WriteLn('=== Test: Dependency With Version Constraint ===');

  // Create test index.json with version constraints in dependencies
  JSONContent := '{' + LineEnding +
    '  "packages": [' + LineEnding +
    '    {' + LineEnding +
    '      "name": "mylib",' + LineEnding +
    '      "version": "1.0.0",' + LineEnding +
    '      "dependencies": ["libfoo>=1.2.0", "libbar^2.0.0"],' + LineEnding +
    '      "url": "http://example.com/mylib.zip"' + LineEnding +
    '    }' + LineEnding +
    '  ]' + LineEnding +
    '}';

  CreateTestIndexJSON(JSONContent);

  // TODO: Test that TPackageManager can parse version constraints from dependencies
  // This test will fail until we implement version constraint parsing
  AssertTrue(False, 'Version constraint parsing not yet implemented');
end;

procedure TPackageManagerEnhancedTest.TestResolveDependenciesWithVersionValidation;
begin
  WriteLn;
  WriteLn('=== Test: Resolve Dependencies With Version Validation ===');

  // TODO: Test that ResolveDependencies validates version constraints
  // This test will fail until we implement version validation
  AssertTrue(False, 'Version validation in ResolveDependencies not yet implemented');
end;

procedure TPackageManagerEnhancedTest.TestInstallWithNoDepsFlag;
begin
  WriteLn;
  WriteLn('=== Test: Install With --no-deps Flag ===');

  // TODO: Test that install command respects --no-deps flag
  // This test will fail until we implement --no-deps flag
  AssertTrue(False, '--no-deps flag not yet implemented');
end;

procedure TPackageManagerEnhancedTest.TestInstallWithDryRunFlag;
begin
  WriteLn;
  WriteLn('=== Test: Install With --dry-run Flag ===');

  // TODO: Test that install command respects --dry-run flag
  // This test will fail until we implement --dry-run flag
  AssertTrue(False, '--dry-run flag not yet implemented');
end;

procedure TPackageManagerEnhancedTest.TestDependencyTreeDisplay;
begin
  WriteLn;
  WriteLn('=== Test: Dependency Tree Display ===');

  // TODO: Test that dependency tree is displayed before installation
  // This test will fail until we implement tree display
  AssertTrue(False, 'Dependency tree display not yet implemented');
end;

procedure TPackageManagerEnhancedTest.TestVersionConstraintParsing;
var
  Constraint: TVersionConstraint;
begin
  WriteLn;
  WriteLn('=== Test: Version Constraint Parsing ===');

  // Test >= operator
  Constraint := ParseVersionConstraint('libfoo>=1.2.0');
  AssertTrue(Constraint.Valid, 'Should parse >= constraint');
  AssertEquals('libfoo', Constraint.PackageName, 'Should extract package name from >= constraint');
  AssertEquals('1.2.0', Constraint.Version, 'Should extract version from >= constraint');
  AssertTrue(Constraint.ConstraintOp = vcoGTE, 'Should identify >= operator');

  // Test <= operator
  Constraint := ParseVersionConstraint('libbar<=2.0.0');
  AssertTrue(Constraint.Valid, 'Should parse <= constraint');
  AssertEquals('libbar', Constraint.PackageName, 'Should extract package name from <= constraint');
  AssertEquals('2.0.0', Constraint.Version, 'Should extract version from <= constraint');
  AssertTrue(Constraint.ConstraintOp = vcoLTE, 'Should identify <= operator');

  // Test ^ operator (caret)
  Constraint := ParseVersionConstraint('libbaz^1.5.0');
  AssertTrue(Constraint.Valid, 'Should parse ^ constraint');
  AssertEquals('libbaz', Constraint.PackageName, 'Should extract package name from ^ constraint');
  AssertEquals('1.5.0', Constraint.Version, 'Should extract version from ^ constraint');
  AssertTrue(Constraint.ConstraintOp = vcoCaret, 'Should identify ^ operator');

  // Test ~ operator (tilde)
  Constraint := ParseVersionConstraint('libqux~2.1.0');
  AssertTrue(Constraint.Valid, 'Should parse ~ constraint');
  AssertEquals('libqux', Constraint.PackageName, 'Should extract package name from ~ constraint');
  AssertEquals('2.1.0', Constraint.Version, 'Should extract version from ~ constraint');
  AssertTrue(Constraint.ConstraintOp = vcoTilde, 'Should identify ~ operator');

  // Test package name only (no version constraint)
  Constraint := ParseVersionConstraint('libplain');
  AssertTrue(Constraint.Valid, 'Should parse package name without version');
  AssertEquals('libplain', Constraint.PackageName, 'Should extract package name without version');
  AssertEquals('', Constraint.Version, 'Should have empty version for package name only');

  // Test version validation
  AssertTrue(ValidateVersion('1.2.5', '>=1.2.0'), 'Version 1.2.5 should satisfy >=1.2.0');
  AssertTrue(ValidateVersion('1.2.0', '>=1.2.0'), 'Version 1.2.0 should satisfy >=1.2.0');
  AssertTrue(not ValidateVersion('1.1.9', '>=1.2.0'), 'Version 1.1.9 should not satisfy >=1.2.0');

  AssertTrue(ValidateVersion('1.9.0', '<=2.0.0'), 'Version 1.9.0 should satisfy <=2.0.0');
  AssertTrue(not ValidateVersion('2.1.0', '<=2.0.0'), 'Version 2.1.0 should not satisfy <=2.0.0');

  // Test caret constraint (^1.2.0 allows 1.x.x but not 2.0.0)
  AssertTrue(ValidateVersion('1.2.5', '^1.2.0'), 'Version 1.2.5 should satisfy ^1.2.0');
  AssertTrue(ValidateVersion('1.9.9', '^1.2.0'), 'Version 1.9.9 should satisfy ^1.2.0');
  AssertTrue(not ValidateVersion('2.0.0', '^1.2.0'), 'Version 2.0.0 should not satisfy ^1.2.0');

  // Test tilde constraint (~1.2.0 allows 1.2.x but not 1.3.0)
  AssertTrue(ValidateVersion('1.2.5', '~1.2.0'), 'Version 1.2.5 should satisfy ~1.2.0');
  AssertTrue(not ValidateVersion('1.3.0', '~1.2.0'), 'Version 1.3.0 should not satisfy ~1.2.0');
end;

procedure TPackageManagerEnhancedTest.RunAllTests;
begin
  WriteLn('========================================');
  WriteLn('Package Manager Enhanced Tests (Red Phase)');
  WriteLn('========================================');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  TestDependencyWithVersionConstraint;
  TestResolveDependenciesWithVersionValidation;
  TestInstallWithNoDepsFlag;
  TestInstallWithDryRunFlag;
  TestDependencyTreeDisplay;
  TestVersionConstraintParsing;

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
    WriteLn('Next step: Implement enhanced package manager features (Green Phase)');
  end;
end;

var
  Test: TPackageManagerEnhancedTest;
begin
  Test := TPackageManagerEnhancedTest.Create;
  try
    Test.RunAllTests;

    // Exit with error code if tests failed (expected in Red phase)
    if Test.TestsFailed > 0 then
      Halt(1);
  finally
    Test.Free;
  end;
end.
