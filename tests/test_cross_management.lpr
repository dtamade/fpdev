program test_cross_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, test_pause_control, Classes,
  fpdev.config, fpdev.cross.manager, fpdev.utils, test_temp_paths, fpdev.paths;

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
    procedure TestCrossManagerUsesSameProcessInstallRootFallback;
    procedure TestCrossManagerUsesFPDEVDataRootOverride;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

procedure RestoreEnv(const AName, ASavedValue: string);
begin
  if ASavedValue <> '' then
    set_env(AName, ASavedValue)
  else
    unset_env(AName);
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
  TestCrossManagerUsesSameProcessInstallRootFallback;
  TestCrossManagerUsesFPDEVDataRootOverride;
  
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

procedure TCrossManagementTest.TestCrossManagerUsesSameProcessInstallRootFallback;
var
  Manager: TCrossCompilerManager;
  Settings: TFPDevSettings;
  ProbeHome: string;
  ExpectedRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
  {$IFDEF MSWINDOWS}
  SavedAppData: string;
  SavedUserProfile: string;
  {$ELSE}
  SavedHome: string;
  {$ENDIF}
begin
  WriteLn('--- Testing Cross Manager Same-Process Install Root Fallback ---');

  try
    ProbeHome := CreateUniqueTempDir('test_cross_manager_home');
    Settings := FConfigManager.GetSettings;
    Settings.InstallRoot := '';
    AssertTrue(FConfigManager.SetSettings(Settings),
      'Should clear install root before same-process fallback probe');

    {$IFDEF MSWINDOWS}
    SavedUserProfile := get_env('USERPROFILE');
    SavedAppData := get_env('APPDATA');
    {$ELSE}
    SavedHome := get_env('HOME');
    {$ENDIF}
    SavedDataRoot := get_env('FPDEV_DATA_ROOT');
    SavedXDGDataHome := get_env('XDG_DATA_HOME');
    try
      SetPortableMode(False);
      unset_env('FPDEV_DATA_ROOT');
      unset_env('XDG_DATA_HOME');
      {$IFDEF MSWINDOWS}
      set_env('USERPROFILE', ProbeHome);
      set_env('APPDATA', ProbeHome);
      {$ELSE}
      set_env('HOME', ProbeHome);
      {$ENDIF}
      ExpectedRoot := GetDataRoot;

      Manager := TCrossCompilerManager.Create(FConfigManager);
      try
        AssertEquals(ExpectedRoot, FConfigManager.GetSettings.InstallRoot,
          'Cross manager should persist same-process install root fallback');
        AssertTrue(DirectoryExists(ExpectedRoot),
          'Cross manager should create same-process install root directory');
      finally
        Manager.Free;
      end;
    finally
      {$IFDEF MSWINDOWS}
      if SavedUserProfile <> '' then
        set_env('USERPROFILE', SavedUserProfile)
      else
        unset_env('USERPROFILE');
      if SavedAppData <> '' then
        set_env('APPDATA', SavedAppData)
      else
        unset_env('APPDATA');
      {$ELSE}
      RestoreEnv('HOME', SavedHome);
      {$ENDIF}
      RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
      RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
      CleanupTempDir(ProbeHome);
    end;

    WriteLn('✓ Cross manager same-process install root fallback successful');
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during cross manager fallback test: ' + E.Message);
    end;
  end;

  WriteLn;
end;

procedure TCrossManagementTest.TestCrossManagerUsesFPDEVDataRootOverride;
var
  Manager: TCrossCompilerManager;
  Settings: TFPDevSettings;
  ProbeRoot: string;
  ExpectedRoot: string;
  SavedDataRoot: string;
  SavedXDGDataHome: string;
begin
  WriteLn('--- Testing Cross Manager FPDEV_DATA_ROOT Override ---');

  try
    ProbeRoot := CreateUniqueTempDir('test_cross_manager_data_root');
    Settings := FConfigManager.GetSettings;
    Settings.InstallRoot := '';
    AssertTrue(FConfigManager.SetSettings(Settings),
      'Should clear install root before FPDEV_DATA_ROOT probe');

    SavedDataRoot := get_env('FPDEV_DATA_ROOT');
    SavedXDGDataHome := get_env('XDG_DATA_HOME');
    try
      SetPortableMode(False);
      unset_env('XDG_DATA_HOME');
      set_env('FPDEV_DATA_ROOT', ProbeRoot);
      ExpectedRoot := GetDataRoot;

      Manager := TCrossCompilerManager.Create(FConfigManager);
      try
        AssertEquals(ExpectedRoot, FConfigManager.GetSettings.InstallRoot,
          'Cross manager should persist FPDEV_DATA_ROOT install root');
        AssertTrue(DirectoryExists(ExpectedRoot),
          'Cross manager should create FPDEV_DATA_ROOT install root directory');
      finally
        Manager.Free;
      end;
    finally
      RestoreEnv('FPDEV_DATA_ROOT', SavedDataRoot);
      RestoreEnv('XDG_DATA_HOME', SavedXDGDataHome);
      CleanupTempDir(ProbeRoot);
    end;

    WriteLn('✓ Cross manager FPDEV_DATA_ROOT override successful');
  except
    on E: Exception do
    begin
      AssertTrue(False, 'Exception during cross manager FPDEV_DATA_ROOT test: ' + E.Message);
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
    if Test.TestsFailed > 0 then
      ExitCode := 1;
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
