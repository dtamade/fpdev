program test_package_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, test_temp_paths, Classes,
  fpdev.config;

type
  { TPackageManagementTest }
  TPackageManagementTest = class
  private
    FTestConfigPath: string;
    FConfigManager: TFPDevConfigManager;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    
    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RunAllTests;
    
    // 测试方法
    procedure TestPackageConfigurationCreation;
    procedure TestPackageRepositoryManagement;
    procedure TestPackageInstallationFramework;
    procedure TestPackageCommandInterface;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TPackageManagementTest }

constructor TPackageManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  FTestConfigPath := CreateUniqueTempDir('test_package_management')
    + PathDelim + 'config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TPackageManagementTest.Destroy;
begin
  FConfigManager.Free;
  if FTestConfigPath <> '' then
    CleanupTempDir(ExtractFileDir(FTestConfigPath));
  FTestConfigPath := '';
  inherited Destroy;
end;

procedure TPackageManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(FTestsPassed);
    WriteLn('✓ PASS: ', AMessage);
  end
  else
  begin
    Inc(FTestsFailed);
    WriteLn('✗ FAIL: ', AMessage);
  end;
end;

procedure TPackageManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TPackageManagementTest.RunAllTests;
begin
  WriteLn('=== Package Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestPackageConfigurationCreation;
  TestPackageRepositoryManagement;
  TestPackageInstallationFramework;
  TestPackageCommandInterface;
  
  WriteLn;
  WriteLn('=== Test Results ===');
  WriteLn('Tests Passed: ', FTestsPassed);
  WriteLn('Tests Failed: ', FTestsFailed);
  WriteLn('Total Tests: ', FTestsPassed + FTestsFailed);
  
  if FTestsFailed = 0 then
    WriteLn('✓ All tests passed!')
  else
    WriteLn('✗ Some tests failed!');
end;

procedure TPackageManagementTest.TestPackageConfigurationCreation;
begin
  WriteLn('--- Testing Package Configuration Creation ---');
  
  try
    AssertTrue(
      PathUsesSystemTempRoot(FTestConfigPath),
      'Config path should live under system temp'
    );

    // 创建配置管理器
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');
    
    // 测试加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');
    
    WriteLn('✓ Package configuration creation and loading successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during configuration creation: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TPackageManagementTest.TestPackageRepositoryManagement;
begin
  WriteLn('--- Testing Package Repository Management ---');
  
  try
    // 测试添加仓库
    AssertTrue(FConfigManager.AddRepository('test_repo', 'https://example.com/packages.git'), 'Should add repository');
    AssertEquals('https://example.com/packages.git', FConfigManager.GetRepository('test_repo'), 'Repository URL should match');
    
    // 测试添加另一个仓库
    AssertTrue(FConfigManager.AddRepository('official', 'https://packages.freepascal.org/'), 'Should add official repository');
    AssertEquals('https://packages.freepascal.org/', FConfigManager.GetRepository('official'), 'Official repository URL should match');
    
    WriteLn('✓ Package repository management successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during repository management: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TPackageManagementTest.TestPackageInstallationFramework;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Package Installation Framework ---');
  
  try
    // 测试设置包安装根目录
    FillChar(Settings, SizeOf(Settings), 0);
    Settings.InstallRoot := '/test/fpdev/packages';
    Settings.AutoUpdate := True;
    Settings.ParallelJobs := 4;
    Settings.KeepSources := True;
    
    AssertTrue(FConfigManager.SetSettings(Settings), 'Should set package settings');
    
    // 验证设置
    Settings := FConfigManager.GetSettings;
    AssertEquals('/test/fpdev/packages', Settings.InstallRoot, 'Install root should match');
    AssertTrue(Settings.AutoUpdate = True, 'AutoUpdate should be enabled');
    AssertTrue(Settings.ParallelJobs = 4, 'ParallelJobs should match');
    AssertTrue(Settings.KeepSources = True, 'KeepSources should be enabled');
    
    WriteLn('✓ Package installation framework successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during installation framework test: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TPackageManagementTest.TestPackageCommandInterface;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Package Command Interface ---');

  try
    // 测试配置保存和加载
    AssertTrue(FConfigManager.SaveConfig, 'Should save configuration');

    // 重新加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should reload configuration');

    // 验证数据完整性
    AssertEquals('https://example.com/packages.git', FConfigManager.GetRepository('test_repo'), 'Test repository should persist');
    AssertEquals('https://packages.freepascal.org/', FConfigManager.GetRepository('official'), 'Official repository should persist');

    Settings := FConfigManager.GetSettings;
    AssertEquals('/test/fpdev/packages', Settings.InstallRoot, 'Install root should persist');

    WriteLn('✓ Package command interface successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during command interface test: ' + E.Message);
    end;
  end;

  WriteLn;
end;

// 全局测试函数
procedure RunPackageManagementTests;
var
  Test: TPackageManagementTest;
begin
  Test := TPackageManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('Package Management Test Suite');
    WriteLn('=============================');
    WriteLn;
    
    RunPackageManagementTests;
    
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
