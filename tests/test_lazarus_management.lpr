program test_lazarus_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.config;

type
  { TLazarusManagementTest }
  TLazarusManagementTest = class
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
    procedure TestLazarusConfigurationCreation;
    procedure TestLazarusVersionManagement;
    procedure TestLazarusFPCIntegration;
    procedure TestLazarusEnvironmentSetup;
    procedure TestLazarusCommandInterface;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TLazarusManagementTest }

constructor TLazarusManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  // 创建临时测试配置文件路径
  FTestConfigPath := 'test_lazarus_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TLazarusManagementTest.Destroy;
begin
  // 清理测试文件
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);
    
  FConfigManager.Free;
  inherited Destroy;
end;

procedure TLazarusManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TLazarusManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TLazarusManagementTest.RunAllTests;
begin
  WriteLn('=== Lazarus Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestLazarusConfigurationCreation;
  TestLazarusVersionManagement;
  TestLazarusFPCIntegration;
  TestLazarusEnvironmentSetup;
  TestLazarusCommandInterface;
  
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

procedure TLazarusManagementTest.TestLazarusConfigurationCreation;
begin
  WriteLn('--- Testing Lazarus Configuration Creation ---');
  
  try
    // 创建配置管理器
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');
    
    // 测试加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');
    
    WriteLn('✓ Lazarus configuration creation and loading successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during configuration creation: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TLazarusManagementTest.TestLazarusVersionManagement;
var
  LazarusInfo: TLazarusInfo;
  Versions: TStringArray;
begin
  WriteLn('--- Testing Lazarus Version Management ---');
  
  try
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
    AssertEquals('fpc-3.2.2', LazarusInfo.FPCVersion, 'FPC version should match');
    
    // 测试列出Lazarus版本
    Versions := FConfigManager.ListLazarusVersions;
    AssertTrue(Length(Versions) > 0, 'Should have at least one Lazarus version');
    
    WriteLn('✓ Lazarus version management successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during version management: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TLazarusManagementTest.TestLazarusFPCIntegration;
var
  LazarusInfo: TLazarusInfo;
  ToolchainInfo: TToolchainInfo;
begin
  WriteLn('--- Testing Lazarus-FPC Integration ---');
  
  try
    // 先添加FPC工具链
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/test/fpc/3.2.2';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'fixes_3_2';
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;
    
    AssertTrue(FConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo), 'Should add FPC toolchain');
    
    // 添加关联的Lazarus版本
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    LazarusInfo.Version := '3.0';
    LazarusInfo.FPCVersion := 'fpc-3.2.2';
    LazarusInfo.InstallPath := '/test/lazarus/3.0';
    LazarusInfo.SourceURL := 'https://gitlab.com/freepascal.org/lazarus.git';
    LazarusInfo.Branch := 'lazarus_3_0';
    LazarusInfo.Installed := True;
    
    AssertTrue(FConfigManager.AddLazarusVersion('lazarus-3.0', LazarusInfo), 'Should add Lazarus version with FPC association');
    
    // 验证关联
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    AssertTrue(FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Should get Lazarus version');
    AssertEquals('fpc-3.2.2', LazarusInfo.FPCVersion, 'FPC version association should be correct');
    
    WriteLn('✓ Lazarus-FPC integration successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during FPC integration: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TLazarusManagementTest.TestLazarusEnvironmentSetup;
var
  LazarusInfo: TLazarusInfo;
begin
  WriteLn('--- Testing Lazarus Environment Setup ---');
  
  try
    // 测试设置默认Lazarus版本
    AssertTrue(FConfigManager.SetDefaultLazarusVersion('lazarus-3.0'), 'Should set default Lazarus version');
    AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default Lazarus version should match');
    
    // 测试获取Lazarus版本信息
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    AssertTrue(FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Should get Lazarus version info');
    AssertTrue(LazarusInfo.Installed = True, 'Lazarus should be marked as installed');
    
    WriteLn('✓ Lazarus environment setup successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during environment setup: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TLazarusManagementTest.TestLazarusCommandInterface;
var
  Versions: TStringArray;
begin
  WriteLn('--- Testing Lazarus Command Interface ---');

  try
    // 测试配置保存和加载
    AssertTrue(FConfigManager.SaveConfig, 'Should save configuration');

    // 重新加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should reload configuration');

    // 验证数据完整性
    AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default version should persist');

    Versions := FConfigManager.ListLazarusVersions;
    AssertTrue(Length(Versions) > 0, 'Should have persisted Lazarus versions');

    WriteLn('✓ Lazarus command interface successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during command interface test: ' + E.Message);
    end;
  end;

  WriteLn;
end;

// 全局测试函数
procedure RunLazarusManagementTests;
var
  Test: TLazarusManagementTest;
begin
  Test := TLazarusManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('Lazarus Management Test Suite');
    WriteLn('============================');
    WriteLn;
    
    RunLazarusManagementTests;
    
    WriteLn;
    WriteLn('Test suite completed.');
    
  except
    on E: Exception do
    begin
      WriteLn('Error running tests: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  {$IFDEF MSWINDOWS}
  WriteLn;
  WriteLn('Press Enter to continue...');
  ReadLn;
  {$ENDIF}
end.
