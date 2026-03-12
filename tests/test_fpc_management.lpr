program test_fpc_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, test_temp_paths, Classes,
  fpdev.config;

type
  { TFPCManagementTest }
  TFPCManagementTest = class
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
    procedure TestConfigurationCreation;
    procedure TestToolchainManagement;
    procedure TestVersionConfiguration;
    procedure TestSettingsManagement;
    procedure TestCommandLineInterface;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TFPCManagementTest }

constructor TFPCManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  FTestConfigPath := CreateUniqueTempDir('test_fpc_management')
    + PathDelim + 'config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TFPCManagementTest.Destroy;
begin
  FConfigManager.Free;
  if FTestConfigPath <> '' then
    CleanupTempDir(ExtractFileDir(FTestConfigPath));
  FTestConfigPath := '';
  inherited Destroy;
end;

procedure TFPCManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TFPCManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TFPCManagementTest.RunAllTests;
begin
  WriteLn('=== FPC Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;

  TestConfigurationCreation;
  TestToolchainManagement;
  TestVersionConfiguration;
  TestSettingsManagement;
  TestCommandLineInterface;
  
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

procedure TFPCManagementTest.TestConfigurationCreation;
begin
  WriteLn('--- Testing Configuration Creation ---');

  try
    AssertTrue(
      Pos(IncludeTrailingPathDelimiter(ExpandFileName(GetTempDir(False))),
        ExpandFileName(FTestConfigPath)) = 1,
      'Config path should live under system temp'
    );

    // 创建配置管理器
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');

    // 测试加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');

    WriteLn('✓ Configuration creation and loading successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during configuration creation: ' + E.Message);
    end;
  end;

  WriteLn;
end;

procedure TFPCManagementTest.TestToolchainManagement;
var
  ToolchainInfo: TToolchainInfo;
  Toolchains: TStringArray;
begin
  WriteLn('--- Testing Toolchain Management ---');

  try
    // 准备测试数据
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/test/fpc/3.2.2';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'fixes_3_2';
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;

    // 测试添加工具链
    AssertTrue(FConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo), 'Should add toolchain');

    // 测试获取工具链
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    AssertTrue(FConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo), 'Should get toolchain');
    AssertEquals('3.2.2', ToolchainInfo.Version, 'Toolchain version should match');

    // 测试列出工具链
    Toolchains := FConfigManager.ListToolchains;
    AssertTrue(Length(Toolchains) > 0, 'Should have at least one toolchain');

    WriteLn('✓ Toolchain management successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during toolchain management: ' + E.Message);
    end;
  end;

  WriteLn;
end;

procedure TFPCManagementTest.TestVersionConfiguration;
var
  ToolchainInfo: TToolchainInfo;
begin
  WriteLn('--- Testing Version Configuration ---');

  try
    // 准备测试数据
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttDevelopment;
    ToolchainInfo.Version := 'main';
    ToolchainInfo.InstallPath := '/test/fpc/main';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'main';
    ToolchainInfo.Installed := False;

    // 测试添加开发版本
    AssertTrue(FConfigManager.AddToolchain('fpc-main', ToolchainInfo), 'Should add development version');

    // 测试设置默认版本
    AssertTrue(FConfigManager.SetDefaultToolchain('fpc-main'), 'Should set default toolchain');
    AssertEquals('fpc-main', FConfigManager.GetDefaultToolchain, 'Default toolchain should match');

    WriteLn('✓ Version configuration successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during version configuration: ' + E.Message);
    end;
  end;

  WriteLn;
end;

procedure TFPCManagementTest.TestSettingsManagement;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Settings Management ---');

  try
    // 准备测试数据
    FillChar(Settings, SizeOf(Settings), 0);
    Settings.AutoUpdate := True;
    Settings.ParallelJobs := 8;
    Settings.KeepSources := False;
    Settings.InstallRoot := '/test/fpdev';

    // 测试设置配置
    AssertTrue(FConfigManager.SetSettings(Settings), 'Should set settings');

    // 测试获取配置
    Settings := FConfigManager.GetSettings;
    AssertTrue(Settings.AutoUpdate = True, 'AutoUpdate should match');
    AssertTrue(Settings.ParallelJobs = 8, 'ParallelJobs should match');
    AssertTrue(Settings.KeepSources = False, 'KeepSources should match');
    AssertEquals('/test/fpdev', Settings.InstallRoot, 'InstallRoot should match');

    WriteLn('✓ Settings management successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during settings management: ' + E.Message);
    end;
  end;

  WriteLn;
end;



procedure TFPCManagementTest.TestCommandLineInterface;
var
  CrossTarget: TCrossTarget;
begin
  WriteLn('--- Testing Command Line Interface ---');

  try
    // 测试仓库管理
    AssertTrue(FConfigManager.AddRepository('test_repo', 'https://example.com/test.git'), 'Should add repository');
    AssertEquals('https://example.com/test.git', FConfigManager.GetRepository('test_repo'), 'Repository URL should match');

    // 测试交叉编译目标
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    CrossTarget.Enabled := True;
    CrossTarget.BinutilsPath := '/test/binutils';
    CrossTarget.LibrariesPath := '/test/libs';

    AssertTrue(FConfigManager.AddCrossTarget('test_target', CrossTarget), 'Should add cross target');

    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('test_target', CrossTarget), 'Should get cross target');
    AssertTrue(CrossTarget.Enabled = True, 'Cross target should be enabled');

    WriteLn('✓ Command line interface components successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during command line interface test: ' + E.Message);
    end;
  end;

  WriteLn;
end;

// 全局测试函数
procedure RunFPCManagementTests;
var
  Test: TFPCManagementTest;
begin
  Test := TFPCManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('FPC Management Test Suite');
    WriteLn('========================');
    WriteLn;
    
    RunFPCManagementTests;
    
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
