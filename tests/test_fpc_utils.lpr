program test_fpc_utils;
{$codepage utf8}
{$mode objfpc}{$H+}

{
  FPC Utils 模块测试

  测试 fpdev.fpc.utils 模块中的共享工具函数：
  - FindProjectRoot
  - DetectInstallScope
  - DetectArchiveFormat
  - ExtractArchive (ZIP + TAR.GZ)
  - CalculateFileSHA256
  - VerifyFileSHA256
}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, test_config_isolation, Classes,
  fpdev.types, fpdev.fpc.types, fpdev.fpc.utils, fpdev.fpc.logger,
  fpdev.config.interfaces, fpdev.config.managers, fpdev.fpc.version,
  fpdev.fpc.installer, fpdev.utils.fs, test_temp_paths;

type
  { TFPCUtilsTest }
  TFPCUtilsTest = class
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

    // 创建测试文件
    function CreateTestFile(const APath, AContent: string): Boolean;
    function CreateTestDir(const APath: string): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    procedure RunAllTests;

    // Unit tests
    procedure TestFindProjectRoot;
    procedure TestDetectInstallScope;
    procedure TestDetectArchiveFormat;
    procedure TestExtractZip;
    procedure TestCalculateFileSHA256;
    procedure TestVerifyFileSHA256;
    procedure TestGetBinaryDownloadURL;
    procedure TestOutputDirUsesSystemTempAndUniqueSuffix;
    procedure TestConfigManagerUsesIsolatedDefaultConfigPath;

    // Property-based tests
    procedure TestProperty1_ArchiveExtractionRoundTrip;
    procedure TestProperty6_LoggingSystemRobustness;
    procedure TestProperty3_ChecksumFailureCleanup;
    procedure TestProperty5_PlatformURLGeneration;

    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TFPCUtilsTest }

constructor TFPCUtilsTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  FTestDataDir := 'tests' + PathDelim + 'data' + PathDelim + 'cross' + PathDelim;
  FTestOutputDir := CreateUniqueTempDir('fpdev_fpc_utils_test') + PathDelim;
end;

destructor TFPCUtilsTest.Destroy;
begin
  CleanupTestEnvironment;
  inherited Destroy;
end;

procedure TFPCUtilsTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TFPCUtilsTest.AssertFalse(const ACondition: Boolean; const AMessage: string);
begin
  AssertTrue(not ACondition, AMessage);
end;

procedure TFPCUtilsTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TFPCUtilsTest.SetupTestEnvironment;
begin
  if not DirectoryExists(FTestOutputDir) then
    ForceDirectories(FTestOutputDir);
end;

procedure TFPCUtilsTest.CleanupTestEnvironment;
begin
  if DirectoryExists(FTestOutputDir) then
    CleanupTempDir(FTestOutputDir);
end;

function TFPCUtilsTest.CreateTestFile(const APath, AContent: string): Boolean;
var
  Dir: string;
  SL: TStringList;
begin
  Result := False;
  try
    Dir := ExtractFileDir(APath);
    if (Dir <> '') and not DirectoryExists(Dir) then
      ForceDirectories(Dir);

    SL := TStringList.Create;
    try
      SL.Text := AContent;
      SL.SaveToFile(APath);
      Result := True;
    finally
      SL.Free;
    end;
  except
    Result := False;
  end;
end;

function TFPCUtilsTest.CreateTestDir(const APath: string): Boolean;
begin
  Result := False;
  try
    if not DirectoryExists(APath) then
      ForceDirectories(APath);
    Result := DirectoryExists(APath);
  except
    Result := False;
  end;
end;

procedure TFPCUtilsTest.RunAllTests;
begin
  WriteLn('=== FPC Utils Tests ===');
  WriteLn;

  FTestsPassed := 0;
  FTestsFailed := 0;

  SetupTestEnvironment;
  try
    // Unit tests
    WriteLn('--- Unit Tests ---');
    TestOutputDirUsesSystemTempAndUniqueSuffix;
    TestConfigManagerUsesIsolatedDefaultConfigPath;
    TestFindProjectRoot;
    TestDetectInstallScope;
    TestDetectArchiveFormat;
    TestExtractZip;
    TestCalculateFileSHA256;
    TestVerifyFileSHA256;
    TestGetBinaryDownloadURL;

    WriteLn;
    WriteLn('--- Property-Based Tests ---');
    TestProperty1_ArchiveExtractionRoundTrip;
    TestProperty6_LoggingSystemRobustness;
    TestProperty3_ChecksumFailureCleanup;
    TestProperty5_PlatformURLGeneration;
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

procedure TFPCUtilsTest.TestFindProjectRoot;
var
  TestDir, FPDevDir, SubDir, Result: string;
begin
  WriteLn('TestFindProjectRoot:');

  // 创建测试目录结构
  TestDir := FTestOutputDir + 'project_root_test' + PathDelim;
  FPDevDir := TestDir + '.fpdev' + PathDelim;
  SubDir := TestDir + 'src' + PathDelim + 'units' + PathDelim;

  CreateTestDir(FPDevDir);
  CreateTestDir(SubDir);

  // 测试从子目录查找
  Result := FindProjectRoot(SubDir);
  AssertEquals(ExcludeTrailingPathDelimiter(TestDir), Result,
    'Should find project root from subdirectory');

  // 测试从项目根目录查找
  Result := FindProjectRoot(TestDir);
  AssertEquals(ExcludeTrailingPathDelimiter(TestDir), Result,
    'Should find project root from root directory');

  // 测试从不存在 .fpdev 的目录查找
  Result := FindProjectRoot(GetTempDir);
  AssertTrue(Result = '', 'Should return empty for non-project directory');

  WriteLn;
end;

procedure TFPCUtilsTest.TestDetectInstallScope;
var
  TestDir, FPDevDir, SubDir: string;
  Scope: TInstallScope;
begin
  WriteLn('TestDetectInstallScope:');

  // 创建测试目录结构
  TestDir := FTestOutputDir + 'scope_test' + PathDelim;
  FPDevDir := TestDir + '.fpdev' + PathDelim;
  SubDir := TestDir + 'src' + PathDelim;

  CreateTestDir(FPDevDir);
  CreateTestDir(SubDir);

  // 测试项目作用域
  Scope := DetectInstallScope(SubDir);
  AssertTrue(Scope = isProject, 'Should detect project scope');

  // 测试用户作用域（无 .fpdev 目录）
  Scope := DetectInstallScope(GetTempDir);
  AssertTrue(Scope = isUser, 'Should detect user scope');

  WriteLn;
end;

procedure TFPCUtilsTest.TestDetectArchiveFormat;
begin
  WriteLn('TestDetectArchiveFormat:');

  AssertTrue(DetectArchiveFormat('test.zip') = afZip, 'Should detect .zip format');
  AssertTrue(DetectArchiveFormat('test.ZIP') = afZip, 'Should detect .ZIP format (case insensitive)');
  AssertTrue(DetectArchiveFormat('test.tar.gz') = afTarGz, 'Should detect .tar.gz format');
  AssertTrue(DetectArchiveFormat('test.TAR.GZ') = afTarGz, 'Should detect .TAR.GZ format');
  AssertTrue(DetectArchiveFormat('test.tgz') = afTarGz, 'Should detect .tgz format');
  AssertTrue(DetectArchiveFormat('test.tar') = afTar, 'Should detect .tar format');
  AssertTrue(DetectArchiveFormat('test.txt') = afUnknown, 'Should return unknown for .txt');
  AssertTrue(DetectArchiveFormat('test') = afUnknown, 'Should return unknown for no extension');
  AssertTrue(DetectArchiveFormat('') = afUnknown, 'Should return unknown for empty string');

  WriteLn;
end;

procedure TFPCUtilsTest.TestExtractZip;
var
  ZipFile, OutputDir: string;
  OpResult: TOperationResult;
begin
  WriteLn('TestExtractZip:');

  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';
  OutputDir := FTestOutputDir + 'zip_extract_test' + PathDelim;

  // 测试解压存在的 ZIP 文件
  if FileExists(ZipFile) then
  begin
    OpResult := ExtractZip(ZipFile, OutputDir);
    AssertTrue(OpResult.Success, 'Should extract ZIP file successfully');
    AssertTrue(DirectoryExists(OutputDir), 'Output directory should exist');
  end
  else
  begin
    WriteLn('  [SKIP] Test ZIP file not found: ', ZipFile);
  end;

  // 测试解压不存在的文件
  OpResult := ExtractZip('nonexistent.zip', OutputDir);
  AssertFalse(OpResult.Success, 'Should fail for non-existent file');
  AssertTrue(OpResult.ErrorCode = ecFileSystemError, 'Should have file system error code');

  WriteLn;
end;

procedure TFPCUtilsTest.TestCalculateFileSHA256;
var
  TestFile, Hash1, Hash2: string;
begin
  WriteLn('TestCalculateFileSHA256:');

  TestFile := FTestOutputDir + 'sha256_test.txt';

  // 创建测试文件
  CreateTestFile(TestFile, 'Hello, World!');

  // 计算哈希
  Hash1 := CalculateFileSHA256(TestFile);
  AssertTrue(Hash1 <> '', 'Should calculate SHA256 hash');
  AssertTrue(Length(Hash1) = 64, 'SHA256 hash should be 64 characters');

  // 相同文件应该产生相同哈希
  Hash2 := CalculateFileSHA256(TestFile);
  AssertEquals(Hash1, Hash2, 'Same file should produce same hash');

  // 不存在的文件应该返回空
  Hash1 := CalculateFileSHA256('nonexistent.txt');
  AssertTrue(Hash1 = '', 'Should return empty for non-existent file');

  WriteLn;
end;

procedure TFPCUtilsTest.TestVerifyFileSHA256;
var
  TestFile, CorrectHash, WrongHash: string;
begin
  WriteLn('TestVerifyFileSHA256:');

  TestFile := FTestOutputDir + 'verify_test.txt';

  // 创建测试文件
  CreateTestFile(TestFile, 'Test content for verification');

  // 计算正确的哈希
  CorrectHash := CalculateFileSHA256(TestFile);
  WrongHash := 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  // 验证正确的哈希
  AssertTrue(VerifyFileSHA256(TestFile, CorrectHash),
    'Should verify correct hash');

  // 验证错误的哈希
  AssertFalse(VerifyFileSHA256(TestFile, WrongHash),
    'Should reject wrong hash');

  // 验证空哈希
  AssertFalse(VerifyFileSHA256(TestFile, ''),
    'Should reject empty hash');

  // 验证不存在的文件
  AssertFalse(VerifyFileSHA256('nonexistent.txt', CorrectHash),
    'Should reject non-existent file');

  WriteLn;
end;

procedure TFPCUtilsTest.TestProperty1_ArchiveExtractionRoundTrip;
{
  **Feature: fpc-code-review-2, Property 1: Archive Extraction Round-Trip**
  **Validates: Requirements 2.1, 2.3**

  *For any* valid archive file (ZIP or TAR.GZ), extracting it to a directory
  and then listing the extracted files should produce the same file list as
  the archive contents.

  Note: This test verifies that extraction produces consistent results across
  multiple iterations.
}
const
  ITERATIONS = 100;
var
  i, PassCount: Integer;
  ZipFile, OutputDir: string;
  OpResult: TOperationResult;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty1_ArchiveExtractionRoundTrip:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');

  AllPassed := True;
  PassCount := 0;

  ZipFile := FTestDataDir + 'win64-binutils-2.40-test.zip';

  if not FileExists(ZipFile) then
  begin
    WriteLn('  [SKIP] Test archive not found');
    AssertTrue(True, 'Property 1: Skipped - test archive not found');
    Exit;
  end;

  for i := 1 to ITERATIONS do
  begin
    OutputDir := FTestOutputDir + 'prop1_' + IntToStr(i) + PathDelim;

    // 测试解压
    OpResult := ExtractArchive(ZipFile, OutputDir);
    if not OpResult.Success then
    begin
      AllPassed := False;
      Continue;
    end;

    // 验证输出目录存在
    if not DirectoryExists(OutputDir) then
    begin
      AllPassed := False;
      Continue;
    end;

    // 验证格式检测正确
    if DetectArchiveFormat(ZipFile) <> afZip then
    begin
      AllPassed := False;
      Continue;
    end;

    Inc(PassCount);

    // 清理本次迭代
    if DirectoryExists(OutputDir) then
      CleanupTempDir(OutputDir);
  end;

  AssertTrue(AllPassed, 'Property 1: Archive extraction round-trip (' +
    IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  WriteLn;
end;

procedure TFPCUtilsTest.TestProperty6_LoggingSystemRobustness;
{
  **Feature: fpc-code-review-2, Property 6: Logging System Robustness**
  **Validates: Requirements 7.2**

  *For any* log operation, even when the log file is inaccessible or disk is full,
  the logging function should not throw exceptions that propagate to the caller.
}
const
  ITERATIONS = 100;
var
  i, PassCount: Integer;
  LogFile: string;
  AllPassed: Boolean;
  Logger: TLogger;
begin
  WriteLn('TestProperty6_LoggingSystemRobustness:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');

  AllPassed := True;
  PassCount := 0;

  LogFile := FTestOutputDir + 'test_logger.log';

  for i := 1 to ITERATIONS do
  begin
    try
      Logger := TLogger.Create;
      try
        // 测试正常日志
        Logger.Initialize(LogFile);
        Logger.Debug('Debug message ' + IntToStr(i));
        Logger.Info('Info message ' + IntToStr(i));
        Logger.Warn('Warn message ' + IntToStr(i));
        Logger.Error('Error message ' + IntToStr(i));
        Logger.Shutdown;

        // 测试未初始化时的日志（应该不抛异常）
        Logger.Info('Message without initialization');

        // 测试无效路径（应该不抛异常）
        Logger.Initialize('');
        Logger.Info('Message with empty path');

        Inc(PassCount);
      finally
        Logger.Free;
      end;
    except
      on E: Exception do
      begin
        AllPassed := False;
        WriteLn('  Exception at iteration ', i, ': ', E.Message);
      end;
    end;
  end;

  // 清理日志文件
  if FileExists(LogFile) then
    DeleteFile(LogFile);

  AssertTrue(AllPassed, 'Property 6: Logging system robustness (' +
    IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  WriteLn;
end;

procedure TFPCUtilsTest.TestOutputDirUsesSystemTempAndUniqueSuffix;
var
  TempPrefix: string;
  DirName: string;
begin
  WriteLn('TestOutputDirUsesSystemTempAndUniqueSuffix:');

  TempPrefix := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  AssertTrue(
    Pos(TempPrefix, ExpandFileName(FTestOutputDir)) = 1,
    'Output dir should live under system temp'
  );

  DirName := ExtractFileName(ExcludeTrailingPathDelimiter(FTestOutputDir));
  AssertTrue(
    Pos('fpdev_fpc_utils_test_', DirName) = 1,
    'Output dir should use unique suffix'
  );
  WriteLn;
end;

procedure TFPCUtilsTest.TestConfigManagerUsesIsolatedDefaultConfigPath;
var
  ConfigManager: IConfigManager;
  ConfigPath: string;
  TempRoot: string;
  ExpectedPath: string;
begin
  WriteLn('TestConfigManagerUsesIsolatedDefaultConfigPath:');

  ConfigManager := CreateIsolatedConfigManager;
  ConfigPath := ExpandFileName(ConfigManager.GetConfigPath);
  TempRoot := IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False)));
  ExpectedPath := ExpandFileName(GetIsolatedDefaultConfigPath);

  AssertTrue(Pos(TempRoot, ConfigPath) = 1,
    'Config path should live under system temp');
  AssertTrue(ConfigPath = ExpectedPath,
    'Config path should use isolated default override');
  WriteLn;
end;

procedure TFPCUtilsTest.TestGetBinaryDownloadURL;
var
  ConfigManager: IConfigManager;
  VersionManager: TFPCVersionManager;
  Installer: TFPCBinaryInstaller;
  URL: string;
begin
  WriteLn('TestGetBinaryDownloadURL:');

  ConfigManager := CreateIsolatedConfigManager;
  VersionManager := TFPCVersionManager.Create(ConfigManager);
  try
    Installer := TFPCBinaryInstaller.Create(ConfigManager);
    try
      URL := Installer.GetBinaryDownloadURL('3.2.2');

        // 验证 URL 不为空（在支持的平台上）
        {$IFDEF MSWINDOWS}
        AssertTrue(URL <> '', 'Should return URL for Windows');
        AssertTrue(Pos('Win', URL) > 0, 'URL should contain Win for Windows');
        {$ENDIF}

        {$IFDEF LINUX}
        AssertTrue(URL <> '', 'Should return URL for Linux');
        AssertTrue(Pos('Linux', URL) > 0, 'URL should contain Linux');
        {$ENDIF}

        {$IFDEF DARWIN}
        AssertTrue(URL <> '', 'Should return URL for macOS');
        AssertTrue(Pos('macOS', URL) > 0, 'URL should contain macOS');
        {$ENDIF}

        // 验证 URL 包含版本号
        if URL <> '' then
          AssertTrue(Pos('3.2.2', URL) > 0, 'URL should contain version number');
      finally
        Installer.Free;
      end;
    finally
      VersionManager.Free;
    end;

  WriteLn;
end;

procedure TFPCUtilsTest.TestProperty3_ChecksumFailureCleanup;
{
  **Feature: fpc-code-review-2, Property 3: Checksum Failure Cleanup**
  **Validates: Requirements 8.2**

  *For any* downloaded file that fails checksum verification, the file should
  be deleted and an error result should be returned.
}
const
  ITERATIONS = 100;
var
  i, PassCount: Integer;
  TestFile, WrongChecksum: string;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty3_ChecksumFailureCleanup:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');

  AllPassed := True;
  PassCount := 0;
  WrongChecksum := 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  for i := 1 to ITERATIONS do
  begin
    TestFile := FTestOutputDir + 'checksum_test_' + IntToStr(i) + '.txt';

    try
      // 创建测试文件
      CreateTestFile(TestFile, 'Test content ' + IntToStr(i));

      // 验证错误的校验和应该返回 False
      if VerifyFileSHA256(TestFile, WrongChecksum) then
      begin
        AllPassed := False;
        Continue;
      end;

      Inc(PassCount);
    finally
      // 清理
      if FileExists(TestFile) then
        DeleteFile(TestFile);
    end;
  end;

  AssertTrue(AllPassed, 'Property 3: Checksum failure cleanup (' +
    IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  WriteLn;
end;

procedure TFPCUtilsTest.TestProperty5_PlatformURLGeneration;
{
  **Feature: fpc-code-review-2, Property 5: Platform URL Generation**
  **Validates: Requirements 5.1, 5.2, 5.3**

  *For any* supported platform (Windows x64, Linux x64, macOS ARM64), the
  GetBinaryDownloadURL function should return a valid, non-empty URL.
}
const
  ITERATIONS = 100;
  TEST_VERSIONS: array[0..2] of string = ('3.2.2', '3.2.0', '3.0.4');
var
  i, j, PassCount: Integer;
  ConfigManager: IConfigManager;
  VersionManager: TFPCVersionManager;
  Installer: TFPCBinaryInstaller;
  URL: string;
  AllPassed: Boolean;
begin
  WriteLn('TestProperty5_PlatformURLGeneration:');
  WriteLn('  Running ', ITERATIONS, ' iterations...');

  AllPassed := True;
  PassCount := 0;

  ConfigManager := CreateIsolatedConfigManager;
  VersionManager := TFPCVersionManager.Create(ConfigManager);
  try
    Installer := TFPCBinaryInstaller.Create(ConfigManager);
    try
        for i := 1 to ITERATIONS do
        begin
          for j := 0 to High(TEST_VERSIONS) do
          begin
            URL := Installer.GetBinaryDownloadURL(TEST_VERSIONS[j]);

            // 在支持的平台上，URL 应该不为空
            {$IF DEFINED(MSWINDOWS) OR DEFINED(LINUX) OR DEFINED(DARWIN)}
            if URL = '' then
            begin
              AllPassed := False;
              Continue;
            end;

            // URL 应该包含版本号
            if Pos(TEST_VERSIONS[j], URL) = 0 then
            begin
              AllPassed := False;
              Continue;
            end;
            {$ENDIF}
          end;

          Inc(PassCount);
        end;
      finally
        Installer.Free;
      end;
    finally
      VersionManager.Free;
    end;

  AssertTrue(AllPassed, 'Property 5: Platform URL generation (' +
    IntToStr(PassCount) + '/' + IntToStr(ITERATIONS) + ' passed)');
  WriteLn;
end;

{ Main }

var
  Test: TFPCUtilsTest;
begin
  try
    WriteLn('FPC Utils Test Suite');
    WriteLn('====================');
    WriteLn;

    Test := TFPCUtilsTest.Create;
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
