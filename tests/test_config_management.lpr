program test_config_management;

{$codepage utf8}
{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  SysUtils, Classes,
  fpdev.config;

type
  { TConfigManagementTest }
  TConfigManagementTest = class
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
    procedure TestConfigCreation;
    procedure TestToolchainManagement;
    procedure TestLazarusVersionManagement;
    procedure TestCrossTargetManagement;
    procedure TestSettingsManagement;
    procedure TestRepositoryManagement;
    procedure TestConfigPersistence;
    
    // 属性
    property TestsPassed: Integer read FTestsPassed;
    property TestsFailed: Integer read FTestsFailed;
  end;

{ TConfigManagementTest }

constructor TConfigManagementTest.Create;
begin
  inherited Create;
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  // 创建临时测试配置文件路径
  FTestConfigPath := 'test_config.json';
  FConfigManager := TFPDevConfigManager.Create(FTestConfigPath);
end;

destructor TConfigManagementTest.Destroy;
begin
  // 清理测试文件
  if FileExists(FTestConfigPath) then
    DeleteFile(FTestConfigPath);
    
  FConfigManager.Free;
  inherited Destroy;
end;

procedure TConfigManagementTest.AssertTrue(const ACondition: Boolean; const AMessage: string);
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

procedure TConfigManagementTest.AssertEquals(const AExpected, AActual: string; const AMessage: string);
begin
  AssertTrue(AExpected = AActual, AMessage + ' (Expected: "' + AExpected + '", Actual: "' + AActual + '")');
end;

procedure TConfigManagementTest.RunAllTests;
begin
  WriteLn('=== Configuration Management Tests ===');
  WriteLn;
  
  FTestsPassed := 0;
  FTestsFailed := 0;
  
  TestConfigCreation;
  TestToolchainManagement;
  TestLazarusVersionManagement;
  TestCrossTargetManagement;
  TestSettingsManagement;
  TestRepositoryManagement;
  TestConfigPersistence;
  
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

procedure TConfigManagementTest.TestConfigCreation;
begin
  WriteLn('--- Testing Config Creation ---');
  
  try
    AssertTrue(FConfigManager.CreateDefaultConfig, 'Should create default config');
    AssertTrue(FileExists(FTestConfigPath), 'Config file should exist');
    AssertTrue(FConfigManager.LoadConfig, 'Should load config');
    
    WriteLn('✓ Config creation successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestToolchainManagement;
var
  ToolchainInfo: TToolchainInfo;
  Toolchains: TStringArray;
begin
  WriteLn('--- Testing Toolchain Management ---');
  
  try
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    ToolchainInfo.ToolchainType := ttRelease;
    ToolchainInfo.Version := '3.2.2';
    ToolchainInfo.InstallPath := '/test/fpc/3.2.2';
    ToolchainInfo.SourceURL := 'https://gitlab.com/freepascal.org/fpc/source.git';
    ToolchainInfo.Branch := 'fixes_3_2';
    ToolchainInfo.Installed := True;
    ToolchainInfo.InstallDate := Now;
    
    AssertTrue(FConfigManager.AddToolchain('fpc-3.2.2', ToolchainInfo), 'Should add toolchain');
    
    FillChar(ToolchainInfo, SizeOf(ToolchainInfo), 0);
    AssertTrue(FConfigManager.GetToolchain('fpc-3.2.2', ToolchainInfo), 'Should get toolchain');
    AssertEquals('3.2.2', ToolchainInfo.Version, 'Version should match');
    
    Toolchains := FConfigManager.ListToolchains;
    AssertTrue(Length(Toolchains) > 0, 'Should have toolchains');
    
    AssertTrue(FConfigManager.SetDefaultToolchain('fpc-3.2.2'), 'Should set default');
    AssertEquals('fpc-3.2.2', FConfigManager.GetDefaultToolchain, 'Default should match');
    
    WriteLn('✓ Toolchain management successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestLazarusVersionManagement;
var
  LazarusInfo: TLazarusInfo;
  Versions: TStringArray;
begin
  WriteLn('--- Testing Lazarus Version Management ---');
  
  try
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    LazarusInfo.Version := '3.0';
    LazarusInfo.FPCVersion := 'fpc-3.2.2';
    LazarusInfo.InstallPath := '/test/lazarus/3.0';
    LazarusInfo.SourceURL := 'https://gitlab.com/freepascal.org/lazarus.git';
    LazarusInfo.Branch := 'lazarus_3_0';
    LazarusInfo.Installed := True;
    
    AssertTrue(FConfigManager.AddLazarusVersion('lazarus-3.0', LazarusInfo), 'Should add Lazarus version');
    
    FillChar(LazarusInfo, SizeOf(LazarusInfo), 0);
    AssertTrue(FConfigManager.GetLazarusVersion('lazarus-3.0', LazarusInfo), 'Should get Lazarus version');
    AssertEquals('3.0', LazarusInfo.Version, 'Version should match');
    
    Versions := FConfigManager.ListLazarusVersions;
    AssertTrue(Length(Versions) > 0, 'Should have Lazarus versions');
    
    AssertTrue(FConfigManager.SetDefaultLazarusVersion('lazarus-3.0'), 'Should set default Lazarus');
    AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default Lazarus should match');
    
    WriteLn('✓ Lazarus version management successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestCrossTargetManagement;
var
  CrossTarget: TCrossTarget;
  Targets: TStringArray;
begin
  WriteLn('--- Testing Cross Target Management ---');
  
  try
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    CrossTarget.Enabled := True;
    CrossTarget.BinutilsPath := '/test/binutils';
    CrossTarget.LibrariesPath := '/test/libs';
    
    AssertTrue(FConfigManager.AddCrossTarget('win64', CrossTarget), 'Should add cross target');
    
    FillChar(CrossTarget, SizeOf(CrossTarget), 0);
    AssertTrue(FConfigManager.GetCrossTarget('win64', CrossTarget), 'Should get cross target');
    AssertTrue(CrossTarget.Enabled = True, 'Should be enabled');
    
    Targets := FConfigManager.ListCrossTargets;
    AssertTrue(Length(Targets) > 0, 'Should have cross targets');
    
    WriteLn('✓ Cross target management successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestSettingsManagement;
var
  Settings: TFPDevSettings;
begin
  WriteLn('--- Testing Settings Management ---');
  
  try
    FillChar(Settings, SizeOf(Settings), 0);
    Settings.AutoUpdate := True;
    Settings.ParallelJobs := 8;
    Settings.KeepSources := False;
    Settings.InstallRoot := '/test/fpdev';
    
    AssertTrue(FConfigManager.SetSettings(Settings), 'Should set settings');
    
    Settings := FConfigManager.GetSettings;
    AssertTrue(Settings.AutoUpdate = True, 'AutoUpdate should match');
    AssertTrue(Settings.ParallelJobs = 8, 'ParallelJobs should match');
    AssertEquals('/test/fpdev', Settings.InstallRoot, 'InstallRoot should match');
    
    WriteLn('✓ Settings management successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestRepositoryManagement;
begin
  WriteLn('--- Testing Repository Management ---');
  
  try
    AssertTrue(FConfigManager.AddRepository('test_repo', 'https://example.com/test.git'), 'Should add repository');
    AssertEquals('https://example.com/test.git', FConfigManager.GetRepository('test_repo'), 'Repository should match');
    
    WriteLn('✓ Repository management successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

procedure TConfigManagementTest.TestConfigPersistence;
begin
  WriteLn('--- Testing Config Persistence ---');
  
  try
    AssertTrue(FConfigManager.SaveConfig, 'Should save config');
    AssertTrue(FConfigManager.LoadConfig, 'Should reload config');
    
    // 验证数据持久化
    AssertEquals('fpc-3.2.2', FConfigManager.GetDefaultToolchain, 'Default toolchain should persist');
    AssertEquals('lazarus-3.0', FConfigManager.GetDefaultLazarusVersion, 'Default Lazarus should persist');
    
    WriteLn('✓ Config persistence successful');
    
  except
    on E: Exception do
      AssertTrue(False, 'Exception: ' + E.Message);
  end;
  
  WriteLn;
end;

// 全局测试函数
procedure RunConfigManagementTests;
var
  Test: TConfigManagementTest;
begin
  Test := TConfigManagementTest.Create;
  try
    Test.RunAllTests;
  finally
    Test.Free;
  end;
end;

begin
  try
    WriteLn('Configuration Management Test Suite');
    WriteLn('===================================');
    WriteLn;
    
    RunConfigManagementTests;
    
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
  if FindCmdLineSwitch('pause',['-','/','--'],True) or (GetEnv('FPDEV_DEMO_PAUSE') <> '') then
  begin
    WriteLn('Press Enter to continue... (--pause or FPDEV_DEMO_PAUSE)');
    ReadLn;
  end;
  {$ENDIF}
end.
