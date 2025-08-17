unit fpdev.config.test;

{$codepage utf8}

{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# fpdev.config.test

配置管理系统测试单元


## 声明

转发或者用于自己项目请保留本项目的版权声明,谢谢.

fafafaStudio
Email:dtamade@gmail.com
QQ群:685403987  QQ:179033731

}

{$I fpdev.settings.inc}
{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  fpdev.config;

type
  { TFPDevConfigTest }
  TFPDevConfigTest = class
  private
    FTestConfigPath: string;
    FConfigManager: TFPDevConfigManager;
    FTestsPassed: Integer;
    FTestsFailed: Integer;
    
    procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: string; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
    procedure AssertEquals(const AExpected, AActual: Boolean; const AMessage: string);
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RunAllTests;
    
    // 测试方法
    procedure TestCreateDefaultConfig;
    procedure TestLoadSaveConfig;
    procedure TestToolchainManagement;
    procedure TestLazarusManagement;
    procedure TestCrossTargetManagement;
    procedure TestRepositoryManagement;
    procedure TestSettingsManagement;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

// 全局测试函数
procedure RunConfigTests;

implementation

{ TFPDevConfigTest }

constructor TFPDevConfigTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  // 创建临时测试配置文件路径
  FTestConfigPath := 'fpdev_test_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TFPDevConfigTest.Destroy;
begin
  // 清理测试文件
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);
    
  FConfigManager.Free;
  inherited Destroy;
end;

procedure TFPDevConfigTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: Integer; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + IntToStr(AExpected) + ', Actual: ' + IntToStr(AActual) + ')');
end;

procedure TFPDevConfigTest.AssertEquals(const AExpected, AActual: Boolean; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: ' + BoolToStr(AExpected, True) + ', Actual: ' + BoolToStr(AActual, True) + ')');
end;

procedure TFPDevConfigTest.RunAllTests;
begin
  WriteLn('=== FPDev Configuration Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestCreateDefaultConfig;
  TestLoadSaveConfig;
  TestToolchainManagement;
  TestLazarusManagement;
  TestCrossTargetManagement;
  TestRepositoryManagement;
  TestSettingsManagement;
  
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

procedure TFPDevConfigTest.TestCreateDefaultConfig;
begin
  WriteLn('--- Testing Default Config Creation ---');
  
  // 确保测试文件不存在
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);
    
  AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
  AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestLoadSaveConfig;
begin
  WriteLn('--- Testing Load/Save Config ---');
  
  // 创建默认配置
  AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
  
  // 测试加载
  AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');
  
  // 测试保存
  AssertTrue(FConfigManager.SaveConfig, 'Should save config successfully');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestToolchainManagement;
var
  ToolchainInfo: TToolchainInfo;
  Toolchains: TStringArray;
begin
  WriteLn('--- Testing Toolchain Management ---');
  
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
  
  // 测试设置默认工具链
  AssertTrue(FConfigManager.SetDefaultToolchain('fpc-3.2.2'), 'Should set default toolchain');
  AssertEquals('fpc-3.2.2', FConfigManager.GetDefaultToolchain, 'Default toolchain should match');
  
  // 测试列出工具链
  Toolchains := FConfigManager.ListToolchains;
  AssertTrue(Length(Toolchains) > 0, 'Should have at least one toolchain');
  
  // 测试删除工具链
  AssertTrue(FConfigManager.RemoveToolchain('fpc-3.2.2'), 'Should remove toolchain');
  AssertTrue(not FConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo), 'Toolchain should not exist after removal');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestLazarusManagement;
var
  LazarusInfo: TLazarusInfo;
  Versions: TStringArray;
begin
  WriteLn('--- Testing Lazarus Management ---');
  
  // 准备测试数据
  FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
  LazarusInfo.Version := '3.0';
  LazarusInfo.FPCVersion := 'fpc-3.2.2';
  LazarusInfo.InstallPath := '/test/lazarus/3.0';
  LazarusInfo.SourceURL := 'https://gitlab.com/freepascal.org/lazarus.git';
  LazarusInfo.Branch := 'lazarus_3_0';
  LazarusInfo.Installed := True;
  
  // 测试添加Lazarus版本
  AssertTrue(FConfigManager.AddLazarusVersion('lazarus-3.0', LazarusInfo), 'Should add Lazarus version');
  
  // 测试获取Lazarus版本
  FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
  AssertTrue(FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Should get Lazarus version');
  AssertEquals('3.0', LazarusInfo.Version, 'Lazarus version should match');
  
  // 测试设置默认Lazarus版本
  AssertTrue(FConfigManager.SetDefaultLazarusVersion('lazarus-3.0'), 'Should set default Lazarus version');
  AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default Lazarus version should match');
  
  // 测试列出Lazarus版本
  Versions := FConfigManager.ListLazarusVersions;
  AssertTrue(Length(Versions) > 0, 'Should have at least one Lazarus version');
  
  // 测试删除Lazarus版本
  AssertTrue(FConfigManager.RemoveLazarusVersion('lazarus-3.0'), 'Should remove Lazarus version');
  AssertTrue(not FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Lazarus version should not exist after removal');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestCrossTargetManagement;
var
  CrossTarget: TCrossTarget;
  Targets: TStringArray;
begin
  WriteLn('--- Testing Cross Target Management ---');
  
  // 准备测试数据
  FillChar(CrossTarget, SizeOf(CrossTarget), 0);
  CrossTarget.Enabled := True;
  CrossTarget.BinutilsPath := '/test/binutils/win64';
  CrossTarget.LibrariesPath := '/test/libs/win64';
  
  // 测试添加交叉编译目标
  AssertTrue(FConfigManager.AddCrossTarget('win64', CrossTarget), 'Should add cross target');
  
  // 测试获取交叉编译目标
  FillChar(CrossTarget, SizeOf(CrossTarget), 0);
  AssertTrue(FConfigManager.GetCrossTarget('win64', CrossTarget), 'Should get cross target');
  AssertEquals(True, CrossTarget.Enabled, 'Cross target should be enabled');
  
  // 测试列出交叉编译目标
  Targets := FConfigManager.ListCrossTargets;
  AssertTrue(Length(Targets) > 0, 'Should have at least one cross target');
  
  // 测试删除交叉编译目标
  AssertTrue(FConfigManager.RemoveCrossTarget('win64'), 'Should remove cross target');
  AssertTrue(not FConfigManager.GetCrossTarget('win64', CrossTarget), 'Cross target should not exist after removal');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestRepositoryManagement;
var
  Repositories: TStringArray;
begin
  WriteLn('--- Testing Repository Management ---');
  
  // 测试添加仓库
  AssertTrue(FConfigManager.AddRepository('test_repo', 'https://example.com/test.git'), 'Should add repository');
  
  // 测试获取仓库
  AssertEquals('https://example.com/test.git', FConfigManager.GetRepository('test_repo'), 'Repository URL should match');
  
  // 测试列出仓库
  Repositories := FConfigManager.ListRepositories;
  AssertTrue(Length(Repositories) > 0, 'Should have at least one repository');
  
  // 测试删除仓库
  AssertTrue(FConfigManager.RemoveRepository('test_repo'), 'Should remove repository');
  AssertEquals('', FConfigManager.GetRepository('test_repo'), 'Repository should not exist after removal');
  
  WriteLn;
end;

procedure TFPDevConfigTest.TestSettingsManagement;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Settings Management ---');
  
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
  AssertEquals(True, Settings.AutoUpdate, 'AutoUpdate should match');
  AssertEquals(8, Settings.ParallelJobs, 'ParallelJobs should match');
  AssertEquals(False, Settings.KeepSources, 'KeepSources should match');
  AssertEquals('/test/fpdev', Settings.InstallRoot, 'InstallRoot should match');
  
  WriteLn;
end;

// 全局测试函数
procedure RunConfigTests;
var
  Test: TFPDevConfigTest;
begin
  Test := TFPDevConfigTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

end.
