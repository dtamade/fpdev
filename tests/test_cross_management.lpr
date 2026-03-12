program test_cross_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, Classes,
  fpdev.config, test_temp_paths;

type
  { TCrossManagementTest }
  TCrossManagementTest = class
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
    procedure TestCrossConfigurationCreation;
    procedure TestCrossTargetManagement;
    procedure TestCrossTargetConfiguration;
    procedure TestCrossTargetEnableDisable;
    procedure TestCrossCommandInterface;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TCrossManagementTest }

constructor TCrossManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  FTestConfigPath := CreateUniqueTempDir('test_cross_management')
    + PathDelim + 'test_cross_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TCrossManagementTest.Destroy;
begin
  FConfigManager.Free;
  if FTestConfigPath <> '' then
    CleanupTempDir(ExtractFileDir(FTestConfigPath));
  FTestConfigPath := '';
  inherited Destroy;
end;

procedure TCrossManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TCrossManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TCrossManagementTest.RunAllTests;
begin
  WriteLn('=== Cross Compilation Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestCrossConfigurationCreation;
  TestCrossTargetManagement;
  TestCrossTargetConfiguration;
  TestCrossTargetEnableDisable;
  TestCrossCommandInterface;
  
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

procedure TCrossManagementTest.TestCrossConfigurationCreation;
begin
  WriteLn('--- Testing Cross Configuration Creation ---');
  
  try
    // 创建配置管理器
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist after creation');
    
    // 测试加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should load config successfully');
    
    WriteLn('✓ Cross configuration creation and loading successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during configuration creation: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TCrossManagementTest.TestCrossTargetManagement;
var
  CrossTarget: TCrossTarget;
  Targets: TStringArray;
begin
  WriteLn('--- Testing Cross Target Management ---');
  
  try
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
    AssertTrue(CrossTarget.Enabled = True, 'Cross target should be enabled');
    AssertEquals('/test/binutils/win64', CrossTarget.BinutilsPath, 'Binutils path should match');
    AssertEquals('/test/libs/win64', CrossTarget.LibrariesPath, 'Libraries path should match');
    
    // 测试列出交叉编译目标
    Targets := FConfigManager.ListCrossTargets;
    AssertTrue(Length(Targets) > 0, 'Should have at least one cross target');
    
    WriteLn('✓ Cross target management successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during target management: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TCrossManagementTest.TestCrossTargetConfiguration;
var
  CrossTarget: TCrossTarget;
begin
  WriteLn('--- Testing Cross Target Configuration ---');
  
  try
    // 添加另一个交叉编译目标
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    CrossTarget.Enabled := False;
    CrossTarget.BinutilsPath := '/test/binutils/linux64';
    CrossTarget.LibrariesPath := '/test/libs/linux64';
    
    AssertTrue(FConfigManager.AddCrossTarget('linux64', CrossTarget), 'Should add Linux64 cross target');
    
    // 验证配置
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('linux64', CrossTarget), 'Should get Linux64 cross target');
    AssertTrue(CrossTarget.Enabled = False, 'Linux64 target should be disabled initially');
    
    WriteLn('✓ Cross target configuration successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during target configuration: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TCrossManagementTest.TestCrossTargetEnableDisable;
var
  CrossTarget: TCrossTarget;
begin
  WriteLn('--- Testing Cross Target Enable/Disable ---');
  
  try
    // 测试启用目标
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('linux64', CrossTarget), 'Should get Linux64 target');
    CrossTarget.Enabled := True;
    AssertTrue(FConfigManager.AddCrossTarget('linux64', CrossTarget), 'Should enable Linux64 target');
    
    // 验证启用状态
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('linux64', CrossTarget), 'Should get updated Linux64 target');
    AssertTrue(CrossTarget.Enabled = True, 'Linux64 target should be enabled');
    
    // 测试禁用目标
    CrossTarget.Enabled := False;
    AssertTrue(FConfigManager.AddCrossTarget('linux64', CrossTarget), 'Should disable Linux64 target');
    
    // 验证禁用状态
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('linux64', CrossTarget), 'Should get disabled Linux64 target');
    AssertTrue(CrossTarget.Enabled = False, 'Linux64 target should be disabled');
    
    WriteLn('✓ Cross target enable/disable successful');
    
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during enable/disable test: ' + E.Message);
    end;
  end;
  
  WriteLn;
end;

procedure TCrossManagementTest.TestCrossCommandInterface;
var
  Targets: TStringArray;
  CrossTarget: TCrossTarget;
begin
  WriteLn('--- Testing Cross Command Interface ---');

  try
    // 测试配置保存和加载
    AssertTrue(FConfigManager.SaveConfig, 'Should save configuration');

    // 重新加载配置
    AssertTrue(FConfigManager.LoadConfig, 'Should reload configuration');

    // 验证数据完整性
    Targets := FConfigManager.ListCrossTargets;
    AssertTrue(Length(Targets) >= 2, 'Should have at least 2 cross targets after reload');

    // 验证特定目标仍然存在
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('win64', CrossTarget), 'Win64 target should persist');
    AssertTrue(CrossTarget.Enabled = True, 'Win64 target should remain enabled');

    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('linux64', CrossTarget), 'Linux64 target should persist');
    AssertTrue(CrossTarget.Enabled = False, 'Linux64 target should remain disabled');

    WriteLn('✓ Cross command interface successful');

  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during command interface test: ' + E.Message);
    end;
  end;

  WriteLn;
end;

// 全局测试函数
procedure RunCrossManagementTests;
var
  Test: TCrossManagementTest;
begin
  Test := TCrossManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('Cross Compilation Management Test Suite');
    WriteLn('======================================');
    WriteLn;
    
    RunCrossManagementTests;
    
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
