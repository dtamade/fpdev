program test_lazarus_ide_config;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpdev.lazarus.config;

var
  TestRootDir: string;
  TestsPassed: Integer;
  TestsFailed: Integer;

procedure InitTestEnvironment;
begin
  // Create test root directory in temp
  TestRootDir := GetTempDir + 'test_lazarus_ide_config_' + IntToStr(GetTickCount64);
  ForceDirectories(TestRootDir);

  TestsPassed := 0;
  TestsFailed := 0;
end;

procedure CleanupTestEnvironment;
  procedure DeleteDirectory(const DirPath: string);
  var
    SR: TSearchRec;
    FilePath: string;
  begin
    if not DirectoryExists(DirPath) then Exit;

    if FindFirst(DirPath + PathDelim + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          FilePath := DirPath + PathDelim + SR.Name;
          if (SR.Attr and faDirectory) <> 0 then
            DeleteDirectory(FilePath)
          else
            DeleteFile(FilePath);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    RemoveDir(DirPath);
  end;

begin
  if DirectoryExists(TestRootDir) then
    DeleteDirectory(TestRootDir);

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Results: ', TestsPassed, ' passed, ', TestsFailed, ' failed');
  WriteLn('========================================');
end;

procedure AssertTrue(const Condition: Boolean; const TestName, Message: string);
begin
  if Condition then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    Inc(TestsFailed);
  end;
end;

procedure AssertFalse(const Condition: Boolean; const TestName, Message: string);
begin
  AssertTrue(not Condition, TestName, Message);
end;

procedure AssertEquals(const Expected, Actual: string; const TestName, Message: string);
begin
  if Expected = Actual then
  begin
    WriteLn('[PASS] ', TestName);
    Inc(TestsPassed);
  end
  else
  begin
    WriteLn('[FAIL] ', TestName);
    WriteLn('  ', Message);
    WriteLn('  Expected: ', Expected);
    WriteLn('  Actual: ', Actual);
    Inc(TestsFailed);
  end;
end;

// ============================================================================
// Test 1: TLazarusIDEConfig can be created
// ============================================================================
procedure TestIDEConfigCreation;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 1: TLazarusIDEConfig Creation');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test1';
    ForceDirectories(ConfigDir);

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      AssertTrue(Assigned(IDEConfig), 'IDEConfig created',
        'TLazarusIDEConfig should be created successfully');

      AssertEquals(ConfigDir, IDEConfig.ConfigDir, 'ConfigDir property',
        'ConfigDir property should match constructor parameter');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'IDEConfig creation', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 2: SetCompilerPath and GetCompilerPath
// ============================================================================
procedure TestCompilerPathSetGet;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  TestPath, RetrievedPath: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 2: Compiler Path Set/Get');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test2';
    ForceDirectories(ConfigDir);

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      TestPath := '/usr/bin/fpc';

      // Set compiler path
      Success := IDEConfig.SetCompilerPath(TestPath);
      AssertTrue(Success, 'SetCompilerPath succeeds',
        'SetCompilerPath should return True');

      // Get compiler path
      RetrievedPath := IDEConfig.GetCompilerPath;
      AssertEquals(TestPath, RetrievedPath, 'GetCompilerPath returns correct value',
        'Retrieved path should match the set path');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'Compiler path set/get', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 3: BackupConfig creates backup
// ============================================================================
procedure TestBackupConfig;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  BackupPath: string;
  EnvOptionsFile: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 3: BackupConfig Creates Backup');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test3';
    ForceDirectories(ConfigDir);

    // Create a mock environmentoptions.xml
    EnvOptionsFile := ConfigDir + PathDelim + 'environmentoptions.xml';
    with TStringList.Create do
    try
      Add('<?xml version="1.0" encoding="UTF-8"?>');
      Add('<CONFIG>');
      Add('  <EnvironmentOptions>');
      Add('    <CompilerFilename Value="/usr/bin/fpc"/>');
      Add('  </EnvironmentOptions>');
      Add('</CONFIG>');
      SaveToFile(EnvOptionsFile);
    finally
      Free;
    end;

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      // Create backup
      BackupPath := IDEConfig.BackupConfig;

      AssertTrue(BackupPath <> '', 'BackupConfig returns path',
        'BackupConfig should return non-empty backup path');

      AssertTrue(DirectoryExists(BackupPath), 'Backup directory exists',
        'Backup directory should be created');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'BackupConfig', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 4: ValidateConfig checks configuration
// ============================================================================
procedure TestValidateConfig;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  IsValid: Boolean;
  EnvOptionsFile: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 4: ValidateConfig Checks Configuration');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test4';
    ForceDirectories(ConfigDir);

    // Create a mock environmentoptions.xml with invalid paths
    EnvOptionsFile := ConfigDir + PathDelim + 'environmentoptions.xml';
    with TStringList.Create do
    try
      Add('<?xml version="1.0" encoding="UTF-8"?>');
      Add('<CONFIG>');
      Add('  <EnvironmentOptions>');
      Add('    <CompilerFilename Value="/nonexistent/fpc"/>');
      Add('  </EnvironmentOptions>');
      Add('</CONFIG>');
      SaveToFile(EnvOptionsFile);
    finally
      Free;
    end;

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      // Validate config (should fail because paths don't exist)
      IsValid := IDEConfig.ValidateConfig;

      AssertFalse(IsValid, 'ValidateConfig detects invalid config',
        'ValidateConfig should return False for invalid configuration');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'ValidateConfig', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 5: GetConfigSummary returns summary
// ============================================================================
procedure TestGetConfigSummary;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  Summary: string;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 5: GetConfigSummary Returns Summary');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test5';
    ForceDirectories(ConfigDir);

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      // Set some paths
      IDEConfig.SetCompilerPath('/usr/bin/fpc');
      IDEConfig.SetMakePath('/usr/bin/make');

      // Get summary
      Summary := IDEConfig.GetConfigSummary;

      AssertTrue(Summary <> '', 'GetConfigSummary returns non-empty',
        'GetConfigSummary should return non-empty summary');

      AssertTrue(Pos('Compiler path', Summary) > 0, 'Summary contains compiler path',
        'Summary should contain compiler path information');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'GetConfigSummary', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Test 6: SetLibraryPath and GetLibraryPath
// ============================================================================
procedure TestLibraryPathSetGet;
var
  ConfigDir: string;
  IDEConfig: TLazarusIDEConfig;
  TestPath, RetrievedPath: string;
  Success: Boolean;
begin
  WriteLn;
  WriteLn('==================================================');
  WriteLn('Test 6: Library Path Set/Get');
  WriteLn('==================================================');

  try
    ConfigDir := TestRootDir + PathDelim + '.lazarus-test6';
    ForceDirectories(ConfigDir);

    IDEConfig := TLazarusIDEConfig.Create(ConfigDir);
    try
      TestPath := '/usr/lib/lazarus';

      // Set library path
      Success := IDEConfig.SetLibraryPath(TestPath);
      AssertTrue(Success, 'SetLibraryPath succeeds',
        'SetLibraryPath should return True');

      // Get library path
      RetrievedPath := IDEConfig.GetLibraryPath;
      AssertEquals(TestPath, RetrievedPath, 'GetLibraryPath returns correct value',
        'Retrieved path should match the set path');

    finally
      IDEConfig.Free;
    end;

  except
    on E: Exception do
      AssertTrue(False, 'Library path set/get', 'Exception: ' + E.Message);
  end;
end;

// ============================================================================
// Main Test Runner
// ============================================================================
begin
  WriteLn('========================================');
  WriteLn('  Lazarus IDE Config Test Suite');
  WriteLn('========================================');
  WriteLn;

  try
    InitTestEnvironment;
    try
      // Run all tests
      TestIDEConfigCreation;
      TestCompilerPathSetGet;
      TestBackupConfig;
      TestValidateConfig;
      TestGetConfigSummary;
      TestLibraryPathSetGet;

      // Exit with error if any tests failed
      if TestsFailed > 0 then
        ExitCode := 1
      else
        ExitCode := 0;

    finally
      CleanupTestEnvironment;
    end;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('  Test suite crashed');
      WriteLn('========================================');
      WriteLn('Exception: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
